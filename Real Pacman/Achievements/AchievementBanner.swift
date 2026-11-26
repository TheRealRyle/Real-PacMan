import SwiftUI

/// A compact arcade title card; the earned award remains in the trophy cabinet.
struct AchievementBanner: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(.yellow)
                .shadow(color: .black, radius: 0, x: 2, y: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("CONGRATS!")
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .tracking(1)
                    .shadow(color: .black, radius: 0, x: 1, y: 2)
                Text(achievement.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.yellow.opacity(0.95))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20).padding(.vertical, 15)
        .frame(maxWidth: 440)
        .background {
            RoundedRectangle(cornerRadius: 13)
                .fill(LinearGradient(colors: [Color(red: 0.66, green: 0.36, blue: 0.18),
                                              Color(red: 0.43, green: 0.21, blue: 0.12)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13).strokeBorder(.black, lineWidth: 3)
            RoundedRectangle(cornerRadius: 10).inset(by: 4)
                .strokeBorder(Color(red: 1, green: 0.89, blue: 0.59), lineWidth: 1.5)
        }
        .shadow(color: .cyan.opacity(0.65), radius: 10)
        .shadow(color: .black.opacity(0.5), radius: 8, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Achievement unlocked: \(achievement.title)")
    }
}

struct AchievementBannerQueue: View {
    let achievements: [Achievement]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var current: Achievement?
    @State private var presentedAchievements: [Achievement] = []
    @State private var nextIndex = 0

    private struct Presentation: Equatable {
        let achievements: [Achievement]
        let isActive: Bool
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let current {
                AchievementBanner(achievement: current)
                    .id(current)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.97).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20).padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .task(id: Presentation(achievements: achievements, isActive: scenePhase == .active)) {
            if presentedAchievements != achievements {
                presentedAchievements = achievements
                nextIndex = 0
                current = nil
            }
            guard scenePhase == .active else { current = nil; return }
            do {
                while nextIndex < achievements.count {
                    try Task.checkCancellation()
                    let achievement = achievements[nextIndex]
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                        current = achievement
                    }
                    // Let the completion announcement finish before announcing the award.
                    try await Task.sleep(for: .milliseconds(700))
                    AccessibilityNotification.Announcement("Achievement unlocked: \(achievement.title).").post()
                    try await Task.sleep(for: .seconds(voiceOver ? 7 : 4))
                    nextIndex += 1
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { current = nil }
                    try await Task.sleep(for: .milliseconds(300))
                }
            } catch {
                // Leaving gameplay cancels the queue; backgrounding resumes this award.
            }
        }
    }
}

#Preview("Achievement title card") {
    ZStack {
        Color(red: 0.025, green: 0.05, blue: 0.12).ignoresSafeArea()
        AchievementBanner(achievement: .pocketful).padding(20)
    }
}
