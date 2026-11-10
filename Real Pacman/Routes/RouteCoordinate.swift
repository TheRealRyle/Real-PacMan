import CoreLocation

struct RouteCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite &&
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var coordinate: CLLocationCoordinate2D { location.coordinate }
    /// Local equirectangular projection, suitable for compact walking areas.
    func distanceToSegment(_ a: RouteCoordinate, _ b: RouteCoordinate) -> Double {
        let meters = 111_320.0
        let longitudeScale = cos(latitude * .pi / 180) * meters
        let ax = (a.longitude - longitude) * longitudeScale
        let ay = (a.latitude - latitude) * meters
        let bx = (b.longitude - longitude) * longitudeScale
        let by = (b.latitude - latitude) * meters
        let dx = bx - ax, dy = by - ay
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared == 0 ? 0 : min(1, max(0, -(ax * dx + ay * dy) / lengthSquared))
        return hypot(ax + t * dx, ay + t * dy)
    }
}
