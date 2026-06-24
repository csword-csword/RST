import SwiftUI
import UIKit

/// Small "PRO" capsule used to mark Pinpoint Pro features in the UI.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.accentGradient, in: Capsule())
            .foregroundStyle(.white)
    }
}

/// Thin wrapper around `UIActivityViewController` for sharing a file (e.g. the
/// exported CSV) via the system share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
