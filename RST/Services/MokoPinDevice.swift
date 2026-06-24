import CoreBluetooth
import Foundation
import Observation

/// Real smart-pin driver for the MOKO M1Pro sensor.
///
/// The sensor broadcasts its acceleration and a motion counter in a BLE
/// advertisement (Service Data UUID `0xEA01`, frame type `0x80`), so rep
/// tracking works purely by **scanning** — no GATT connection, no pairing
/// password. We lock onto one sensor (strongest seen, or a paired Tag ID),
/// parse every advertisement, and feed the acceleration to `RepCounter` while a
/// set is active. Rest is detected when motion stops for `restTimeout`.
///
/// Configure the sensor itself (advertising interval, motion trigger, etc.) with
/// the MOKO app per `SENSOR_SETUP.md`; the MOKO iOS SDK can be layered in later
/// to do that in-app.
@Observable @MainActor
final class MokoPinDevice: NSObject, PinDeviceService {
    /// 16-bit Service Data UUID MOKO uses for the customized frames.
    static let serviceUUID = CBUUID(string: "EA01")

    private(set) var connectionState: PinConnectionState = .disconnected
    private(set) var phase: SetPhase = .idle
    private(set) var repCount: Int = 0
    private(set) var deviceInfo: PinDeviceInfo?
    private(set) var liveAcceleration: Double = 0

    /// Seconds without motion before an active set is auto-ended.
    var restTimeout: TimeInterval = 4.0
    /// If set, only lock onto a sensor advertising this Tag ID (hex). Persisted
    /// pairing lives in UserDefaults under `pairedSensorTagID`.
    var pairedTagID: String?

    private var central: CBCentralManager!
    private let counter = RepCounter()
    private var lockedTagID: String?
    private var lastMotionAt: Date?
    private var watchdog: Task<Void, Never>?
    private var liveDecay: Task<Void, Never>?
    private var wantScan = false

    nonisolated override init() {
        super.init()
        pairedTagID = UserDefaults.standard.string(forKey: "pairedSensorTagID")
        central = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - PinDeviceService

    func connect() async {
        guard connectionState == .disconnected else { return }
        wantScan = true
        connectionState = .scanning
        startScanIfReady()
    }

    func disconnect() {
        wantScan = false
        if central.state == .poweredOn { central.stopScan() }
        watchdog?.cancel(); watchdog = nil
        liveDecay?.cancel(); liveDecay = nil
        connectionState = .disconnected
        phase = .idle
        repCount = 0
        liveAcceleration = 0
        lockedTagID = nil
        deviceInfo = nil
    }

    func beginSet() {
        counter.reset()
        repCount = 0
        phase = .lifting
        lastMotionAt = Date()
        // Make sure we're scanning so accel keeps flowing during the set.
        if connectionState != .connected { connectionState = .scanning }
        startScanIfReady()
        startWatchdog()
    }

    @discardableResult
    func endSet() -> Int {
        watchdog?.cancel(); watchdog = nil
        if phase == .lifting { phase = .resting }
        liveAcceleration = 0
        return repCount
    }

    /// Remembers the currently locked sensor so we reconnect to the same pin.
    func pairCurrentSensor() {
        guard let tag = lockedTagID else { return }
        pairedTagID = tag
        UserDefaults.standard.set(tag, forKey: "pairedSensorTagID")
    }

    func forgetPairedSensor() {
        pairedTagID = nil
        UserDefaults.standard.removeObject(forKey: "pairedSensorTagID")
    }

    // MARK: - Internals

    private func startScanIfReady() {
        guard wantScan, central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.phase == .lifting,
                   let last = self.lastMotionAt,
                   Date().timeIntervalSince(last) > self.restTimeout {
                    self.phase = .resting
                    self.liveAcceleration = 0
                    return
                }
            }
        }
    }

    /// Called on the main actor with a parsed frame from a discovered sensor.
    private func ingest(frame: PinSensorFrame, name: String?, rssi: Int) {
        // Honor an explicit pairing.
        if let paired = pairedTagID, !paired.isEmpty, frame.tagID != paired { return }
        // Lock onto the first qualifying sensor for the session.
        if lockedTagID == nil { lockedTagID = frame.tagID }
        guard frame.tagID == lockedTagID else { return }

        connectionState = .connected
        deviceInfo = PinDeviceInfo(name: name ?? "MK Sensor",
                                   tagID: frame.tagID,
                                   rssi: rssi,
                                   batteryPercent: frame.batteryPercent,
                                   batteryMilliVolts: frame.batteryMilliVolts)

        guard phase == .lifting else { return }

        if frame.motionActive { lastMotionAt = Date() }
        let sample = AccelSample(time: Date().timeIntervalSince1970,
                                 magnitudeG: frame.magnitudeG)
        let countedRep = counter.ingest(sample)
        pulseLive(counter.lastDynamic)
        if countedRep {
            repCount = counter.count
            lastMotionAt = Date()
        }
    }

    private func pulseLive(_ value: Double) {
        liveAcceleration = min(value / 0.4, 1.0)  // normalize ~0.4g to full
        liveDecay?.cancel()
        liveDecay = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.liveAcceleration = 0
        }
    }
}

extension MokoPinDevice: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let poweredOn = central.state == .poweredOn
        Task { @MainActor in
            if poweredOn {
                self.startScanIfReady()
            } else if self.wantScan {
                self.connectionState = .scanning
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        guard
            let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
            let payload = serviceData[MokoPinDevice.serviceUUID],
            let frame = PinSensorFrame(serviceData: payload)
        else { return }

        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let rssi = RSSI.intValue
        Task { @MainActor in
            self.ingest(frame: frame, name: name, rssi: rssi)
        }
    }
}
