import SwiftUI

struct EndWalkPrompt: View {
    let session: GameSession
    let keepPlaying: () -> Void
    let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.yellow)
                    .frame(width: 88, height: 88)
                    .background(.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
                    .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.yellow.opacity(0.4)) }
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("CALL IT A RUN?")
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your progress counts.")
                        .font(.headline).foregroundStyle(.yellow)
                    Text("Save this walk to Statistics and finish here, or head back out for the remaining pellets.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.score.formatted())
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                            .foregroundStyle(.yellow)
                        Text("POINTS SAVED")
                            .font(.caption.weight(.heavy)).foregroundStyle(.yellow.opacity(0.8))
                        Spacer(minLength: 0)
                    }
                    ProgressView(value: Double(session.collectedPelletIDs.count),
                                 total: Double(max(1, session.route.pellets.count)))
                        .tint(.cyan)
                        .accessibilityLabel("Pellets collected")
                        .accessibilityValue("\(session.collectedPelletIDs.count) of \(session.route.pellets.count)")
                    HStack {
                        Text("\(session.collectedPelletIDs.count) / \(session.route.pellets.count) pellets")
                        Spacer()
                        Label("Paused", systemImage: "pause.fill")
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.cyan.opacity(0.25)) }

                Text("Ending now saves a partial run. You can’t resume it afterward.")
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button(action: keepPlaying) {
                        Label("BACK TO GAME", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ArcadeButtonStyle(color: .cyan))
                    Button(action: finish) {
                        Label("SAVE & END WALK", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ArcadeButtonStyle(color: .yellow))
                }
            }
            .padding(26)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
            .arcadeEntrance()
        }
        .background(Color(red: 0.025, green: 0.05, blue: 0.12))
        .safeAreaInset(edge: .top, spacing: 0) {
            Capsule().fill(.yellow.opacity(0.8)).frame(width: 52, height: 4).padding(.top, 14)
        }
        .preferredColorScheme(.dark)
    }
}
