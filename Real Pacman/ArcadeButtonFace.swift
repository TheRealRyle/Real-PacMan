import SwiftUI

/// Owns animation state so a quick tap still gets a visible compression and rebound.
struct ArcadeButtonFace<Label: View>: View {
    let label: Label
    let color: Color
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.arcadeButtonActivated) private var activated
    @State private var compressed = false
    @State private var releaseAt = Date.distantPast

    var body: some View {
        label
            .font(.title3.weight(.black))
            .foregroundStyle(Color(red: 0.06, green: 0.12, blue: 0.2))
            .padding(18)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.65), lineWidth: 3)
                    .padding(4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.6), lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.45), radius: 0, y: compressed ? 2 : 6)
            .offset(y: reduceMotion ? 0 : (compressed ? 5 : 0))
            .scaleEffect(
                x: reduceMotion ? 1 : (compressed ? 0.93 : 1),
                y: reduceMotion ? 1 : (compressed ? 0.84 : 1)
            )
            .onChange(of: isPressed) {
                if isPressed { compress() }
            }
            .onChange(of: activated) {
                // Scroll views can delay touch-down feedback. Activation guarantees a pop
                // even when the native pressed state was too short to be rendered.
                if activated { compress() }
            }
            .task(id: releaseKey) {
                guard compressed, !isPressed else { return }
                let remaining = max(0, releaseAt.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(remaining)) }
                catch { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.36)) {
                    compressed = false
                }
            }
            .onChange(of: reduceMotion) {
                if reduceMotion { compressed = false }
            }
    }

    private var releaseKey: String {
        "\(isPressed)-\(releaseAt.timeIntervalSinceReferenceDate)"
    }

    private func compress() {
        guard !reduceMotion else { return }
        releaseAt = Date().addingTimeInterval(0.09)
        withAnimation(.easeOut(duration: 0.055)) { compressed = true }
    }
}
