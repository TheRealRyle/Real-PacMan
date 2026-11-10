import Foundation

struct Pellet: Codable, Identifiable, Equatable {
    let id: UUID
    let coordinate: RouteCoordinate
    let value: Int

    init(id: UUID, coordinate: RouteCoordinate, value: Int = 10) {
        self.id = id
        self.coordinate = coordinate
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        coordinate = try container.decode(RouteCoordinate.self, forKey: .coordinate)
        value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 10
    }
}
