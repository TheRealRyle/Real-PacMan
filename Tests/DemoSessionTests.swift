import Testing
import Foundation
import CoreLocation
@testable import ParcoursCore

@MainActor
struct DemoSessionTests {
    private func route() -> GameRoute {
        let start = RouteCoordinate(latitude: 45, longitude: 5)
        let middle = RouteCoordinate(latitude: 45.00036, longitude: 5)
        let end = RouteCoordinate(latitude: 45.00072, longitude: 5)
        return GameRoute(id: UUID(), name: "Demo test", version: 1,
                         coordinates: [start, end],
                         pellets: [start, middle, end].map { Pellet(id: UUID(), coordinate: $0) },
                         mapStyleURL: URL(string: "https://example.com/style.json")!)
    }

    @Test("Each arrow moves five metres in its compass direction", arguments: [
        (DemoDirection.north, 45.000045, 5.0),
        (.east, 45.0, 5.000064),
        (.south, 44.999955, 5.0),
        (.west, 45.0, 4.999936)
    ])
    func cardinalMovement(direction: DemoDirection, latitude: Double, longitude: Double) {
        let demo = DemoSession(route: route())
        let start = demo.player
        demo.move(direction)
        #expect(abs(demo.player.latitude - latitude) < 0.000001)
        #expect(abs(demo.player.longitude - longitude) < 0.000001)
        #expect((4.9...5.1).contains(start.location.distance(from: demo.player.location)))
        #expect(demo.playerBearing == direction.rawValue)
    }

    @Test("Moving collects nearby pellets once, including when retracing steps")
    func collection() {
        let demo = DemoSession(route: route())
        #expect(demo.score == 10)
        for _ in 0..<7 { demo.move(.north) }
        #expect(demo.collectedPelletIDs.count == 2)
        #expect(demo.score == 20)
        for _ in 0..<7 { demo.move(.south) }
        #expect(demo.score == 20)
        #expect(demo.distanceMeters > 69 && demo.distanceMeters < 71)
    }

    @Test("Pause blocks movement and Resume enables it")
    func pauseAndResume() {
        let demo = DemoSession(route: route())
        let start = demo.player
        let bearing = demo.playerBearing
        demo.pause()
        demo.move(.north)
        #expect(demo.player == start)
        #expect(demo.distanceMeters == 0)
        #expect(demo.playerBearing == bearing)
        demo.togglePause()
        demo.move(.north)
        #expect(demo.player != start)
    }

    @Test("Finishing stops movement and Restart resets the practice session")
    func completionAndRestart() {
        let demo = DemoSession(route: route())
        let start = demo.player
        for _ in 0..<15 { demo.move(.north) }
        #expect(demo.isComplete)
        #expect(!demo.isPlaying)
        #expect(demo.score == 30)
        let finish = demo.player
        demo.move(.east)
        demo.togglePause()
        #expect(demo.player == finish)
        #expect(!demo.isPlaying)
        demo.restart()
        #expect(demo.player == start)
        #expect(demo.distanceMeters == 0)
        #expect(demo.score == 10)
        #expect(demo.isPlaying)
        #expect(!demo.isComplete)
        #expect(demo.playerBearing == 90)
    }

    @Test("Demo play preserves the real walk file, active session and result queue")
    func realProgressIsIsolated() throws {
        let file = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json")
        let route = route()
        let store = GameStore(fileURL: file)
        store.start(route)
        store.pause()
        let sessionID = try #require(store.archive.activeSession?.id)
        let saved = try Data(contentsOf: file)
        let demo = DemoSession(route: route)
        for _ in 0..<15 { demo.move(.north) }
        #expect(demo.isComplete)
        #expect(try Data(contentsOf: file) == saved)
        let restored = GameStore(fileURL: file)
        #expect(restored.archive.activeSession?.id == sessionID)
        #expect(restored.archive.activeSession?.score == 0)
        #expect(restored.archive.results.isEmpty)
        #expect(restored.pendingResults == 0)
    }

    @Test("Bundled demo begins at the proposed parcours start")
    func bundledStartingPoint() throws {
        let route = try ParcoursCatalogue.loadVerney(bundle: .module)
        let start = try #require(route.parcours?.start)
        let demo = DemoSession(route: route)
        #expect(demo.player == start)
    }
}
