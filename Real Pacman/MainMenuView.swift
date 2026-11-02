import SwiftUI

struct MainMenuView: View {
    @Environment(GameStore.self) private var game
    @Environment(GameSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var game = game
        NavigationStack {
            ZStack {
                ArcadeBackground()
                ScrollView {
                    VStack(spacing: 34) {
                        VStack(spacing: 2) {
                            Text("REAL")
                                .font(.largeTitle.weight(.black))
                                .foregroundStyle(.white)
                            Text("PAC-MAN")
                                .font(.system(.largeTitle, design: .rounded, weight: .black))
                                .foregroundStyle(.yellow)
                                .shadow(color: .black.opacity(0.6), radius: 0, y: 5)
                            Text("THE STREETS ARE YOUR LEVEL")
                                .font(.caption.weight(.heavy))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.top, 12)
                        }
                        .multilineTextAlignment(.center)
                        .arcadeEntrance(delay: 0.04)

                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 90, weight: .black))
                            .foregroundStyle(.yellow)
                            .shadow(color: .black.opacity(0.4), radius: 0, y: 6)
                            .accessibilityHidden(true)
                            .arcadeEntrance(delay: 0.12)

                        NavigationLink { RouteLibraryView() } label: {
                            Label("PLAY", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ArcadeButtonStyle(color: .green))
                        .arcadeEntrance(delay: 0.22)

                        HStack(spacing: 20) {
                            NavigationLink { StatisticsView().toolbar(.visible, for: .navigationBar) } label: {
                                Label("Stats", systemImage: "chart.bar.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            NavigationLink { SettingsView().toolbar(.visible, for: .navigationBar) } label: {
                                Label("Settings", systemImage: "gearshape.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(ArcadeButtonStyle(color: .cyan))
                        .arcadeEntrance(delay: 0.3)

                        Text("WALK • COLLECT • COMPLETE")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 48)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Real Pac-Man", isPresented: Binding(
                get: { game.message != nil },
                set: { if !$0 { game.message = nil } }
            )) {
                Button("OK") { game.message = nil }
            } message: { Text(game.message ?? "") }
        }
        .task { if !settings.serverURL.isEmpty { await game.sync(server: settings.serverURL) } }
        .onChange(of: scenePhase) {
            if scenePhase == .active, !settings.serverURL.isEmpty {
                Task { await game.sync(server: settings.serverURL) }
            }
        }
    }
}

#Preview {
    MainMenuView()
        .environment(GameStore())
        .environment(GameSettings())
}
