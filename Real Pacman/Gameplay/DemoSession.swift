import Foundation
import CoreLocation
import Observation

/// Practice is entirely in memory and never touches GameStore, GPS or result sync.
@MainActor @Observable
final class DemoSession {
    let route: GameRoute
    private(set) var player: RouteCoordinate
    private(set) var collectedPelletIDs: Set<UUID> = []
    private(set) var isPlaying = true
    private(set) var distanceMeters: Double = 0

    var score: Int {
        route.pellets.filter { collectedPelletIDs.contains($0.id) }.reduce(0) { $0 + $1.value }
    }

    var isComplete: Bool { collectedPelletIDs.count == route.pellets.count }

    init(route: GameRoute) {
        self.route = route
        player = route.parcours?.start ?? route.coordinates.first ?? route.pellets.first?.coordinate
            ?? RouteCoordinate(latitude: 0, longitude: 0)
        collectNearbyPellets()
    }

    func move(_ direction: DemoDirection) {
        guard isPlaying, !isComplete else { return }
        // Five metres per tap. A geodesic step keeps arrow speed consistent at any latitude.
        let distance = 5.0 / 6_371_000
        let bearing = direction.rawValue * .pi / 180
        let latitude = player.latitude * .pi / 180
        let longitude = player.longitude * .pi / 180
        let nextLatitude = asin(sin(latitude) * cos(distance)
                                + cos(latitude) * sin(distance) * cos(bearing))
        let nextLongitude = longitude + atan2(sin(bearing) * sin(distance) * cos(latitude),
                                              cos(distance) - sin(latitude) * sin(nextLatitude))
        let next = RouteCoordinate(latitude: nextLatitude * 180 / .pi,
                                   longitude: (nextLongitude * 180 / .pi + 540)
                                    .truncatingRemainder(dividingBy: 360) - 180)
        distanceMeters += player.location.distance(from: next.location)
        player = next
        collectNearbyPellets()
    }

    func togglePause() {
        guard !isComplete else { return }
        isPlaying.toggle()
    }

    func pause() { isPlaying = false }

    func restart() {
        player = route.parcours?.start ?? route.coordinates.first ?? route.pellets.first?.coordinate
            ?? RouteCoordinate(latitude: 0, longitude: 0)
        collectedPelletIDs = []
        distanceMeters = 0
        isPlaying = true
        collectNearbyPellets()
    }

    private func collectNearbyPellets() {
        for pellet in route.pellets where !collectedPelletIDs.contains(pellet.id) {
            if player.location.distance(from: pellet.coordinate.location) <= GameplayRules.collectionRadiusMeters {
                collectedPelletIDs.insert(pellet.id)
            }
        }
        if isComplete { isPlaying = false }
    }
}
