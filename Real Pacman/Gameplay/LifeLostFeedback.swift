import SwiftUI

/// Lives are observed above the gameplay/score switch so the final hit also fires.
struct LifeLostFeedback: ViewModifier {
    let lives: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var hit = 0

    private struct Frame {
        var shake: CGFloat = 0
        var tint = 0.0
        var notice = 0.0
    }

    func body(content: Content) -> some View {
        let motionReduced = reduceMotion
        return content
            .keyframeAnimator(initialValue: Frame(), trigger: hit) { view, frame in
                view
                    .offset(x: motionReduced ? 0 : frame.shake)
                    .overlay {
                        Color.red.opacity(frame.tint * (motionReduced ? 0.5 : 1))
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .overlay(alignment: .top) {
                        Text("LIFE LOST")
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(.red.opacity(0.9), in: Capsule())
                            .padding(.top, 12)
                            .opacity(frame.notice)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
            } keyframes: { _ in
                KeyframeTrack(\.shake) {
                    LinearKeyframe(-8, duration: 0.06)
                    LinearKeyframe(8, duration: 0.06)
                    LinearKeyframe(-5, duration: 0.06)
                    LinearKeyframe(5, duration: 0.06)
                    LinearKeyframe(-2, duration: 0.06)
                    LinearKeyframe(0, duration: 0.06)
                }
                KeyframeTrack(\.tint) {
                    LinearKeyframe(0.16, duration: 0.06)
                    LinearKeyframe(0, duration: 0.30)
                }
                KeyframeTrack(\.notice) {
                    LinearKeyframe(1, duration: 0.06)
                    LinearKeyframe(1, duration: 0.40)
                    LinearKeyframe(0, duration: 0.24)
                }
            }
            .onChange(of: lives) { before, after in
                guard scenePhase == .active, let before, let after, after < before else { return }
                hit += 1
                ArcadeAudio.shared.play(.lifeLost)
                AccessibilityNotification.Announcement("Life lost. \(after) \(after == 1 ? "life" : "lives") remaining.").post()
            }
    }
}
