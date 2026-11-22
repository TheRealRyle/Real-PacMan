import SwiftUI

struct NextPelletIndicator: View {
    let indicator: PelletIndicator

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.up.circle.fill")
                .rotationEffect(.degrees(indicator.angleDegrees))
                .foregroundStyle(.yellow)
            Text("\(indicator.distanceMeters) m").font(.caption.bold()).monospacedDigit()
        }
        .frame(width: 88, height: 44)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.yellow, lineWidth: 2) }
        .offset(x: indicator.position.x - 44, y: indicator.position.y - 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next pellet, \(indicator.distanceMeters) metres away. Arrow points toward it on the map.")
        .allowsHitTesting(false)
    }
}
