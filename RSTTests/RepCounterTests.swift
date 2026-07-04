import XCTest
@testable import RST

final class RepCounterTests: XCTestCase {
    /// Feeds one full out-and-back rep as a sine cycle of deviation on a single
    /// axis: 0 -> +peak -> 0 -> -peak -> 0. The zero-crossing at the midpoint
    /// falls inside the "outbound" phase (which only watches for a reversal,
    /// not a return to rest), so this produces exactly one counted rep — the
    /// same shape a pin's accelerate/decelerate/reverse/decelerate motion
    /// produces on whichever axis is aligned with the stack's travel.
    private func feedRep(into counter: RepCounter,
                         axis: Int = 2,
                         peak: Double = 0.3,
                         duration: Double = 2.0,
                         sampleHz: Double = 10,
                         startTime: Double = 0) {
        let dt = 1.0 / sampleHz
        var t = 0.0
        while t <= duration {
            let dev = peak * sin(2 * .pi * t / duration)
            let time = startTime + t
            switch axis {
            case 0: counter.ingest(AccelSample(time: time, x: dev, y: 0, z: 1.0))
            case 1: counter.ingest(AccelSample(time: time, x: 0, y: dev, z: 1.0))
            default: counter.ingest(AccelSample(time: time, x: 0, y: 0, z: 1.0 + dev))
            }
            t += dt
        }
    }

    func testSingleRepCountsOnce() {
        let counter = RepCounter()
        feedRep(into: counter)
        XCTAssertEqual(counter.count, 1)
    }

    func testMultipleConsecutiveReps() {
        let counter = RepCounter()
        for i in 0..<8 {
            feedRep(into: counter, startTime: Double(i) * 2.5)
        }
        XCTAssertEqual(counter.count, 8)
    }

    func testWorksOnAnyDominantAxis() {
        for axis in [0, 1, 2] {
            let counter = RepCounter()
            feedRep(into: counter, axis: axis)
            XCTAssertEqual(counter.count, 1, "axis \(axis) should count a rep")
        }
    }

    func testQuietSignalCountsNothing() {
        let counter = RepCounter()
        for i in 0..<60 {
            counter.ingest(AccelSample(time: Double(i) / 6.0, x: 0.01, y: 0, z: 1.0))
        }
        XCTAssertEqual(counter.count, 0)
    }

    func testTinyNoiseFasterThanMinDurationDoesNotCount() {
        // A blip that reverses and settles well under minRepDuration is noise,
        // not a rep.
        let counter = RepCounter(minRepDuration: 0.4)
        counter.ingest(AccelSample(time: 0.00, x: 0, y: 0, z: 1.0))
        counter.ingest(AccelSample(time: 0.05, x: 0, y: 0, z: 1.0 + 0.3))   // outbound
        counter.ingest(AccelSample(time: 0.10, x: 0, y: 0, z: 1.0 - 0.3))   // reversal
        counter.ingest(AccelSample(time: 0.15, x: 0, y: 0, z: 1.0))         // back to rest fast
        XCTAssertEqual(counter.count, 0)
    }

    func testNeverReversingDoesNotCount() {
        // Moves out and comes back without ever swinging past threshold in the
        // opposite direction — not a full cycle, shouldn't count.
        let counter = RepCounter()
        var t = 0.0
        for _ in 0..<20 {
            let dev = 0.3 * sin(.pi * t / 1.0)  // half sine: 0 -> +peak -> 0, never negative
            counter.ingest(AccelSample(time: t, x: 0, y: 0, z: 1.0 + max(dev, 0)))
            t += 0.1
        }
        XCTAssertEqual(counter.count, 0)
    }

    func testStuckMidCycleAbandonsWithoutCounting() {
        let counter = RepCounter(maxRepDuration: 1.0)
        counter.ingest(AccelSample(time: 0.0, x: 0, y: 0, z: 1.0))
        counter.ingest(AccelSample(time: 0.1, x: 0, y: 0, z: 1.0 + 0.3))  // outbound, never reverses
        counter.ingest(AccelSample(time: 2.0, x: 0, y: 0, z: 1.0 + 0.3))  // way past maxRepDuration
        XCTAssertEqual(counter.count, 0)
        // Counter should have reset to resting and be ready to detect fresh motion.
        counter.ingest(AccelSample(time: 2.1, x: 0, y: 0, z: 1.0))
        feedRep(into: counter, startTime: 2.2)
        XCTAssertEqual(counter.count, 1)
    }

    func testResetClears() {
        let counter = RepCounter()
        feedRep(into: counter)
        XCTAssertGreaterThan(counter.count, 0)
        counter.reset()
        XCTAssertEqual(counter.count, 0)
    }

    func testBaselineAdaptsToOrientationAtRest() {
        // If the pin rests with a different gravity orientation (e.g. z = 0.9
        // instead of 1.0), the baseline should adapt during quiet periods so
        // reps are still detected from the *change*, not the absolute value.
        let counter = RepCounter()
        for i in 0..<20 {
            counter.ingest(AccelSample(time: Double(i) / 10.0, x: 0, y: 0, z: 0.9))
        }
        var t = 2.0
        let duration = 2.0
        while t <= 2.0 + duration {
            let dev = 0.3 * sin(2 * .pi * (t - 2.0) / duration)
            counter.ingest(AccelSample(time: t, x: 0, y: 0, z: 0.9 + dev))
            t += 0.1
        }
        XCTAssertEqual(counter.count, 1)
    }
}
