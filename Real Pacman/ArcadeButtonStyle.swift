import SwiftUI

struct ArcadeButtonStyle: ButtonStyle {
    var color: Color = .yellow

    func makeBody(configuration: Configuration) -> some View {
        ArcadeButtonFace(label: configuration.label, color: color,
                         isPressed: configuration.isPressed)
    }
}
