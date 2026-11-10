import CoreLocation
import Observation

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var status: CLAuthorizationStatus = .notDetermined
    private(set) var message = "Start a game to enable GPS."
    private(set) var coordinate: RouteCoordinate?
    var onLocation: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.activityType = .fitness
        status = manager.authorizationStatus
    }

    func start() {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            message = "Waiting for an accurate GPS fix…"
        } else { message = "Enable location access in iOS Settings to collect pellets." }
    }

    func stop() { manager.stopUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        // A pending permission request can complete after the game has paused.
        if wantsUpdates { start() }
    }

    var wantsUpdates = false {
        didSet { if wantsUpdates { start() } else { stop() } }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsUpdates, let location = locations.last else { return }
        message = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 20
            ? "GPS ready · collect within 15 m" : "GPS accuracy is low. Move to an open area."
        coordinate = RouteCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        onLocation?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        message = error.localizedDescription
    }
}
