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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var isComplete: Bool {
        total > 0 && collected == total && (rules?.outcome == nil || rules?.outcome == .completed)
    }

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.05, blue: 0.12).ignoresSafeArea()
            if isComplete {
                RadialGradient(colors: [.yellow.opacity(0.13), .clear], center: .top, startRadius: 30, endRadius: 500)
                    .ignoresSafeArea().allowsHitTesting(false)
            }
            ScrollView {
                VStack(spacing: 24) {
                    if isComplete {
                        CompletionVictoryView(score: score, isDemo: isDemo, revealed: revealed)
                    } else {
                        outcomeHeader
                    }
                    if !isDemo, !unlockedAchievements.isEmpty {
                        Label("\(unlockedAchievements.count) new \(unlockedAchievements.count == 1 ? "achievement" : "achievements") unlocked", systemImage: "sparkles")
                            .font(.subheadline.weight(.bold)).foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                    }
                    CompletionSummaryView(collected: collected, total: total, distance: distance, rules: rules, revealed: revealed)
                        .arcadeEntrance(delay: reduceMotion ? 0 : 0.35)
                    Label(isDemo ? "Practice score · not saved to Statistics" : "Saved in Statistics · queued for sync",
                          systemImage: isDemo ? "dpad.fill" : "checkmark.icloud.fill")
                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                    if !isDemo, !unlockedAchievements.isEmpty {
                        AchievementUnlocksView(achievements: unlockedAchievements, playsSound: !isComplete,
                                               announcesUnlock: !isComplete)
                    }
                }
                .padding(28)
                .frame(maxWidth: 580).frame(maxWidth: .infinity)
                .arcadeEntrance()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                if let restart {
                    Button("PLAY AGAIN", action: restart)
                        .buttonStyle(ArcadeButtonStyle(color: .green))
                }
                Button { dismiss() } label: {
                    Label("DONE", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(ArcadeButtonStyle(color: .cyan))
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.025, green: 0.05, blue: 0.12).opacity(0.98))
        }
        .navigationTitle(isComplete ? "Victory" : "Score")
        .navigationBarBackButtonHidden()
        .task(id: scenePhase) {
            guard scenePhase == .active, !revealed else { return }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            revealed = true
            if isComplete {
                ArcadeAudio.shared.play(.achievementUnlocked)
                let badges = !isDemo && !unlockedAchievements.isEmpty
                    ? " Achievements unlocked: \(unlockedAchievements.map(\.title).joined(separator: ", "))." : ""
                AccessibilityNotification.Announcement("Parcours complete. \(score) \(isDemo ? "demo points" : "points").\(badges)").post()
            }
        }
    }

    private var outcomeHeader: some View {
        VStack(spacing: 18) {
            Image(systemName: rules?.outcome == .caught ? "eye.fill" : rules?.outcome == .timedOut ? "hourglass" : "flag.checkered")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(rules?.outcome == .stopped || rules?.outcome == nil ? Color.cyan : Color.pink)
                .accessibilityHidden(true)
            Text(rules?.outcome?.title ?? "WALK SAVED")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(.white).multilineTextAlignment(.center)
            CompletionScoreCounter(score: score, isDemo: isDemo, revealed: true, animated: false)
        }
    }
}
