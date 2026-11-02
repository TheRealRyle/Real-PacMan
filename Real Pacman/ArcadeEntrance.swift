import SwiftUI

/// A one-shot pop that stays local to each element and cancels when it leaves the screen.
struct ArcadeEntrance: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion || appeared ? 1 : 0.72)
            .offset(y: reduceMotion || appeared ? 0 : 28)
            .opacity(reduceMotion || appeared ? 1 : 0)
            .task {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.48)) {
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
