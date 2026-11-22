import Foundation
import CoreLocation

/// Retain direction at rest and ignore small GPS jitter when no reliable course exists.
struct PlayerHeading {
    private(set) var degrees = 90.0
    private var anchor: RouteCoordinate?

    mutating func update(coordinate: RouteCoordinate, course: Double = -1, speed: Double = -1) {
        guard coordinate.isValid else { return }
        if course.isFinite, (0..<360).contains(course), speed.isFinite, speed >= 0.5 {
            degrees = course
            anchor = coordinate
        } else if let anchor, anchor.location.distance(from: coordinate.location) >= 3 {
            let a = anchor.latitude * .pi / 180
            let b = coordinate.latitude * .pi / 180
            let longitude = (coordinate.longitude - anchor.longitude) * .pi / 180
            let bearing = atan2(sin(longitude) * cos(b), cos(a) * sin(b) - sin(a) * cos(b) * cos(longitude)) * 180 / .pi
            degrees = (bearing + 360).truncatingRemainder(dividingBy: 360)
            self.anchor = coordinate
        } else if anchor == nil {
            anchor = coordinate
        }
    }

    /// Artwork faces east; map bearings are clockwise from north.
    static func screenRotation(bearing: Double, mapDirection: Double) -> Double {
        (bearing - mapDirection - 90).truncatingRemainder(dividingBy: 360)
    }
}
