import Foundation

/// One accelerometer reading, in g, on all three axes.
struct AccelSample {
    let time: TimeInterval
    let x: Double
    let y: Double
    let z: Double
}

/// Counts reps by detecting a full **out-and-back cycle** on the weight
/// stack's pin, rather than counting acceleration peaks.
///
/// On a guided weight stack the pin moves along essentially one axis: it
/// accelerates away from rest, decelerates, reverses, and decelerates again
/// back to rest. That physical round trip naturally produces a positive pulse
/// followed by a negative pulse (or vice versa) in the deviation from gravity
/// on whichever axis is aligned with the stack's travel — which is exactly why
/// a plain magnitude/peak threshold over- or under-counts: it sees the
/// sub-pulses within a single rep as separate events instead of one cycle.
///
/// This tracks direction instead:
/// 1. **Resting** — deviation on every axis is small. Once one axis exceeds
///    `moveThreshold`, that axis is locked in as the rep's dominant axis and
///    we note which way it moved (`outbound`).
/// 2. **Outbound** — wait for the *same* axis to swing past the threshold in
///    the *opposite* direction (`inbound`) — the reversal.
/// 3. **Inbound** — wait for that axis to settle back within `restThreshold`
///    of the baseline — the pin (and stack) has returned to where it started.
///    That completes one rep.
///
/// The dominant axis is re-detected at the start of every cycle rather than
/// fixed, so it self-adjusts to however the pin happens to sit in a given
/// machine. A slow gravity baseline is tracked per axis, but only while
/// resting, so an in-progress rep can't drag the baseline along with it.
///
/// The sample rate here is the sensor's *advertising* rate while moving (up to
/// ~10 Hz), not a true high-rate IMU stream — these defaults are a starting
/// point meant to be tuned against real M1Pro data. See `SENSOR_SETUP.md`.
final class RepCounter {
    /// g of deviation from baseline needed to register as "moving."
    var moveThreshold: Double
    /// g of deviation below which the pin is considered back at rest.
    var restThreshold: Double
    /// EMA weight for the per-axis gravity baseline (applied only at rest).
    var baselineAlpha: Double
    /// Minimum total cycle time to count as a real rep — rejects noise flicker.
    var minRepDuration: TimeInterval
    /// Abandon (don't count) a cycle that's still in progress after this long,
    /// and reset to resting — guards against getting stuck mid-cycle.
    var maxRepDuration: TimeInterval

    private(set) var count = 0
    /// Current deviation magnitude on the tracked axis (0 while resting), for
    /// live UI feedback.
    private(set) var lastDynamic = 0.0

    private enum Phase { case resting, outbound, inbound }
    private enum Axis { case x, y, z }

    private var phase: Phase = .resting
    private var baseline = (x: 0.0, y: 0.0, z: 0.0)
    private var baselinePrimed = false
    private var axis: Axis?
    private var outboundSign: Double = 1
    private var phaseStartTime: TimeInterval = 0

    init(moveThreshold: Double = 0.12,
         restThreshold: Double = 0.06,
         baselineAlpha: Double = 0.08,
         minRepDuration: TimeInterval = 0.4,
         maxRepDuration: TimeInterval = 4.0) {
        self.moveThreshold = moveThreshold
        self.restThreshold = restThreshold
        self.baselineAlpha = baselineAlpha
        self.minRepDuration = minRepDuration
        self.maxRepDuration = maxRepDuration
    }

    func reset() {
        count = 0
        lastDynamic = 0
        phase = .resting
        baselinePrimed = false
        axis = nil
        phaseStartTime = 0
    }

    /// Feeds one sample. Returns `true` if it just completed a rep.
    @discardableResult
    func ingest(_ sample: AccelSample) -> Bool {
        if !baselinePrimed {
            baseline = (sample.x, sample.y, sample.z)
            baselinePrimed = true
            return false
        }

        // Only adapt the baseline while resting, so a rep in progress can't
        // pull the baseline toward itself.
        if phase == .resting {
            baseline.x += baselineAlpha * (sample.x - baseline.x)
            baseline.y += baselineAlpha * (sample.y - baseline.y)
            baseline.z += baselineAlpha * (sample.z - baseline.z)
        }

        let dx = sample.x - baseline.x
        let dy = sample.y - baseline.y
        let dz = sample.z - baseline.z

        switch phase {
        case .resting:
            let candidates: [(Axis, Double)] = [(.x, dx), (.y, dy), (.z, dz)]
            let strongest = candidates.max { abs($0.1) < abs($1.1) }!
            lastDynamic = abs(strongest.1)
            guard abs(strongest.1) >= moveThreshold else { return false }
            axis = strongest.0
            outboundSign = strongest.1 > 0 ? 1 : -1
            phase = .outbound
            phaseStartTime = sample.time
            return false

        case .outbound:
            let value = axisValue(dx, dy, dz)
            lastDynamic = abs(value)
            if sample.time - phaseStartTime > maxRepDuration {
                phase = .resting
                axis = nil
                return false
            }
            // Reversed past the threshold on the other side — heading back.
            if value * outboundSign < -moveThreshold {
                phase = .inbound
            }
            return false

        case .inbound:
            let value = axisValue(dx, dy, dz)
            lastDynamic = abs(value)
            if sample.time - phaseStartTime > maxRepDuration {
                phase = .resting
                axis = nil
                return false
            }
            guard abs(value) <= restThreshold else { return false }
            // Back at rest: the cycle is complete.
            let duration = sample.time - phaseStartTime
            phase = .resting
            axis = nil
            guard duration >= minRepDuration else { return false }
            count += 1
            return true
        }
    }

    private func axisValue(_ dx: Double, _ dy: Double, _ dz: Double) -> Double {
        switch axis {
        case .x: return dx
        case .y: return dy
        case .z: return dz
        case nil: return 0
        }
    }
}
