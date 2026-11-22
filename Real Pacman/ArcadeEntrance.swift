import SwiftUI

/// A subtle one-shot entrance that cancels when its element leaves the screen.
struct ArcadeEntrance: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion || appeared ? 1 : 0.97)
            .opacity(reduceMotion || appeared ? 1 : 0)
            .task {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func arcadeEntrance(delay: Double = 0) -> some View {
        modifier(ArcadeEntrance(delay: delay))
    }
}
