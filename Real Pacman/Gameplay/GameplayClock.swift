import SwiftUI

/// Clock instances are discarded on pause/background; there is no catch-up on resume.
struct GameplayClock: ViewModifier {
    let running: Bool
    let tick: (Double) -> Void
    func body(content: Content) -> some View {
        content.task(id: running) {
            guard running else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                let now = clock.now
                let parts = previous.duration(to: now).components
                previous = now
                tick(Double(parts.seconds) + Double(parts.attoseconds) / 1e18)
            }
        }
    }
}
