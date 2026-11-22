import SwiftUI

struct LivesIndicator: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { slot in
                LifeHeart(isFull: slot < remaining)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining) \(remaining == 1 ? "life" : "lives") remaining")
    }
}

private struct LifeHeart: View {
    let isFull: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loss = 0

    private struct Frame {
        var scale: CGFloat = 1
        var rise: CGFloat = 0
        var echo = 0.0
    }

    var body: some View {
        let motionReduced = reduceMotion
        return Image(systemName: isFull ? "heart.fill" : "heart")
            .foregroundStyle(isFull ? Color.pink : Color.white.opacity(0.35))
            .keyframeAnimator(initialValue: Frame(), trigger: loss) { heart, frame in
                heart
                    .scaleEffect(motionReduced ? 1 : frame.scale)
                    .overlay {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .opacity(frame.echo)
                            .offset(y: motionReduced ? 0 : frame.rise)
                    }
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.25, duration: 0.10)
                    CubicKeyframe(0.97, duration: 0.12)
                    CubicKeyframe(1, duration: 0.18)
                }
                KeyframeTrack(\.rise) {
                    LinearKeyframe(-12, duration: 0.40)
                    MoveKeyframe(0)
                }
                KeyframeTrack(\.echo) {
                    MoveKeyframe(1)
                    LinearKeyframe(0, duration: 0.40)
                }
            }
            .onChange(of: isFull) { before, after in
                if before && !after { loss += 1 }
            }
    }
}
