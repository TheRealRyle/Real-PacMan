import SwiftUI

struct DemoGameplayView: View {
    // The selected route seeds one independent practice session for this screen.
    @State private var demo: DemoSession
    @State private var cameraReset = UUID()
    @Environment(\.scenePhase) private var scenePhase

    init(route: GameRoute, mode: ParcoursMode = .explore) {
        _demo = State(initialValue: DemoSession(route: route, mode: mode))
    }

    var body: some View {
        Group {
            if demo.isComplete {
                CompletionScoreView(score: demo.score, collected: demo.collectedPelletIDs.count,
                                    total: demo.route.pellets.count, distance: demo.distanceMeters,
                                    isDemo: true, restart: restart, rules: demo.rules)
            } else {
                gameplay
            }
        }
        .background(Color(red: 0.025, green: 0.05, blue: 0.12).ignoresSafeArea())
        .navigationTitle(demo.isComplete ? "Demo score" : "Demo mode")
        .toolbarBackground(Color(red: 0.025, green: 0.05, blue: 0.12), for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(GameplayClock(running: demo.isPlaying && scenePhase == .active && demo.mode != .explore) { demo.advance(by: $0) })
        .onAppear { ArcadeAudio.shared.setGameplayVisible(true) }
        .onDisappear { demo.pause(); ArcadeAudio.shared.setGameplayVisible(false) }
        .onChange(of: scenePhase) {
            if scenePhase != .active { demo.pause() }
        }
    }

    private var gameplay: some View {
        VStack(spacing: 0) {
            GameplayMapView(route: demo.route, collected: demo.collectedPelletIDs,
                            player: demo.player, isDemo: true, ghosts: demo.rules.ghosts)
                .id(cameraReset)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.cyan.opacity(0.25), lineWidth: 1) }
                .padding(.horizontal, 12).padding(.top, 8)
            ModeHUD(mode: demo.mode, rules: demo.rules)
            GameplayDashboard(score: demo.score, collected: demo.collectedPelletIDs.count,
                              total: demo.route.pellets.count, distance: demo.distanceMeters,
                              isPlaying: demo.isPlaying, isDemo: true,
                              status: demo.isPlaying ? "Hold an arrow to move · GPS-free" : "Paused · tap Resume to continue") {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        directionPad
                        Spacer(minLength: 0)
                        sessionControls
                    }
                    VStack(spacing: 12) {
                        directionPad
                        sessionControls
                    }
                }
            }
        }
    }

    private func restart() {
        demo.restart()
        cameraReset = UUID()
    }

    private var directionPad: some View {
        DemoDirectionPad { direction in demo.move(direction) }
            .disabled(!demo.isPlaying)
            .opacity(demo.isPlaying ? 1 : 0.5)
    }

    private var sessionControls: some View {
        VStack(spacing: 10) {
            Button(demo.isPlaying ? "Pause" : "Resume") {
                demo.togglePause()
            }
            .disabled(demo.isComplete)
            .buttonStyle(ArcadeButtonStyle(color: .green))
            Button("Restart") {
                restart()
            }
            .buttonStyle(ArcadeButtonStyle(color: .yellow))
        }
    }
}
