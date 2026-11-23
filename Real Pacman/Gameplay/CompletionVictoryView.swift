import SwiftUI

struct CompletionVictoryView: View {
    let score: Int
    let isDemo: Bool
    let revealed: Bool

    var body: some View {
        VStack(spacing: 16) {
            Label("ALL PELLETS COLLECTED", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.black)).tracking(1.2)
                .foregroundStyle(.cyan)
                .multilineTextAlignment(.center)
            AwardMedallion(symbol: "trophy.fill", reveal: revealed)
            Text("PARCOURS\nCOMPLETE!")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .yellow.opacity(0.25), radius: 16)
                .accessibilityAddTraits(.isHeader)
            Text(isDemo ? "Practice perfected." : "You cleared the whole parcours.")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
            CompletionScoreCounter(score: score, isDemo: isDemo, revealed: revealed)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompletionScoreCounter: View {
    let score: Int
    let isDemo: Bool
    let revealed: Bool
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 64

    private struct Frame {
        var points = 0.0
        var scale: CGFloat = 1
    }

    var body: some View {
        let size = scoreSize
        VStack(spacing: 4) {
            CompletionScoreDigits(value: score, size: size)
                .hidden()
                .overlay {
                    if reduceMotion || !animated {
                        CompletionScoreDigits(value: score, size: size)
                    } else {
                        // Initial presentation may already be settled when this view is restored.
                        Color.clear
                            .keyframeAnimator(initialValue: Frame(points: revealed ? Double(score) : 0), trigger: revealed) { _, frame in
                                CompletionScoreDigits(value: Int(frame.points.rounded()), size: size)
                                    .scaleEffect(frame.scale)
                            } keyframes: { _ in
                                KeyframeTrack(\.points) {
                                    CubicKeyframe(Double(score), duration: 0.85)
                                }
                                KeyframeTrack(\.scale) {
                                    LinearKeyframe(1, duration: 0.85)
                                    CubicKeyframe(1.05, duration: 0.12)
                                    CubicKeyframe(1, duration: 0.15)
                                }
                            }
                    }
                }
            Text(isDemo ? "DEMO POINTS" : "POINTS EARNED")
                .font(.caption.weight(.heavy)).tracking(2)
                .foregroundStyle(.yellow.opacity(0.8))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.yellow.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.yellow.opacity(0.2), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score) \(isDemo ? "demo points" : "points")")
    }
}

private struct CompletionScoreDigits: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        Text(value.formatted())
            .font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit().foregroundStyle(.yellow)
            .lineLimit(1).minimumScaleFactor(0.5)
    }
}
