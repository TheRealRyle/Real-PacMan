import SwiftUI

struct AchievementUnlocksView: View {
    let achievements: [Achievement]
    var playsSound = true
    var announcesUnlock = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        if let featured = achievements.first {
            VStack(spacing: 18) {
                Text(achievements.count == 1 ? "ACHIEVEMENT UNLOCKED" : "\(achievements.count) ACHIEVEMENTS UNLOCKED")
                    .font(.caption.weight(.black)).tracking(2)
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                AwardMedallion(symbol: featured.symbol, reveal: revealed)
                VStack(spacing: 10) {
                    Text(featured.title.uppercased())
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .yellow.opacity(0.25), radius: 12)
                        .accessibilityAddTraits(.isHeader)
                    Text(featured.requirement)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                if achievements.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALSO EARNED THIS RUN")
                            .font(.caption2.weight(.heavy)).tracking(1.5)
                            .foregroundStyle(.yellow.opacity(0.85))
                        ForEach(Array(achievements.dropFirst())) { achievement in
                            Label(achievement.title, systemImage: achievement.symbol)
                                .font(.headline).foregroundStyle(.white)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                }
                Text("Added to your trophy cabinet")
                    .font(.caption.weight(.semibold)).foregroundStyle(.yellow.opacity(0.9))
                ArcadeNavigationLink { AchievementsView() } label: {
                    Label("VIEW ACHIEVEMENTS", systemImage: "trophy.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ArcadeButtonStyle(color: .yellow))
            }
            .padding(.horizontal, 20).padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.25),
                                                  Color(red: 0.025, green: 0.05, blue: 0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(.yellow.opacity(0.65), lineWidth: 1.5) }
            .shadow(color: .yellow.opacity(0.15), radius: 20)
            .task(id: scenePhase) {
                guard scenePhase == .active, !revealed else { return }
                // Let the shared 0.97 entrance settle before the medal's one-shot burst.
                if !reduceMotion {
                    do { try await Task.sleep(for: .milliseconds(250)) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                revealed = true
                if playsSound { ArcadeAudio.shared.play(.achievementUnlocked) }
                if announcesUnlock {
                    AccessibilityNotification.Announcement("Achievement unlocked: \(achievements.map(\.title).joined(separator: ", ")).").post()
                }
            }
        }
    }
}
