import CoreLocation

struct RouteCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite &&
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var coordinate: CLLocationCoordinate2D { location.coordinate }
}
