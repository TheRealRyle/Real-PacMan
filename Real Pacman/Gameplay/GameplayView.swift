import SwiftUI

struct GameplayView: View {
    var startingRoute: GameRoute? = nil
    var startingMode: ParcoursMode = .explore
    @Environment(GameStore.self) private var game
    @Environment(\.scenePhase) private var scenePhase
    @State private var location = LocationService()
    @State private var confirmFinish = false
    @State private var sessionID: UUID?

    var body: some View {
        Group {
            if let session = game.archive.activeSession {
                VStack(spacing: 0) {
                    GameplayMapView(route: session.route, collected: session.collectedPelletIDs,
                                    player: location.coordinate, ghosts: session.rules?.ghosts ?? [])
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.cyan.opacity(0.25), lineWidth: 1) }
                        .padding(.horizontal, 12).padding(.top, 8)
                    ModeHUD(mode: session.mode ?? .explore, rules: session.rules)
                    GameplayDashboard(score: session.score, collected: session.collectedPelletIDs.count,
                                      total: session.route.pellets.count, distance: session.distanceMeters,
                                      isPlaying: game.isPlaying,
                                      status: game.isPlaying ? location.message : "Progress saved · ready when you are") {
                        HStack(spacing: 12) {
                            Button {
                                ArcadeAudio.shared.play(.press)
                                if game.isPlaying { game.pause() } else { game.resume() }
                                location.wantsUpdates = game.isPlaying
                            } label: {
                                Label(game.isPlaying ? "Pause" : "Resume", systemImage: game.isPlaying ? "pause.fill" : "play.fill")
                                    .frame(maxWidth: .infinity)
                            }.buttonStyle(ArcadeButtonStyle(color: .green))
                            Button {
                                ArcadeAudio.shared.play(.press)
                                confirmFinish = true
                            } label: {
                                Label("Finish", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                            }.buttonStyle(ArcadeButtonStyle(color: .yellow))
                                .accessibilityLabel("Finish walk")
                        }
                    }
                }
            } else if let result = game.latestFinishedSession, result.id == sessionID {
                CompletionScoreView(score: result.score, collected: result.collectedPelletIDs.count,
                                    total: result.route.pellets.count, distance: result.distanceMeters, rules: result.rules,
                                    unlockedAchievements: game.latestUnlockedAchievements)
            } else {
                ContentUnavailableView("Walk saved", systemImage: "checkmark.circle",
                                       description: Text("Your result is in Statistics and ready to sync."))
            }
        }
        .background(Color(red: 0.025, green: 0.05, blue: 0.12).ignoresSafeArea())
        .modifier(LifeLostFeedback(lives: game.archive.activeSession?.rules?.livesRemaining
                                  ?? (game.latestFinishedSession?.id == sessionID ? game.latestFinishedSession?.rules?.livesRemaining : nil)))
        .navigationTitle("Collect pellets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.025, green: 0.05, blue: 0.12), for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .modifier(GameplayClock(running: game.isPlaying && scenePhase == .active && (game.archive.activeSession?.mode ?? .explore) != .explore) { game.advance(by: $0) })
        .onAppear {
            ArcadeAudio.shared.setGameplayVisible(true)
            if let startingRoute { game.start(startingRoute, mode: startingMode) }
            location.onLocation = { game.collect(at: $0) }
            sessionID = game.archive.activeSession?.id
            game.resume()
            location.wantsUpdates = game.archive.activeSession != nil
        }
        .onDisappear { ArcadeAudio.shared.setGameplayVisible(false); location.wantsUpdates = false; game.pause() }
        .onChange(of: scenePhase) {
            if scenePhase != .active { location.wantsUpdates = false; game.pause() }
        }
        .onChange(of: game.archive.activeSession?.id) {
            if game.archive.activeSession == nil { location.wantsUpdates = false }
        }
        .confirmationDialog("Finish this walk and save your result?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish walk") { location.wantsUpdates = false; game.finish() }
        }
    }
}
