import SwiftUI

/// Shared walk/demo HUD; the map keeps the remaining screen space.
struct GameplayDashboard<Controls: View>: View {
    let score: Int
    let collected: Int
    let total: Int
    let distance: Double
    let isPlaying: Bool
    var isDemo = false
    let status: String
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(isDemo ? "PRACTICE RUN" : "EXPLORE", systemImage: isDemo ? "dpad.fill" : "figure.walk")
                    .font(.caption.weight(.black)).tracking(1)
                    .foregroundStyle(.cyan)
                Spacer()
                Label(isPlaying ? "PLAYING" : "PAUSED", systemImage: isPlaying ? "play.circle.fill" : "pause.circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isPlaying ? .green : .yellow)
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("\(score)", systemImage: "star.fill")
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundStyle(.yellow)
                    Text(isDemo ? "DEMO POINTS" : "POINTS")
                        .font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.65))
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(collected) / \(total)")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                    Text("PELLETS COLLECTED")
                        .font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.65))
                }
                .accessibilityElement(children: .combine)
            }
            ProgressView(value: Double(collected), total: Double(max(total, 1)))
                .tint(.yellow)
                .accessibilityLabel("Pellet collection")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { statusLabel; Spacer(minLength: 0); distanceLabel }
                VStack(alignment: .leading, spacing: 6) { statusLabel; distanceLabel }
            }
            controls()
            Text(isDemo ? "Practice only · scores stay out of Statistics" : "Stay on public paths. Keep an eye on your surroundings.")
                .font(.caption2).foregroundStyle(.white.opacity(0.55))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(red: 0.08, green: 0.15, blue: 0.29),
                                              Color(red: 0.035, green: 0.07, blue: 0.16)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(.cyan.opacity(0.25), lineWidth: 1) }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var statusLabel: some View {
        Label(status, systemImage: isDemo ? "gamecontroller" : "location.circle")
            .font(.caption).foregroundStyle(.white.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var distanceLabel: some View {
        Label("\(Int(distance.rounded())) m", systemImage: "shoeprints.fill")
            .font(.caption.weight(.semibold)).monospacedDigit()
            .foregroundStyle(.cyan.opacity(0.9))
            .fixedSize()
            .accessibilityLabel("Distance travelled, \(Int(distance.rounded())) metres")
    }
}
