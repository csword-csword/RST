import Foundation

struct AccelSample {
    let time: TimeInterval
    let magnitudeG: Double
}

/// Counts reps from a stream of acceleration-magnitude samples.
///
/// The pin moves with the weight stack, so each rep produces a pulse of dynamic
/// acceleration (the magnitude deviating from the ~1 g gravity baseline). We
/// track a slow EMA baseline to stay orientation-independent, then count one rep
/// per pulse that exceeds `threshold`, with hysteresis (must fall below
/// `rearmFraction × threshold` to re-arm) and a `minRepInterval` refractory gap
/// to reject double-counts.
///
/// The sample rate here is the sensor's *advertising* rate while moving (a few
/// Hz to ~10 Hz), not a true IMU stream — so these defaults are a starting point
/// and are meant to be tuned against the real M1Pro. See `SENSOR_SETUP.md`.
final class RepCounter {
    var threshold: Double          // g of dynamic acceleration to register a peak
    var rearmFraction: Double      // must drop below threshold×this to count again
    var minRepInterval: TimeInterval
    var baselineAlpha: Double      // EMA weight for the gravity baseline

    private(set) var count = 0
    private(set) var lastDynamic = 0.0

    private var baseline = 1.0
    private var baselinePrimed = false
    private var armed = true
    private var lastRepTime = -Double.greatestFiniteMagnitude

    init(threshold: Double = 0.15,
         rearmFraction: Double = 0.5,
         minRepInterval: TimeInterval = 0.7,
         baselineAlpha: Double = 0.2) {
        self.threshold = threshold
        self.rearmFraction = rearmFraction
        self.minRepInterval = minRepInterval
        self.baselineAlpha = baselineAlpha
    }

    func reset() {
        count = 0
        lastDynamic = 0
        baseline = 1.0
        baselinePrimed = false
        armed = true
        lastRepTime = -Double.greatestFiniteMagnitude
    }

    /// Feeds one sample. Returns `true` if it completed a rep.
    @discardableResult
    func ingest(_ sample: AccelSample) -> Bool {
        if !baselinePrimed {
            baseline = sample.magnitudeG
            baselinePrimed = true
        } else {
            baseline += baselineAlpha * (sample.magnitudeG - baseline)
        }

        let dynamic = abs(sample.magnitudeG - baseline)
        lastDynamic = dynamic

        if dynamic < threshold * rearmFraction {
            armed = true
        }

        if armed,
           dynamic >= threshold,
           sample.time - lastRepTime >= minRepInterval {
            armed = false
            lastRepTime = sample.time
            count += 1
            return true
        }
        return false
    }
}
