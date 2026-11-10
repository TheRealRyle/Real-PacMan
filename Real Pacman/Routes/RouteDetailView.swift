import SwiftUI

struct RouteDetailView: View {
    let route: GameRoute
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
                    if isDraft {
                        ArcadePanel(title: "MAP DRAFT") {
                            Text("These are mapped park paths with proposed pellets. The starting point, access and spacing still need an on-foot review.")
                            Text("The preview works offline. Play and map downloads will unlock for a published, checked parcours.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        }
                    } else {
                        RouteMapView(route: route, collected: [])
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        ArcadePanel(title: "EXPLORE · NO TIMER") {
                            Text(offline.status).font(.caption)
                            ArcadeActionButton { downloadRequested = true } label: {
                                Label(offline.isDownloading ? "DOWNLOADING…" : "DOWNLOAD MAP", systemImage: "arrow.down.circle.fill")
                            }
                            .buttonStyle(ArcadeButtonStyle(color: .cyan))
                            .disabled(offline.isDownloading)
                            if game.archive.activeSession == nil {
                                ArcadeNavigationLink {
                                    GameplayView(startingRoute: route).toolbar(.visible, for: .navigationBar)
                                } label: {
                                    Label("START WALK", systemImage: "play.fill").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ArcadeButtonStyle(color: .green))
                            } else {
                                Text("Finish your saved game before starting another parcours.").font(.caption)
                                ArcadeNavigationLink {
                                    GameplayView().toolbar(.visible, for: .navigationBar)
                                } label: { Text("RESUME SAVED WALK") }
                                .buttonStyle(ArcadeButtonStyle())
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Explore")
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
