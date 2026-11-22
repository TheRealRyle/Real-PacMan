import SwiftUI

struct RouteDetailView: View {
    let route: GameRoute
    var mode: ParcoursMode = .explore
    @Environment(GameStore.self) private var game
    @State private var offline = OfflineMapStore()
    @State private var downloadRequested = false
    private var isDraft: Bool { route.parcours?.fieldVerified == false }

    var body: some View {
        ZStack {
            ArcadeBackground()
            ScrollView {
                VStack(spacing: 24) {
                    ArcadePanel(title: route.name.uppercased()) {
                        ParcoursPreview(route: route)
                        HStack {
                            Label("\(route.pellets.count) pellets", systemImage: "circle.fill")
                            Spacer()
                            Text("\(route.totalPoints) points")
                        }.foregroundStyle(.yellow).font(.headline)
                        Text("\(Int(route.distanceMeters.rounded())) m of path network")
                        if let definition = route.parcours {
                            Text("About \(definition.estimatedMinutes) min · collection order is up to you")
                                .font(.subheadline)
                            Label("Proposed start is marked in white", systemImage: "mappin")
                                .font(.caption)
                            Text("Map data © OpenStreetMap contributors")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Link("View map source", destination: definition.sourceURL).tint(.yellow)
                        }
                    }
                    Text(mode.instructions).foregroundStyle(.white).font(.subheadline)
                    if isDraft {
                        ArcadePanel(title: "MAP DRAFT") {
                            Text("These are mapped park paths with proposed pellets. The starting point, access and spacing still need an on-foot review.")
                        }
                    } else {
                        RouteMapView(route: route, collected: [])
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        ArcadePanel(title: mode.title.uppercased()) {
                            Text(offline.status).font(.caption)
                            ArcadeActionButton { downloadRequested = true } label: {
                                Label(offline.isDownloading ? "DOWNLOADING…" : "DOWNLOAD MAP", systemImage: "arrow.down.circle.fill")
                            }
                            .buttonStyle(ArcadeButtonStyle(color: .cyan))
                            .disabled(offline.isDownloading)
                        }
                    }
                    ArcadeNavigationLink {
                        GameplayView(startingRoute: game.archive.activeSession == nil ? route : nil, startingMode: mode)
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        Label(game.archive.activeSession == nil ? "START WALK" : "RESUME SAVED WALK",
                              systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ArcadeButtonStyle(color: .green))
                }
                .padding(24)
                .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(mode.title)
        .toolbar(.visible, for: .navigationBar)
        .task { if !isDraft { await offline.refreshStatus(for: route) } }
        .task(id: downloadRequested) {
            if downloadRequested {
                await offline.download(route)
                downloadRequested = false
            }
        }
    }
}
