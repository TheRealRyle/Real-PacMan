import SwiftUI

struct ArcadePage<Content: View>: View {
    let title: String
    let symbol: String
    var titleFont: Font = .system(.largeTitle, design: .rounded, weight: .black)
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ArcadeBackground()
            ScrollView {
                VStack(spacing: 26) {
                    HStack(spacing: 16) {
                        ArcadeActionButton { dismiss() } label: {
                            Image(systemName: "arrow.left")
                                .frame(minWidth: 24, minHeight: 24)
                        }
                        .buttonStyle(ArcadeButtonStyle())
                        .accessibilityLabel("Back")
                        Text(title)
                            .font(titleFont)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 0, y: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: symbol)
                            .font(.title.weight(.black))
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                    .arcadeEntrance(delay: 0.03)

                    content()
                }
                .padding(24)
                .padding(.bottom, 12)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }
}
