import Foundation
import Observation

/// Whether a given machine may be used right now.
enum MachineAccess: Equatable {
    case subscribed       // full access — any machine
    case trialMachine     // the user's claimed free machine
    case trialAvailable   // no free machine claimed yet; using one claims it
    case locked           // needs a subscription
}

/// Free-trial policy: an un-subscribed user gets full Pinpoint functionality on
/// **one machine of their choice**. The first machine they run becomes their
/// free machine; any other machine prompts a subscription.
@Observable @MainActor
final class TrialStore {
    private(set) var trialMachineID: String?
    private(set) var trialMachineName: String?

    nonisolated init() {
        trialMachineID = UserDefaults.standard.string(forKey: "trialMachineID")
        trialMachineName = UserDefaults.standard.string(forKey: "trialMachineName")
    }

    /// Pure access decision — also used directly in tests.
    func access(machineID: String, isSubscribed: Bool) -> MachineAccess {
        if isSubscribed { return .subscribed }
        guard let claimed = trialMachineID else { return .trialAvailable }
        return claimed == machineID ? .trialMachine : .locked
    }

    func claim(machineID: String, name: String) {
        trialMachineID = machineID
        trialMachineName = name
        UserDefaults.standard.set(machineID, forKey: "trialMachineID")
        UserDefaults.standard.set(name, forKey: "trialMachineName")
    }

    func reset() {
        trialMachineID = nil
        trialMachineName = nil
        UserDefaults.standard.removeObject(forKey: "trialMachineID")
        UserDefaults.standard.removeObject(forKey: "trialMachineName")
    }
}
