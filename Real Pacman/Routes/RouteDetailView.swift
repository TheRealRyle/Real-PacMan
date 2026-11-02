import SwiftUI

struct RouteDetailView: View {
    let route: GameRoute
    @Environment(GameStore.self) private var game
    @State private var offline = OfflineMapStore()
    @State private var downloadRequested = false

    var body: some View {
        VStack {
            RouteMapView(route: route, collected: [])
            VStack(spacing: 12) {
                Text("\(route.pellets.count) pellets · \(route.pellets.count * 10) possible points")
                Text(offline.status).font(.caption).foregroundStyle(.secondary)
                Button(offline.isDownloading ? "Downloading…" : "Download offline map") {
                    downloadRequested = true
                }.disabled(offline.isDownloading)
                if game.archive.activeSession == nil {
                    NavigationLink("Start walk") { GameplayView(startingRoute: route) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Text("Finish your saved game before starting another route.").font(.caption)
                    NavigationLink("Resume game") { GameplayView() }
                }
            }.padding()
        }
        .navigationTitle(route.name)
        .task(id: downloadRequested) {
            if downloadRequested {
                await offline.download(route)
                downloadRequested = false
            }
        }
    }
}
