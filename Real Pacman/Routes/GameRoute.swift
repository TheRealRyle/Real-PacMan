import Foundation
import CoreLocation

struct GameRoute: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let version: Int
    let coordinates: [RouteCoordinate]
    let pellets: [Pellet]
    let mapStyleURL: URL

    var parcours: ParcoursDefinition? = nil

    var pathLines: [[RouteCoordinate]] { parcours?.paths.map(\.coordinates) ?? [coordinates] }
    var mapCoordinates: [RouteCoordinate] {
        pathLines.flatMap { $0 } + (parcours?.boundary ?? []) + pellets.map(\.coordinate)
    }
    var totalPoints: Int { pellets.reduce(0) { $0 + $1.value } }
    var distanceMeters: Double {
        parcours?.distanceMeters ?? zip(coordinates, coordinates.dropFirst()).reduce(0) {
            $0 + $1.0.location.distance(from: $1.1.location)
        }
    }

    func validate() throws {
        guard !name.isEmpty, version > 0, coordinates.count >= 2,
              !pellets.isEmpty, pellets.count <= 10_000,
              Set(pellets.map(\.id)).count == pellets.count,
              (coordinates + pellets.map(\.coordinate)).allSatisfy({ $0.isValid }),
              mapStyleURL.scheme == "https" else { throw URLError(.cannotParseResponse) }
        guard pellets.allSatisfy({ (1...1000).contains($0.value) }) else { throw URLError(.cannotParseResponse) }
        try parcours?.validate(pellets: pellets)
    }
}
