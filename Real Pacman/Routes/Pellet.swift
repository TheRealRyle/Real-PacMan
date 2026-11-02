import Foundation

struct Pellet: Codable, Identifiable, Equatable {
    let id: UUID
    let coordinate: RouteCoordinate
}
