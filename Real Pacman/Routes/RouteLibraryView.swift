import SwiftUI

struct RouteLibraryView: View {
    @Environment(GameStore.self) private var game
    @Environment(GameSettings.self) private var settings

    var body: some View {
        List {
            if game.archive.activeSession != nil {
                NavigationLink("Resume saved game") { GameplayView() }
            }
            Section("Saved routes") {
                if game.archive.routes.isEmpty {
                    Text("Add your server in Settings, then refresh to download walking routes.")
                        .foregroundStyle(.secondary)
                }
                ForEach(game.archive.routes) { route in
                    NavigationLink { RouteDetailView(route: route) } label: {
                        VStack(alignment: .leading) {
                            Text(route.name).font(.headline)
                            Text("\(route.pellets.count) pellets · version \(route.version)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Choose a route")
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await game.fetchRoutes(server: settings.serverURL) }
            }.disabled(game.isLoading)
        }
        .refreshable { await game.fetchRoutes(server: settings.serverURL) }
    }
}
