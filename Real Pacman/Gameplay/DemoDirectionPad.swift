import SwiftUI

struct DemoDirectionPad: View {
    let move: (DemoDirection) -> Void

    var body: some View {
        HStack(spacing: 10) {
            arrow(.west)
            VStack(spacing: 10) {
                arrow(.north)
                arrow(.south)
            }
            arrow(.east)
        }
        .buttonStyle(ArcadeButtonStyle(color: .cyan))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Demo direction controls")
    }

    private func arrow(_ direction: DemoDirection) -> some View {
        Button(action: { move(direction) }) {
            Label(direction.label, systemImage: direction.symbol)
                .labelStyle(.iconOnly)
                .frame(minWidth: 20, minHeight: 20)
        }
        .buttonRepeatBehavior(.enabled)
        .accessibilityHint("Moves five metres. Hold to keep moving.")
    }
}
