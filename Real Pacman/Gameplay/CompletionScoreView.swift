import SwiftUI

struct CompletionScoreView: View {
    let score: Int
    let collected: Int
    let total: Int
    let distance: Double
    var isDemo = false
    var restart: (() -> Void)? = nil
    var rules: ModeProgress? = nil
    var unlockedAchievements: [Achievement] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ArcadeBackground()
            ScrollView {
                VStack(spacing: 24) {
                    if !isDemo, !unlockedAchievements.isEmpty {
                        AchievementUnlocksView(achievements: unlockedAchievements)
                    } else {
                        Image(systemName: collected == total ? "trophy.fill" : "checkmark.circle.fill")
                            .font(.system(size: 72)).foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                    Text(rules?.outcome?.title ?? (collected == total ? "PARCOURS COMPLETE!" : "WALK SAVED"))
                        .font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text("\(score) \(isDemo ? "demo points" : "points")")
                        .font(.largeTitle.weight(.black)).foregroundStyle(.yellow)
                    Text("\(collected) / \(total) pellets collected")
                        .font(.title3)
                    Text("\(Int(distance.rounded())) m travelled").font(.headline)
                    if let rules {
                        Text("\(Int(rules.activeElapsed)) seconds of active play").font(.subheadline)
                        if !rules.ghosts.isEmpty { Text("\(rules.livesRemaining) lives remaining").font(.headline) }
                    }
                    Text(isDemo ? "Practice score · not saved to Statistics" : "Your result is saved in Statistics and queued for sync.")
                        .font(.subheadline).multilineTextAlignment(.center)
                    if let restart {
                        Button("PLAY AGAIN", action: restart).buttonStyle(ArcadeButtonStyle(color: .green))
                    }
                    Button("DONE") { dismiss() }.buttonStyle(ArcadeButtonStyle(color: .cyan))
                }
                .foregroundStyle(.white)
                .padding(28)
                .frame(maxWidth: 580).frame(maxWidth: .infinity)
                .arcadeEntrance()
            }
        }
        .navigationTitle("Score")
        .navigationBarBackButtonHidden()
    }
}
