import SwiftUI

struct GameplayView: View {
    var startingRoute: GameRoute? = nil
    @Environment(GameStore.self) private var game
    @Environment(\.scenePhase) private var scenePhase
    @State private var location = LocationService()
    @State private var confirmFinish = false

    var body: some View {
        Group {
            if let session = game.archive.activeSession {
                VStack(spacing: 0) {
                    if session.route.parcours?.fieldVerified == false {
                        ParcoursPreview(route: session.route, collected: session.collectedPelletIDs,
                                        player: location.coordinate, height: nil)
                            .background(Color.indigo)
                    } else {
                        RouteMapView(route: session.route, collected: session.collectedPelletIDs)
                    }
                    VStack(spacing: 12) {
                        HStack {
                            Label("\(session.score) points", systemImage: "star.fill")
                            Spacer()
                            Text("\(session.collectedPelletIDs.count) / \(session.route.pellets.count)")
                        }.font(.headline)
                        Text(game.isPlaying ? location.message : "Paused · progress saved")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button(game.isPlaying ? "Pause" : "Resume") {
                                ArcadeAudio.shared.play(.press)
                                if game.isPlaying { game.pause() } else { game.resume() }
                                location.wantsUpdates = game.isPlaying
                            }.buttonStyle(.borderedProminent)
                            Button("Finish walk") { ArcadeAudio.shared.play(.press); confirmFinish = true }.buttonStyle(.bordered)
                        }
                        Text("Stay on public paths and watch your surroundings. GPS runs while this screen is active.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.padding()
                }
            } else {
                ContentUnavailableView("Walk saved", systemImage: "checkmark.circle",
                                       description: Text("Your result is in Statistics and ready to sync."))
            }
        }
        .navigationTitle("Collect pellets")
        .onAppear {
            ArcadeAudio.shared.setGameplayVisible(true)
            if let startingRoute { game.start(startingRoute) }
            location.onLocation = { game.collect(at: $0) }
            game.resume()
            location.wantsUpdates = game.archive.activeSession != nil
        }
        .onDisappear { ArcadeAudio.shared.setGameplayVisible(false); location.wantsUpdates = false; game.pause() }
        .onChange(of: scenePhase) {
            if scenePhase == .background { location.wantsUpdates = false; game.pause() }
        }
        .onChange(of: game.archive.activeSession?.id) {
            if game.archive.activeSession == nil { location.wantsUpdates = false }
        }
        .confirmationDialog("Finish this walk and save your result?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish walk") { location.wantsUpdates = false; game.finish() }
        }
    }
}
