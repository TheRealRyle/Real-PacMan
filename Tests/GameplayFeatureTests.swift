import Testing
import Foundation
import CoreGraphics
import CoreLocation
@testable import ParcoursCore

struct GameplayFeatureTests {
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
