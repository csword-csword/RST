import XCTest
@testable import RST

final class RepCounterTests: XCTestCase {
    /// Generates `reps` acceleration pulses at `sampleHz`, each a half-sine bump
    /// of `peak` g above a 1 g gravity baseline, spaced `period` seconds apart.
    private func feed(into counter: RepCounter,
                      reps: Int,
                      period: Double = 2.0,
                      peak: Double = 0.35,
                      sampleHz: Double = 6) {
        let dt = 1.0 / sampleHz
        var t = 0.0
        let end = period * Double(reps)
        while t < end {
            let phase = t.truncatingRemainder(dividingBy: period) / period
            // A short bump occupying the first third of each rep period.
            let bump = phase < 0.33 ? sin(phase / 0.33 * .pi) * peak : 0
            counter.ingest(AccelSample(time: t, magnitudeG: 1.0 + bump))
            t += dt
        }
    }

    func testCountsCleanReps() {
        let counter = RepCounter()
        feed(into: counter, reps: 8)
        XCTAssertEqual(counter.count, 8)
    }

    func testRefractoryRejectsDoubleCount() {
        // Two pulses closer together than minRepInterval should count once.
        let counter = RepCounter(minRepInterval: 0.7)
        counter.ingest(AccelSample(time: 0.0, magnitudeG: 1.0))
        counter.ingest(AccelSample(time: 0.1, magnitudeG: 1.4))  // rep 1
        counter.ingest(AccelSample(time: 0.2, magnitudeG: 1.0))
        counter.ingest(AccelSample(time: 0.3, magnitudeG: 1.4))  // within refractory
        XCTAssertEqual(counter.count, 1)
    }

    func testQuietSignalCountsNothing() {
        let counter = RepCounter()
        for i in 0..<60 {
            counter.ingest(AccelSample(time: Double(i) / 6.0, magnitudeG: 1.0))
        }
        XCTAssertEqual(counter.count, 0)
    }

    func testResetClears() {
        let counter = RepCounter()
        feed(into: counter, reps: 3)
        XCTAssertGreaterThan(counter.count, 0)
        counter.reset()
        XCTAssertEqual(counter.count, 0)
    }
}
