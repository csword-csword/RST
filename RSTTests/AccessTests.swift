import XCTest
@testable import RST

@MainActor
final class AccessTests: XCTestCase {
    private func freshTrial() -> TrialStore {
        let store = TrialStore()
        store.reset()
        return store
    }

    func testSubscribedUnlocksEverything() {
        let trial = freshTrial()
        XCTAssertEqual(trial.access(machineID: "lat-pulldown", isSubscribed: true), .subscribed)
        XCTAssertEqual(trial.access(machineID: "leg-press", isSubscribed: true), .subscribed)
    }

    func testFirstMachineIsTrialAvailable() {
        let trial = freshTrial()
        XCTAssertEqual(trial.access(machineID: "lat-pulldown", isSubscribed: false), .trialAvailable)
    }

    func testClaimedMachineIsFreeButOthersLocked() {
        let trial = freshTrial()
        trial.claim(machineID: "lat-pulldown", name: "Lat Pulldown")
        XCTAssertEqual(trial.access(machineID: "lat-pulldown", isSubscribed: false), .trialMachine)
        XCTAssertEqual(trial.access(machineID: "leg-press", isSubscribed: false), .locked)
    }

    func testSubscriptionOverridesTrialLock() {
        let trial = freshTrial()
        trial.claim(machineID: "lat-pulldown", name: "Lat Pulldown")
        XCTAssertEqual(trial.access(machineID: "leg-press", isSubscribed: true), .subscribed)
    }

    func testResetClearsTrialMachine() {
        let trial = freshTrial()
        trial.claim(machineID: "lat-pulldown", name: "Lat Pulldown")
        trial.reset()
        XCTAssertNil(trial.trialMachineID)
        XCTAssertEqual(trial.access(machineID: "leg-press", isSubscribed: false), .trialAvailable)
    }
}
