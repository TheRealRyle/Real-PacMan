import SwiftUI

/// Waits for the release spring before acting. The view task cancels if the control disappears.
struct ArcadeActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pending = false

    var body: some View {
        Button {
            guard !pending else { return }
            ArcadeAudio.shared.play(.press)
            pending = true
        } label: { label() }
        .task(id: pending) {
            guard pending else { return }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(260)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            pending = false
            action()
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { pending = false }
        }
        .onDisappear { pending = false }
    }
}
