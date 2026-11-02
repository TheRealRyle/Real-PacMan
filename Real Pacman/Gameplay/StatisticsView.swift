import SwiftUI

struct StatisticsView: View {
    @Environment(GameStore.self) private var game
    @Environment(GameSettings.self) private var settings

    var body: some View {
        List {
            Section("All walks") {
                LabeledContent("Walks", value: "\(game.archive.results.count)")
                LabeledContent("Points", value: "\(game.archive.results.reduce(0) { $0 + $1.score })")
                LabeledContent("Distance", value: Measurement(value: game.archive.results.reduce(0) { $0 + $1.distanceMeters },
                                                            unit: UnitLength.meters).formatted())
                LabeledContent("Waiting to sync", value: "\(game.pendingResults)")
                Button(game.isSyncing ? "Syncing…" : "Sync saved results") {
                    Task { await game.sync(server: settings.serverURL) }
                }.disabled(game.isSyncing || game.pendingResults == 0)
            }
            Section("History") {
                ForEach(game.archive.results.reversed()) { result in
                    VStack(alignment: .leading) {
                        Text(result.route.name).font(.headline)
                        Text("\(result.score) points · \(result.syncedAt == nil ? "Saved on device" : "Synced")")
                        Text(result.startedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Statistics")
    }
}
