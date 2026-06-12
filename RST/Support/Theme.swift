import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.35, blue: 0.31)
    static let accentDim = Color(red: 0.55, green: 0.17, blue: 0.15)
    static let background = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let card = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let warning = Color(red: 0.98, green: 0.73, blue: 0.25)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.42, blue: 0.35), Color(red: 0.78, green: 0.12, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
