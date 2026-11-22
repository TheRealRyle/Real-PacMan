import SwiftUI

struct AchievementUnlocksView: View {
    let achievements: [Achievement]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("ACHIEVEMENTS UNLOCKED", systemImage: "sparkles")
                .font(.caption.weight(.heavy)).foregroundStyle(.yellow)
                .accessibilityAddTraits(.isHeader)
            ForEach(achievements) { achievement in
                Label(achievement.title, systemImage: achievement.symbol)
                    .font(.headline).foregroundStyle(.white)
            }
            ArcadeNavigationLink { AchievementsView() } label: {
                Label("VIEW ACHIEVEMENTS", systemImage: "trophy.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ArcadeButtonStyle(color: .yellow))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.yellow.opacity(0.45), lineWidth: 1) }
    }
}
