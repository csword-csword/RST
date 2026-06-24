import SwiftUI
import UIKit

/// Step 4: live set/rep tracking driven by the smart pin's accelerometer,
/// with a between-sets rest timer and an optional (Pro) voice coach.
struct ActiveSetView: View {
    @Environment(\.pinDevice) private var pin
    @Environment(\.subscriptions) private var subscriptions
    let entry: ExerciseEntry
    let machine: Machine
    let planned: TemplateExercise?
    let unit: WeightUnit
    var onFinishExercise: () -> Void

    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @AppStorage("voiceCoachEnabled") private var voiceCoachEnabled = false

    @State private var setStartedAt: Date?
    @State private var restStartedAt: Date?
    @State private var restRemaining = 0
    @State private var restDone = false
    @State private var voice = VoiceCoach()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var targetReps: Int { planned?.targetReps ?? 10 }
    private var voiceActive: Bool { subscriptions.isSubscribed && voiceCoachEnabled }

    var body: some View {
        VStack(spacing: 20) {
            connectionBanner

            VStack(spacing: 4) {
                Text(machine.name)
                    .font(.title3.bold())
                Text(formatWeight(entry.weight, unit: unit))
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            switch pin.phase {
            case .idle:
                idleContent
            case .lifting:
                liftingContent
            case .resting:
                // A fresh machine can inherit .resting from the previous
                // exercise; show the ready state until a set is logged here.
                if entry.sets.isEmpty {
                    idleContent
                } else {
                    restingContent
                }
            }

            Spacer()

            if !entry.sets.isEmpty {
                completedSets
            }

            bottomButtons
        }
        .padding()
        .background(Theme.background)
        .task { await pin.connect() }
        .onAppear {
            voice.enabled = voiceActive
            if voiceActive { voice.configureAudioSession() }
        }
        .onDisappear { voice.stop() }
        .onChange(of: pin.phase) { oldPhase, newPhase in
            if oldPhase == .lifting && newPhase == .resting {
                logSet()
            }
        }
        .onChange(of: pin.repCount) { oldCount, newCount in
            if pin.phase == .lifting, voiceActive, newCount > oldCount, newCount > 0 {
                voice.rep(newCount)
            }
        }
        .onReceive(ticker) { _ in tickRest() }
    }

    @ViewBuilder
    private var connectionBanner: some View {
        switch pin.connectionState {
        case .connected:
            Label("Smart Pin connected", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.accent)
        case .scanning:
            Label("Connecting to Smart Pin…", systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        case .disconnected:
            Label("Smart Pin disconnected", systemImage: "antenna.radiowaves.left.and.right.slash")
                .font(.caption.bold())
                .foregroundStyle(Theme.warning)
        }
    }

    private var idleContent: some View {
        VStack(spacing: 16) {
            repRing(count: 0)
            Text("Set \(entry.sets.count + 1)")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var liftingContent: some View {
        VStack(spacing: 16) {
            repRing(count: pin.repCount)
            Text("Set \(entry.sets.count + 1) — lifting")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var restingContent: some View {
        VStack(spacing: 14) {
            Image(systemName: restDone ? "bolt.fill" : "pause.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(restDone ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.accent))
            Text(restDone ? "Ready for your next set" : "Rest")
                .font(.title2.bold())

            if !restDone {
                Text(timeString(restRemaining))
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: restRemaining)
                HStack(spacing: 12) {
                    Button("+15s") { restRemaining += 15 }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                    Button("Skip Rest") { finishRest() }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                }
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func tickRest() {
        guard pin.phase == .resting, !entry.sets.isEmpty, !restDone, restRemaining > 0 else { return }
        restRemaining -= 1
        if voiceActive, (1...3).contains(restRemaining) {
            voice.restCountdown(restRemaining)
        }
        if restRemaining == 0 { finishRest() }
    }

    private func finishRest() {
        restRemaining = 0
        guard !restDone else { return }
        restDone = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if voiceActive { voice.nextSet() }
    }

    private func repRing(count: Int) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 16)
            Circle()
                .trim(from: 0, to: min(Double(count) / Double(targetReps), 1))
                .stroke(Theme.accentGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: count)
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: count)
                Text("REPS")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }
        }
        .frame(width: 220, height: 220)
    }

    private var completedSets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(entry.sortedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    VStack(spacing: 2) {
                        Text("Set \(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(set.reps)")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxHeight: 60)
    }

    @ViewBuilder
    private var bottomButtons: some View {
        switch pin.phase {
        case .idle, .resting:
            VStack(spacing: 12) {
                Button {
                    startSet()
                } label: {
                    Label(entry.sets.isEmpty ? "Start Set" : "Start Next Set", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(pin.connectionState != .connected)
                .opacity(pin.connectionState == .connected ? 1 : 0.5)

                Button("Finish Exercise") {
                    pin.endSet()
                    onFinishExercise()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(entry.sets.isEmpty)
                .opacity(entry.sets.isEmpty ? 0.5 : 1)
            }
        case .lifting:
            Button("End Set") {
                pin.endSet()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func startSet() {
        setStartedAt = .now
        restStartedAt = nil
        restDone = false
        restRemaining = 0
        pin.beginSet()
    }

    private func logSet() {
        restStartedAt = .now
        guard pin.repCount > 0 else { return }
        let record = SetRecord(reps: pin.repCount,
                               weight: entry.weight,
                               startedAt: setStartedAt ?? .now)
        entry.sets.append(record)

        // Begin the rest timer for the next set.
        restRemaining = max(defaultRestSeconds, 0)
        restDone = restRemaining == 0
        if voiceActive { voice.setComplete(reps: record.reps) }
    }
}
