import Testing
import Foundation
import CoreLocation
@testable import ParcoursCore

@MainActor
struct ModeProgressTests {
    private func route() throws -> GameRoute { try ParcoursCatalogue.loadVerney(bundle: .module) }

    @Test("Advertised version two enables all four modes")
    func modes() throws {
        let route = try route()
        #expect(route.version == 2)
        #expect(route.parcours?.supportedModes == ParcoursMode.allCases)
    }

    @Test("Timed play counts active intervals and ends exactly at its limit")
    func timeout() throws {
        let route = try route()
        var rules = ModeProgress(route: route, mode: .timed)
        rules.timeLimitSeconds = 3
        rules.advance(by: 2, route: route, player: nil)
        #expect(rules.activeElapsed == 2)
        #expect(rules.remainingSeconds == 1)
        rules.advance(by: 2, route: route, player: nil)
        #expect(rules.activeElapsed == 3)
        #expect(rules.outcome == .timedOut)
        rules.advance(by: 2, route: route, player: nil)
        #expect(rules.activeElapsed == 3)
    }

    @Test("Demo pause freezes time; real elapsed and mode survive save and restore")
    func pauseAndPersistence() throws {
        let route = try route()
        let demo = DemoSession(route: route, mode: .timed)
        demo.advance(by: 2)
        demo.pause()
        demo.advance(by: 10)
        #expect(demo.rules.activeElapsed == 2)
        let file = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json")
        let game = GameStore(fileURL: file)
        game.start(route, mode: .timedGhosts)
        game.advance(by: 2)
        game.pause()
        game.advance(by: 10)
        let restored = GameStore(fileURL: file)
        #expect(restored.archive.activeSession?.mode == .timedGhosts)
        #expect(restored.archive.activeSession?.rules?.activeElapsed == 2)
        #expect(restored.archive.activeSession?.rules?.ghosts.isEmpty == false)
        #expect(!restored.isPlaying)
    }

    @Test("Huge or invalid ticks are treated as discontinuities")
    func discontinuities() throws {
        let route = try route()
        var rules = ModeProgress(route: route, mode: .timedGhosts)
        rules.advance(by: .infinity, route: route, player: route.parcours?.start)
        rules.advance(by: .nan, route: route, player: route.parcours?.start)
        rules.advance(by: 1e15, route: route, player: route.parcours?.start)
        rules.advance(by: -1, route: route, player: route.parcours?.start)
        #expect(rules.activeElapsed == 0)
        #expect(rules.livesRemaining == 3)
    }

    @Test("Ghost chasing reaches a player's projection in the middle of a long legal path")
    func midpointChase() throws {
        let base = try route()
        let graph = try #require(base.parcours)
        let path = try #require(graph.paths.max { $0.lengthMeters < $1.lengthMeters })
        let player = GhostChase.point(on: path.coordinates, distance: path.lengthMeters / 2)
        var ghosts = [GhostState(id: 0, pathID: path.id, distanceAlongPath: 0, isReversed: false, coordinate: path.coordinates[0])]
        GhostChase.advance(&ghosts, on: base, toward: player, seconds: path.lengthMeters / GhostChase.speedMetersPerSecond + 1)
        #expect(ghosts[0].coordinate.location.distance(from: player.location) < 0.1)
        #expect(abs(ghosts[0].distanceAlongPath - path.lengthMeters / 2) < 0.1)
    }

    @Test("Ghosts remain on paths and collision cooldown ends after three hits")
    func collisions() throws {
        let route = try route()
        let path = try #require(route.parcours?.paths.first)
        let player = path.coordinates[0]
        var rules = ModeProgress(route: route, mode: .ghosts)
        rules.ghosts = [GhostState(id: 0, pathID: path.id, distanceAlongPath: 0, isReversed: false, coordinate: player)]
        rules.advance(by: 9, route: route, player: player)
        #expect(rules.livesRemaining == 3)
        rules.advance(by: 1, route: route, player: player)
        #expect(rules.livesRemaining == 2)
        rules.advance(by: 7, route: route, player: player)
        #expect(rules.livesRemaining == 2)
        rules.advance(by: 9, route: route, player: player)
        #expect(rules.livesRemaining == 0)
        #expect(rules.outcome == .caught)
        #expect(rules.activeElapsed == 26)
        for ghost in rules.ghosts {
            #expect(route.pathLines.contains { line in zip(line, line.dropFirst()).contains { ghost.coordinate.distanceToSegment($0.0, $0.1) < 0.1 } })
        }
    }

    @Test("New rules roundtrip without changing legacy session readability")
    func codable() throws {
        let route = try route()
        var session = GameSession(id: UUID(), route: route, startedAt: Date())
        session.mode = .timedGhosts
        session.rules = ModeProgress(route: route, mode: .timedGhosts)
        session.rules?.advance(by: 1, route: route, player: route.parcours?.start)
        let restored = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        #expect(restored.rules == session.rules)
        session.rules = nil
        let legacy = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        #expect(legacy.rules == nil)
    }
}
