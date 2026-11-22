import SwiftUI

/// Waits for the release spring before acting. The view task cancels if the control disappears.
struct ArcadeActionButton<Label: View>: View {
    var sound: ArcadeSound? = .press
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pending = false

    var body: some View {
        Button {
            guard !pending else { return }
            if let sound { ArcadeAudio.shared.play(sound) }
            pending = true
        } label: { label() }
        .environment(\.arcadeButtonActivated, pending)
        .task(id: pending) {
            guard pending else { return }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(180)) }
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
