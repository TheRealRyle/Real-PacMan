import SwiftUI

struct ParcoursModeView: View {
    let route: GameRoute

    var body: some View {
        ArcadePage(title: "CHOOSE MODE", symbol: "gamecontroller.fill") {
            ArcadePanel(title: route.name.uppercased()) {
                Text(route.parcours?.description ?? "Choose how you want to explore this parcours.")
                    .font(.subheadline)
                ForEach(ParcoursMode.allCases) { mode in
                    if mode == .explore && (route.parcours?.supportedModes.contains(.explore) ?? true) {
                        ArcadeNavigationLink {
                            RouteDetailView(route: route).toolbar(.visible, for: .navigationBar)
                        } label: {
                            Label("EXPLORE", systemImage: mode.symbol).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArcadeButtonStyle(color: .green))
                        Text("Collect every pellet in any order. No timer.")
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                    } else {
                        HStack {
                            Label(mode.title, systemImage: mode.symbol)
                            Spacer()
                            Text("COMING LATER").font(.caption.weight(.black))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 8)
                    }
                }
            }
            .arcadeEntrance(delay: 0.1)
        }
    }
}
