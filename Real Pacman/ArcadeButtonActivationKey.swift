import SwiftUI

private struct ArcadeButtonActivationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var arcadeButtonActivated: Bool {
        get { self[ArcadeButtonActivationKey.self] }
        set { self[ArcadeButtonActivationKey.self] = newValue }
    }
}
