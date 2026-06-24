import AVFoundation
import Foundation

/// Speaks rep counts and set/rest cues for users training with headphones.
/// Ducks other audio (music/podcasts) while speaking. A Pro feature.
@MainActor
final class VoiceCoach {
    private let synth = AVSpeechSynthesizer()
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var enabled = false

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio,
                                 options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
    }

    func rep(_ count: Int) {
        say("\(count)")
    }

    func setComplete(reps: Int) {
        say("Set complete. \(reps) reps. Rest now.")
    }

    func restCountdown(_ seconds: Int) {
        say("\(seconds)")
    }

    func nextSet() {
        say("Time for your next set.")
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    private func say(_ text: String) {
        guard enabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        synth.speak(utterance)
    }
}
