import Foundation
import CoreLocation

struct ParcoursPath: Codable, Identifiable, Equatable {
    let id: String
    let from: String
    let to: String
    let coordinates: [RouteCoordinate]
    /// Retained for auditing the source path against OpenStreetMap.
    let osmWayID: String?
    var lengthMeters: Double {
        zip(coordinates, coordinates.dropFirst()).reduce(0) {
            $0 + $1.0.location.distance(from: $1.1.location)
        }
    }
}
