import SwiftUI

struct ArcadeButtonStyle: ButtonStyle {
    var color: Color = .yellow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.black))
            .foregroundStyle(Color(red: 0.06, green: 0.12, blue: 0.2))
            .padding(18)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.65), lineWidth: 3)
                    .padding(4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.black.opacity(0.6), lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.45), radius: 0, y: configuration.isPressed ? 2 : 6)
            .offset(y: configuration.isPressed ? 4 : 0)
    }
}
