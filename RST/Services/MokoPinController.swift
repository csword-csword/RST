import CoreBluetooth
import Foundation
import Observation

/// Real connected-mode controller for the MOKO M1Pro.
///
/// Performs a genuine CoreBluetooth connection and GATT discovery, then runs the
/// authenticated commands (password / battery) **once `MokoControlProtocol` is
/// filled in**. Connection and discovery work today and surface the device's
/// characteristics (handy for identifying the right UUIDs); the write commands
/// refuse to run until the proprietary command bytes are supplied, so we never
/// send incorrect data to the hardware.
///
/// The central manager uses the main queue (`queue: nil`), so all delegate
/// callbacks arrive on the main actor — hence `MainActor.assumeIsolated`.
@Observable @MainActor
final class MokoPinController: NSObject, PinControlling {
    private(set) var state: PinControlState = .idle
    private(set) var connectedInfo: PinDeviceInfo?
    private(set) var discoveredCharacteristics: [String] = []

    var pairedTagID: String? = UserDefaults.standard.string(forKey: "pairedSensorTagID")
    var operationTimeout: TimeInterval = 8

    private var central: CBCentralManager?
    private var target: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?
    private var lastAdvertInfo: PinDeviceInfo?

    private var powerContinuation: CheckedContinuation<Void, Error>?
    private var scanContinuation: CheckedContinuation<Void, Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var discoverContinuation: CheckedContinuation<Void, Error>?
    private var responseContinuation: CheckedContinuation<Data, Error>?

    nonisolated override init() {
        super.init()
    }

    /// Creates the central manager on first use, on the main actor (it can't
    /// be made in the nonisolated init).
    @discardableResult
    private func ensureCentral() -> CBCentralManager {
        if let central { return central }
        let created = CBCentralManager(delegate: self, queue: nil)
        central = created
        return created
    }

    /// Waits for Bluetooth to power on (the lazily-created central starts in
    /// `.unknown` for a moment before its first state update).
    private func waitForPoweredOn() async throws {
        let central = ensureCentral()
        switch central.state {
        case .poweredOn: return
        case .unauthorized, .poweredOff, .unsupported: throw PinControlError.bluetoothUnavailable
        default: break  // .unknown / .resetting — wait for the delegate callback
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            powerContinuation = cont
            scheduleTimeout { [weak self] in
                guard let self, let c = self.powerContinuation else { return }
                self.powerContinuation = nil
                c.resume(throwing: PinControlError.bluetoothUnavailable)
            }
        }
    }

    // MARK: - PinControlling

    func connect(password: String) async throws {
        do {
            state = .scanning
            try await waitForPoweredOn()
            try await findTarget()

            state = .connecting
            try await establishConnection()
            try await discoverGATT()

            if MokoControlProtocol.isConfigured {
                state = .authenticating
                guard let frame = MokoControlProtocol.authCommand(password: password) else {
                    throw PinControlError.protocolNotConfigured
                }
                _ = try await send(frame)
            }
            connectedInfo = lastAdvertInfo
            state = .connected
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            disconnect()
            state = .failed(message)
            throw error
        }
    }

    func disconnect() {
        if let target { central?.cancelPeripheralConnection(target) }
        if let central, central.state == .poweredOn { central.stopScan() }
        failPending(PinControlError.notConnected)
        target = nil
        writeChar = nil
        notifyChar = nil
        connectedInfo = nil
        discoveredCharacteristics = []
        state = .idle
    }

    func changePassword(current: String, new: String) async throws {
        try ensureCommandReady()
        guard let frame = MokoControlProtocol.changePasswordCommand(new: new) else {
            throw PinControlError.protocolNotConfigured
        }
        _ = try await send(frame)
    }

    func resetBatteryGauge() async throws {
        try ensureCommandReady()
        guard let frame = MokoControlProtocol.resetBatteryCommand() else {
            throw PinControlError.protocolNotConfigured
        }
        _ = try await send(frame)
        connectedInfo?.batteryPercent = 100
        connectedInfo?.batteryMilliVolts = nil
    }

    // MARK: - Steps

    private func ensureCommandReady() throws {
        guard state == .connected else { throw PinControlError.notConnected }
        guard MokoControlProtocol.isConfigured else { throw PinControlError.protocolNotConfigured }
    }

