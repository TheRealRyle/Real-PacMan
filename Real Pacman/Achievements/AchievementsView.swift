import SwiftUI

struct AchievementsView: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        let progress = game.achievements
        let unlocked = progress.filter(\.isUnlocked).count
        ArcadePage(title: "ACHIEVEMENTS", symbol: "trophy.fill",
                   titleFont: .system(.title2, design: .rounded, weight: .black)) {
            AchievementSummary(unlocked: unlocked, total: progress.count)
                .arcadeEntrance(delay: 0.08)
            Text("Every run has something to aim for.")
                .font(.title3.weight(.bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                ForEach(progress) { item in
                    AchievementCard(progress: item)
                }
            }
            Text("Earned from saved real runs on this device. Replays count. Demo runs are practice. Quick Clear and Double Feature include pauses and breaks.")
                .font(.caption).foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AchievementSummary: View {
    let unlocked: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.yellow)
                    .frame(width: 78, height: 78)
                    .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR TROPHY CABINET")
                        .font(.caption.weight(.heavy)).tracking(1).foregroundStyle(.cyan)
                    Text("\(unlocked) / \(total)")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(.yellow).monospacedDigit()
                    Text(unlocked == total ? "Collection complete!" : "achievements unlocked")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
            }
            ProgressView(value: Double(unlocked), total: Double(total))
                .tint(.yellow)
                .accessibilityLabel("Achievements unlocked")
                .accessibilityValue("\(unlocked) of \(total)")
            Text(unlocked == 0 ? "Save your first run to earn your first badge." : "Your next adventure could earn the next badge.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.9))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.035, green: 0.09, blue: 0.20).gradient, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.yellow.opacity(0.4), lineWidth: 1.5) }
    }
}

private struct AchievementCard: View {
    let progress: AchievementProgress
    private var accent: Color { progress.isUnlocked ? .yellow : .cyan }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: progress.achievement.symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 52, height: 52)
                    .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Label(progress.isUnlocked ? "UNLOCKED" : "LOCKED", systemImage: progress.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(progress.isUnlocked ? Color.yellow : Color.white.opacity(0.6))
            }
            Text(progress.achievement.title)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text(progress.achievement.requirement)
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            ProgressView(value: progress.fraction).tint(accent)
                .accessibilityLabel(progress.achievement.title)
                .accessibilityValue("\(progress.current) of \(progress.achievement.target) \(progress.achievement.progressUnit)")
            if let date = progress.unlockedAt {
                Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption.weight(.semibold)).foregroundStyle(.yellow)
            } else {
                Text("\(progress.current) / \(progress.achievement.target) \(progress.achievement.progressUnit)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.04, green: 0.10, blue: 0.22), in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(accent.opacity(progress.isUnlocked ? 0.5 : 0.2), lineWidth: 1) }
    }
}

#Preview {
    NavigationStack { AchievementsView() }
        .environment(GameStore())
}
