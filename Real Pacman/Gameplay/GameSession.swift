import Foundation

struct GameSession: Codable, Identifiable {
    let id: UUID
    let route: GameRoute
    let startedAt: Date
    var collectedPelletIDs: Set<UUID> = []
    var distanceMeters: Double = 0
    var finishedAt: Date?
    var syncedAt: Date?
    var score: Int { collectedPelletIDs.count * 10 }
}
