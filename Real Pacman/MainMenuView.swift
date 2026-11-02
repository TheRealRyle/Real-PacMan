import SwiftUI

struct MainMenuView: View {
    @Environment(GameStore.self) private var game
    @Environment(GameSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var game = game
        NavigationStack {
            List {
                Section {
                    Text("REAL PAC-MAN").font(.largeTitle.bold())
                    Text("Turn your next walk into a pellet hunt.").foregroundStyle(.secondary)
                }
                Section {
                    NavigationLink { RouteLibraryView() } label: { Label("Play", systemImage: "figure.walk") }
                    NavigationLink { StatisticsView() } label: { Label("Statistics", systemImage: "chart.bar") }
                    NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }
                }
                if game.pendingResults > 0 {
                    Text("\(game.pendingResults) saved results waiting to sync").font(.caption)
                }
            }
            .navigationTitle("Let's walk")
            .alert("Real Pac-Man", isPresented: Binding(get: { game.message != nil }, set: { if !$0 { game.message = nil } })) {
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
