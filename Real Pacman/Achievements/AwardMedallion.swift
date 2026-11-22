import SwiftUI

/// A single, finite burst. The surrounding score entrance supplies the 0.97 reveal.
struct AwardMedallion: View {
    let symbol: String
    let reveal: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Frame {
        var scale: CGFloat = 1
        var turn = 0.0
        var glow = 0.25
        var burst = 0.0
        var travel: CGFloat = 0
    }

    var body: some View {
        let motionReduced = reduceMotion
        ZStack {
            Circle()
                .fill(.yellow.opacity(0.08))
                .frame(width: 210, height: 210)
            Circle()
                .strokeBorder(.yellow.opacity(0.18), lineWidth: 1)
                .frame(width: 198, height: 198)
            ForEach(0..<12) { ray in
                Capsule()
                    .fill(.yellow.opacity(0.4))
                    .frame(width: 2, height: 10)
                    .offset(y: -96)
                    .rotationEffect(.degrees(Double(ray) * 30))
            }
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.94, blue: 0.56), .yellow, Color(red: 0.75, green: 0.39, blue: 0.04)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(.white.opacity(0.75), lineWidth: 2).padding(4)
                Circle().fill(Color(red: 0.045, green: 0.085, blue: 0.18)).padding(12)
                Circle().strokeBorder(.yellow.opacity(0.5), lineWidth: 1).padding(17)
                Image(systemName: symbol)
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.45), radius: 12)
            }
            .frame(width: 164, height: 164)
        }
        .frame(width: 220, height: 220)
        .keyframeAnimator(initialValue: Frame(), trigger: reveal) { medal, frame in
            medal
                .scaleEffect(motionReduced ? 1 : frame.scale)
                .rotationEffect(.degrees(motionReduced ? 0 : frame.turn))
                .shadow(color: .yellow.opacity(motionReduced ? 0.25 : frame.glow), radius: 24)
                .overlay {
                    if !motionReduced {
                        ForEach(0..<18) { particle in
                            let angle = Double(particle) * .pi / 9
                            RoundedRectangle(cornerRadius: 1)
                                .fill(particle.isMultiple(of: 3) ? Color.white : Color.yellow)
                                .frame(width: 4, height: particle.isMultiple(of: 2) ? 9 : 5)
                                .rotationEffect(.degrees(Double(particle) * 20 + Double(frame.travel) * 90))
                                .offset(x: cos(angle) * (82 + frame.travel * 65),
                                        y: sin(angle) * (82 + frame.travel * 65))
                                .opacity(frame.burst)
                        }
                    }
                }
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.10, duration: 0.18)
                CubicKeyframe(0.97, duration: 0.12)
                CubicKeyframe(1, duration: 0.20)
            }
            KeyframeTrack(\.turn) {
                CubicKeyframe(-6, duration: 0.12)
                CubicKeyframe(4, duration: 0.16)
                CubicKeyframe(0, duration: 0.22)
            }
            KeyframeTrack(\.glow) {
                LinearKeyframe(0.7, duration: 0.18)
                LinearKeyframe(0.25, duration: 0.72)
            }
            KeyframeTrack(\.burst) {
                LinearKeyframe(1, duration: 0.10)
                LinearKeyframe(1, duration: 0.15)
                LinearKeyframe(0, duration: 0.65)
            }
            KeyframeTrack(\.travel) {
                CubicKeyframe(1, duration: 0.9)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
