import SwiftUI

struct StatisticsView: View {
    @Environment(GameStore.self) private var game
    @Environment(GameSettings.self) private var settings

    var body: some View {
        ArcadePage(title: "STATS", symbol: "chart.bar.fill") {
            ArcadePanel(title: "YOUR SCOREBOARD") {
                stat("Walks completed", symbol: "flag.checkered",
                     value: "\(game.archive.results.count)")
                Divider().overlay(.white.opacity(0.3))
                stat("Total points", symbol: "star.fill",
                     value: "\(game.archive.results.reduce(0) { $0 + $1.score })")
                Divider().overlay(.white.opacity(0.3))
                stat("Distance walked", symbol: "figure.walk",
                     value: Measurement(value: game.archive.results.reduce(0) { $0 + $1.distanceMeters },
                                        unit: UnitLength.meters).formatted())
            }
            .arcadeEntrance(delay: 0.12)

            ArcadePanel(title: "SAVED RESULTS", color: Color(red: 0.05, green: 0.3, blue: 0.5)) {
                stat("Waiting to sync", symbol: "icloud.and.arrow.up",
                     value: "\(game.pendingResults)")
                Button {
                    ArcadeAudio.shared.play(.press)
                    Task { await game.sync(server: settings.serverURL) }
                } label: {
                    Label(game.isSyncing ? "SYNCING…" : "SYNC RESULTS",
                          systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ArcadeButtonStyle(color: .green))
                .disabled(game.isSyncing || game.pendingResults == 0)
                .opacity(game.isSyncing || game.pendingResults == 0 ? 0.55 : 1)
            }
            .arcadeEntrance(delay: 0.2)

            ArcadePanel(title: "WALK HISTORY") {
                if game.archive.results.isEmpty {
                    Label("Your first adventure is waiting!", systemImage: "shoeprints.fill")
                    Text("Finished walks and their scores will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                ForEach(game.archive.results.reversed()) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.route.name).font(.headline)
                        Label("\(result.score) points", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(result.startedAt, style: .date)
                            .font(.caption)
                        Label(result.syncedAt == nil ? "Saved on device" : "Synced",
                              systemImage: result.syncedAt == nil ? "iphone" : "checkmark.icloud")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .arcadeEntrance(delay: 0.28)
        }
    }

    private func stat(_ title: String, symbol: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                Label(title, systemImage: symbol)
                Spacer()
                Text(value).font(.title2.weight(.black)).foregroundStyle(.yellow)
            }
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: symbol)
                Text(value).font(.title2.weight(.black)).foregroundStyle(.yellow)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { StatisticsView() }
        .environment(GameStore())
        .environment(GameSettings())
}