    private func findTarget() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            scanContinuation = cont
            ensureCentral().scanForPeripherals(withServices: [MokoPinDevice.serviceUUID],
                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            scheduleTimeout { [weak self] in
                guard let self, let c = self.scanContinuation else { return }
                self.scanContinuation = nil
                self.central?.stopScan()
                c.resume(throwing: PinControlError.deviceNotFound)
            }
        }
    }

    private func establishConnection() async throws {
        guard let target else { throw PinControlError.deviceNotFound }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectContinuation = cont
            ensureCentral().connect(target)
            scheduleTimeout { [weak self] in
                guard let self, let c = self.connectContinuation else { return }
                self.connectContinuation = nil
                c.resume(throwing: PinControlError.timedOut)
            }
        }
    }

    private func discoverGATT() async throws {
        guard let target else { throw PinControlError.notConnected }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            discoverContinuation = cont
            let services = MokoControlProtocol.configServiceUUID.map { [$0] }
            target.discoverServices(services)
            scheduleTimeout { [weak self] in
                guard let self, let c = self.discoverContinuation else { return }
                self.discoverContinuation = nil
                c.resume(throwing: PinControlError.timedOut)
            }
        }
    }

    @discardableResult
    private func send(_ data: Data) async throws -> Data {
        guard let target, let writeChar else { throw PinControlError.notConnected }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            responseContinuation = cont
            target.writeValue(data, for: writeChar, type: .withResponse)
            scheduleTimeout { [weak self] in
                guard let self, let c = self.responseContinuation else { return }
                self.responseContinuation = nil
                c.resume(throwing: PinControlError.timedOut)
            }
        }
    }

    private func scheduleTimeout(_ fire: @escaping @MainActor () -> Void) {
        let seconds = operationTimeout
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            fire()
        }
    }

    private func failPending(_ error: Error) {
        powerContinuation?.resume(throwing: error); powerContinuation = nil
        scanContinuation?.resume(throwing: error); scanContinuation = nil
        connectContinuation?.resume(throwing: error); connectContinuation = nil
        discoverContinuation?.resume(throwing: error); discoverContinuation = nil
        responseContinuation?.resume(throwing: error); responseContinuation = nil
    }
}

extension MokoPinController: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            guard let cont = powerContinuation else { return }
            switch central.state {
            case .poweredOn:
                powerContinuation = nil
                cont.resume()
            case .unauthorized, .poweredOff, .unsupported:
                powerContinuation = nil
                cont.resume(throwing: PinControlError.bluetoothUnavailable)
            default:
                break  // .unknown / .resetting — keep waiting
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            guard scanContinuation != nil else { return }
            var tagID: String?
            var info: PinDeviceInfo?
            if let sd = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
               let payload = sd[MokoPinDevice.serviceUUID],
               let frame = PinSensorFrame(serviceData: payload) {
                tagID = frame.tagID
                info = PinDeviceInfo(name: advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "MK Sensor",
                                     tagID: frame.tagID,
                                     rssi: RSSI.intValue,
                                     batteryPercent: frame.batteryPercent,
                                     batteryMilliVolts: frame.batteryMilliVolts)
            }
            if let paired = pairedTagID, !paired.isEmpty, tagID != paired { return }

            central.stopScan()
            target = peripheral
            peripheral.delegate = self
            lastAdvertInfo = info
            let cont = scanContinuation
            scanContinuation = nil
            cont?.resume()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            let cont = connectContinuation
            connectContinuation = nil
            cont?.resume()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            let cont = connectContinuation
            connectContinuation = nil
            cont?.resume(throwing: PinControlError.connectionFailed)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            failPending(PinControlError.notConnected)
            if state == .connected || state == .authenticating { state = .idle }
        }
    }
}

extension MokoPinController: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            if let error {
                let cont = discoverContinuation; discoverContinuation = nil
                cont?.resume(throwing: error)
                return
            }
            for service in peripheral.services ?? [] {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            for ch in service.characteristics ?? [] {
                discoveredCharacteristics.append("\(service.uuid.uuidString)/\(ch.uuid.uuidString)")
                if ch.uuid == MokoControlProtocol.writeCharacteristicUUID { writeChar = ch }
                if ch.uuid == MokoControlProtocol.notifyCharacteristicUUID {
                    notifyChar = ch
                    peripheral.setNotifyValue(true, for: ch)
                }
            }
            let allDiscovered = peripheral.services?.allSatisfy { $0.characteristics != nil } ?? false
            if allDiscovered {
                let cont = discoverContinuation; discoverContinuation = nil
                cont?.resume()
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            let cont = responseContinuation; responseContinuation = nil
            if let error { cont?.resume(throwing: error) }
            else { cont?.resume(returning: characteristic.value ?? Data()) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Resolve on the write ack only when the device has no notify reply
        // characteristic; otherwise the response arrives via didUpdateValueFor.
        guard MokoControlProtocol.notifyCharacteristicUUID == nil else { return }
        MainActor.assumeIsolated {
            let cont = responseContinuation; responseContinuation = nil
            if let error { cont?.resume(throwing: error) }
            else { cont?.resume(returning: Data()) }
        }
    }
}
