import SwiftUI

struct ModeHUD: View {
    let mode: ParcoursMode
    let rules: ModeProgress?
    var body: some View {
        if mode != .explore, let rules {
            HStack {
                Label(mode.title, systemImage: mode.symbol)
                Spacer()
                if let remaining = rules.remainingSeconds {
                    Label(String(format: "%02d:%02d", remaining / 60, remaining % 60), systemImage: "timer")
                        .monospacedDigit().foregroundStyle(remaining < 60 ? .red : .yellow)
                        .accessibilityLabel("\(remaining) seconds remaining")
                }
                if mode.hasGhosts {
                    LivesIndicator(remaining: rules.livesRemaining)
                }
            }
            .font(.caption.bold()).foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 8)
            if mode.hasGhosts {
                Text("Virtual ghosts only · walk safely and stay on public paths")
                    .font(.caption2).foregroundStyle(.white.opacity(0.75)).padding(.horizontal)
            }
        }
    }
}
