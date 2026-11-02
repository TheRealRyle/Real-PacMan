import Foundation
import CoreLocation

struct GameRoute: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let version: Int
    let coordinates: [RouteCoordinate]
    let pellets: [Pellet]
    let mapStyleURL: URL

    func validate() throws {
        guard !name.isEmpty, version > 0, coordinates.count >= 2,
              !pellets.isEmpty, pellets.count <= 10_000,
              Set(pellets.map(\.id)).count == pellets.count,
              (coordinates + pellets.map(\.coordinate)).allSatisfy({ $0.isValid }),
              mapStyleURL.scheme == "https" else { throw URLError(.cannotParseResponse) }
    }
}
