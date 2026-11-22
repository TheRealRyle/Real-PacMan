import SwiftUI

struct ParcoursModeView: View {
    let route: GameRoute
    private var modes: [ParcoursMode] { route.parcours?.supportedModes ?? [.explore] }
    var body: some View {
        ArcadePage(title: "CHOOSE MODE", symbol: "gamecontroller.fill") {
            ForEach(modes) { mode in
                ArcadePanel(title: mode.title.uppercased()) {
                    Text(mode.instructions).font(.subheadline)
                    if mode.isTimed {
                        Text("Time limit: \(Int(ModeProgress(route: route, mode: mode).timeLimitSeconds ?? 60) / 60) minutes of active play")
                            .font(.caption).foregroundStyle(.yellow)
                    }
                    ArcadeNavigationLink {
                        RouteDetailView(route: route, mode: mode).toolbar(.visible, for: .navigationBar)
                    } label: {
                        Label("WALK · \(mode.title.uppercased())", systemImage: mode.symbol).frame(maxWidth: .infinity)
                    }.buttonStyle(ArcadeButtonStyle(color: .green))
                    ArcadeNavigationLink {
                        DemoGameplayView(route: route, mode: mode).toolbar(.visible, for: .navigationBar)
                    } label: {
                        Label("DEMO · \(mode.title.uppercased())", systemImage: "dpad.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(ArcadeButtonStyle(color: .cyan))
                    Text("Demo uses arrow controls, without GPS or saved scores.").font(.caption)
                }.arcadeEntrance()
            }
        }
    }
}
