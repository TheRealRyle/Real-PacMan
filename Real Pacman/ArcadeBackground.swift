import SwiftUI

struct ArcadeBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.08, green: 0.38, blue: 0.78),
                                Color(red: 0.02, green: 0.12, blue: 0.36)],
                       startPoint: .top, endPoint: .bottom)
            .overlay {
                GeometryReader { geometry in
                    Path { path in
                        let step: CGFloat = 64
                        for x in stride(from: CGFloat.zero, through: geometry.size.width, by: step) {
                            for y in stride(from: CGFloat.zero, through: geometry.size.height, by: step) {
                                path.addRoundedRect(in: CGRect(x: x + 5, y: y + 5, width: 54, height: 54),
                                                    cornerSize: CGSize(width: 6, height: 6))
                            }
                        }
                    }
                    .stroke(.white.opacity(0.045), lineWidth: 2)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
