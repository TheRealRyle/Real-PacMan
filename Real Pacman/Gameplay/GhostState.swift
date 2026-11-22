import Foundation

struct GhostState: Codable, Equatable, Identifiable {
    let id: Int
    var pathID: String
    var distanceAlongPath: Double
    var isReversed: Bool
    var coordinate: RouteCoordinate
}
