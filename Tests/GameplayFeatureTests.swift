import Testing
import Foundation
import CoreGraphics
import CoreLocation
@testable import ParcoursCore

struct GameplayFeatureTests {
    @Test("Player facing follows compass movement and ignores small GPS jitter")
    func playerHeading() {
        var heading = PlayerHeading()
        let origin = RouteCoordinate(latitude: 45, longitude: 5)
        heading.update(coordinate: origin)
        heading.update(coordinate: RouteCoordinate(latitude: 45.000001, longitude: 5))
        #expect(heading.degrees == 90)
        heading.update(coordinate: RouteCoordinate(latitude: 45.000045, longitude: 5))
        #expect(abs(heading.degrees) < 0.1)
        heading.update(coordinate: RouteCoordinate(latitude: 45.000045, longitude: 4.999936))
        #expect(abs(heading.degrees - 270) < 0.1)
    }

    @Test("Valid moving GPS course takes priority, then holds its direction at rest")
    func playerCourse() {
        var heading = PlayerHeading()
        let origin = RouteCoordinate(latitude: 45, longitude: 5)
        heading.update(coordinate: origin, course: 225, speed: 1)
        #expect(heading.degrees == 225)
        heading.update(coordinate: origin, course: 0, speed: 0)
        #expect(heading.degrees == 225)
        heading.update(coordinate: origin, course: .nan, speed: 1)
        heading.update(coordinate: RouteCoordinate(latitude: .nan, longitude: 5), course: 90, speed: 1)
        #expect(heading.degrees == 225)
    }

    @Test("Player facing stays correct when the camera rotates", arguments: [
        (0.0, 0.0, -90.0), (90, 0, 0), (180, 0, 90), (270, 0, 180),
        (90, 90, -90), (0, 270, 0)
    ])
    func playerCameraDirection(bearing: Double, camera: Double, expected: Double) {
        #expect(abs(PlayerHeading.screenRotation(bearing: bearing, mapDirection: camera) - expected) < 0.001)
    }

    @Test("Verney offline download covers its whole layout within the tile budget")
    func offlineBounds() throws {
        let route = try ParcoursCatalogue.loadVerney(bundle: .module)
        let bounds = try #require(OfflineMapBounds(route: route))
        #expect(bounds.estimatedTileCount > 0)
        #expect(bounds.estimatedTileCount <= OfflineMapBounds.tileLimit)
        #expect(route.mapCoordinates.allSatisfy {
            $0.latitude > bounds.south && $0.latitude < bounds.north &&
            $0.longitude > bounds.west && $0.longitude < bounds.east
        })
    }

    @Test("Large or invalid regions are refused before downloading", arguments: [0.2, 0.5, Double.nan])
    func rejectsOfflineBounds(span: Double) {
        let route = GameRoute(id: UUID(), name: "Oversize", version: 1,
            coordinates: [RouteCoordinate(latitude: 45, longitude: 5), RouteCoordinate(latitude: 45 + span, longitude: 5 + span)],
            pellets: [], mapStyleURL: URL(string: "https://example.com/style.json")!)
        #expect(OfflineMapBounds(route: route) == nil)
    }

    @Test("Offscreen targets attach to the correct edge", arguments: [
        (CGPoint(x: 250, y: 100), CGPoint(x: 200, y: 100)),
        (CGPoint(x: -50, y: 100), CGPoint(x: 0, y: 100)),
        (CGPoint(x: 100, y: -50), CGPoint(x: 100, y: 0)),
        (CGPoint(x: 100, y: 250), CGPoint(x: 100, y: 200))
    ])
    func edgeGeometry(target: CGPoint, expected: CGPoint) {
        #expect(PelletGuidance.edgePoint(target: target, visibleRect: CGRect(x: 0, y: 0, width: 200, height: 200)) == expected)
    }

    @Test("Visible targets and unusable viewports do not show edge indicators")
    func visibleTarget() {
        #expect(PelletGuidance.edgePoint(target: CGPoint(x: 50, y: 50), visibleRect: CGRect(x: 0, y: 0, width: 100, height: 100)) == nil)
        #expect(PelletGuidance.edgePoint(target: CGPoint(x: 100, y: 100), visibleRect: .zero) == nil)
    }

    @Test("Nearest guidance skips collected pellets")
    func nearest() throws {
        let route = try ParcoursCatalogue.loadVerney(bundle: .module)
        let pellet = try #require(route.pellets.first)
        #expect(PelletGuidance.nearest(in: route, collected: [], player: pellet.coordinate)?.id == pellet.id)
        #expect(PelletGuidance.nearest(in: route, collected: [pellet.id], player: pellet.coordinate)?.id != pellet.id)
        #expect(PelletGuidance.nearest(in: route, collected: Set(route.pellets.map(\.id)), player: pellet.coordinate) == nil)
    }

    @Test("The final pellet saves and exposes the completed score automatically")
    @MainActor func completedScore() throws {
        let coordinate = RouteCoordinate(latitude: 45, longitude: 5)
        let route = GameRoute(id: UUID(), name: "Completion", version: 1,
            coordinates: [coordinate, RouteCoordinate(latitude: 45.001, longitude: 5)],
            pellets: [Pellet(id: UUID(), coordinate: coordinate)],
            mapStyleURL: URL(string: "https://example.com/style.json")!)
        let store = GameStore(fileURL: URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json"))
        store.start(route)
        store.collect(at: CLLocation(coordinate: coordinate.coordinate, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date()))
        #expect(store.archive.activeSession == nil)
        #expect(store.latestFinishedSession?.score == 10)
        #expect(store.latestFinishedSession?.finishedAt != nil)
        #expect(store.pendingResults == 1)
        #expect(!store.isPlaying)
        store.finish()
        #expect(store.archive.results.count == 1)
    }

    @Test("Collection requires getting within eight metres", arguments: [(0.000063, true), (0.00009, false)])
    @MainActor func tighterCollection(latitudeOffset: Double, collected: Bool) {
        let player = RouteCoordinate(latitude: 45, longitude: 5)
        let pellet = Pellet(id: UUID(), coordinate: RouteCoordinate(latitude: 45 + latitudeOffset, longitude: 5))
        let route = GameRoute(id: UUID(), name: "Radius", version: 1,
            coordinates: [player, pellet.coordinate], pellets: [pellet],
            mapStyleURL: URL(string: "https://example.com/style.json")!)
        let store = GameStore(fileURL: URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json"))
        store.start(route)
        store.collect(at: CLLocation(coordinate: player.coordinate, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date()))
        #expect((store.latestFinishedSession != nil) == collected)
        let demo = DemoSession(route: route)
        #expect(demo.isComplete == collected)
    }

    @Test("The original follow zoom is the midpoint and default")
    func zoomMidpoint() {
        #expect(GameplayRules.defaultZoom == 17.5)
        #expect((GameplayRules.zoomRange.lowerBound + GameplayRules.zoomRange.upperBound) / 2 == GameplayRules.defaultZoom)
    }
}
