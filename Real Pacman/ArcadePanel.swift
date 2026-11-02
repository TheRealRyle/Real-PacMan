import SwiftUI

struct ArcadePanel<Content: View>: View {
    let title: String
    var color: Color = .indigo
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(.yellow)
                .shadow(color: .black.opacity(0.4), radius: 0, y: 2)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .foregroundStyle(.white)
        .font(.body.weight(.semibold))
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(.white.opacity(0.25), lineWidth: 2)
                .padding(6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.black.opacity(0.55), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.35), radius: 0, y: 6)
    }
}
