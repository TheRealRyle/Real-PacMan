import SwiftUI

struct DemoGameplayView: View {
    // The selected route seeds one independent practice session for this screen.
    @State private var demo: DemoSession
    @State private var cameraReset = UUID()
    @Environment(\.scenePhase) private var scenePhase

    init(route: GameRoute) {
        _demo = State(initialValue: DemoSession(route: route))
    }

    var body: some View {
        Group {
            if demo.isComplete {
                CompletionScoreView(score: demo.score, collected: demo.collectedPelletIDs.count,
                                    total: demo.route.pellets.count, distance: demo.distanceMeters,
                                    isDemo: true, restart: restart)
            } else {
                gameplay
            }
        }
        .navigationTitle(demo.isComplete ? "Demo score" : "Demo mode")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ArcadeAudio.shared.setGameplayVisible(true) }
        .onDisappear { demo.pause(); ArcadeAudio.shared.setGameplayVisible(false) }
        .onChange(of: scenePhase) {
            if scenePhase != .active { demo.pause() }
        }
    }

    private var gameplay: some View {
        VStack(spacing: 0) {
            GameplayMapView(route: demo.route, collected: demo.collectedPelletIDs,
                            player: demo.player, isDemo: true)
                .id(cameraReset)
            VStack(spacing: 10) {
                HStack {
                    Label("\(demo.score) demo points", systemImage: "star.fill")
                    Spacer()
                    Text("\(demo.collectedPelletIDs.count) / \(demo.route.pellets.count)").monospacedDigit()
                }.font(.headline)
                Text(demo.isPlaying ? "Tap or hold an arrow to move · no GPS needed" : "Demo paused · tap Resume to continue")
                    .font(.caption).foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) {
                        directionPad
                        Spacer(minLength: 0)
                        sessionControls
                    }
                    VStack(spacing: 12) {
                        directionPad
                        sessionControls
                    }
                }
                Text("Practice only · scores are not saved to Statistics")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding()
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
