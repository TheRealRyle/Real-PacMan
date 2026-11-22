import SwiftUI

struct NextGhostIndicator: View {
    let indicator: PelletIndicator

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.fill").foregroundStyle(.pink)
            Text("\(indicator.distanceMeters) m").font(.caption2.bold()).monospacedDigit()
            Image(systemName: "arrow.up")
                .rotationEffect(.degrees(indicator.angleDegrees))
        }
        .foregroundStyle(.white)
        .frame(width: 84, height: 32)
        .background(Color(red: 0.09, green: 0.04, blue: 0.16), in: Capsule())
        .overlay { Capsule().strokeBorder(.pink, lineWidth: 2) }
        .offset(x: indicator.position.x - 42, y: indicator.position.y - 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chasing ghost, \(indicator.distanceMeters) metres away. Arrow points toward it.")
        .allowsHitTesting(false)
    }
}
