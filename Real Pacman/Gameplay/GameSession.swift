import Foundation

struct GameSession: Codable, Identifiable {
    let id: UUID
    let route: GameRoute
    let startedAt: Date
    var rules: ModeProgress? = nil
    var mode: ParcoursMode? = .explore
    var collectedPelletIDs: Set<UUID> = []
    var distanceMeters: Double = 0
    var finishedAt: Date?
    var syncedAt: Date?
    var score: Int { route.pellets.filter { collectedPelletIDs.contains($0.id) }.reduce(0) { $0 + $1.value } }
}
