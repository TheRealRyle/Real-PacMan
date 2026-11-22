import Testing
import Foundation
import CoreLocation
@testable import ParcoursCore

struct ServerEndpointTests {
    @Test("Production endpoints preserve a deployment prefix")
    func deploymentPrefix() throws {
        let url = try ServerEndpoint.url("https://example.com/pacman", path: "routes")
        #expect(url.absoluteString == "https://example.com/pacman/api/v1/routes")
    }

    @Test("Malformed and insecure remote endpoints are rejected", arguments: [
        "http://example.com", "https://user:password@example.com", "https://example.com?token=x",
        "https://example.com#fragment", "ftp://example.com", ""
    ])
    func rejectsUnsafeEndpoint(_ base: String) {
        #expect(throws: URLError.self) { try ServerEndpoint.url(base, path: "routes") }
    }

    #if DEBUG
    @Test("Debug builds can reach a loopback development server")
    func loopback() throws {
        #expect(try ServerEndpoint.url("http://127.0.0.1:8080", path: "routes").port == 8080)
    }
    #endif
}

@MainActor
struct ServerIntegrationTests {
    @Test("Stage two modes sync their real session metadata",
          .enabled(if: ProcessInfo.processInfo.environment["REALPACMAN_INTEGRATION_URL"] != nil),
          arguments: [ParcoursMode.timed, .ghosts, .timedGhosts])
    func stageTwoRoundTrip(mode: ParcoursMode) async throws {
        let base = try #require(ProcessInfo.processInfo.environment["REALPACMAN_INTEGRATION_URL"])
        let file = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json")
        let game = GameStore(fileURL: file)
        await game.fetchRoutes(server: base)
        let route = try #require(game.archive.routes.first)
        #expect(route.version >= 2)
        game.start(route, mode: mode)
        let session = try #require(game.archive.activeSession)
        #expect(session.mode == mode)
        #expect(session.rules != nil)
        game.finish()
        await game.sync(server: base)
        #expect(game.message == nil)
        #expect(game.pendingResults == 0)
        let restored = GameStore(fileURL: file)
        #expect(restored.archive.results.first?.mode == mode)
        #expect(restored.archive.results.first?.rules?.outcome == .stopped)
    }

    @Test("Real GameStore downloads routes and safely syncs a completed walk",
          .enabled(if: ProcessInfo.processInfo.environment["REALPACMAN_INTEGRATION_URL"] != nil))
    func clientServerRoundTrip() async throws {
        let base = try #require(ProcessInfo.processInfo.environment["REALPACMAN_INTEGRATION_URL"])
        let file = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json")
        let game = GameStore(fileURL: file)
        await game.fetchRoutes(server: base)
        #expect(game.message == nil)
        let route = try #require(game.archive.routes.first)
        try route.validate()
        game.start(route)
        let pellet = try #require(route.pellets.first)
        game.collect(at: CLLocation(coordinate: pellet.coordinate.coordinate, altitude: 0,
                                   horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date()))
        game.finish()
        let result = try #require(game.archive.results.first)
        #expect(result.score > 0)
        #expect(game.pendingResults == 1)
        await game.sync(server: base + "/missing")
        #expect(game.pendingResults == 1)
        #expect(game.message != nil)
        #expect(GameStore(fileURL: file).pendingResults == 1)
        game.message = nil
        await game.sync(server: base)
        #expect(game.message == nil)
        #expect(game.pendingResults == 0)
        let restored = GameStore(fileURL: file)
        #expect(restored.pendingResults == 0)

        var request = URLRequest(url: try ServerEndpoint.url(base, path: "results"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(result.id.uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try JSONEncoder().encode(result)
        let (_, replay) = try await URLSession.shared.data(for: request)
        #expect((replay as? HTTPURLResponse)?.statusCode == 200)
        var conflict = result
        conflict.distanceMeters += 1
        request.httpBody = try JSONEncoder().encode(conflict)
        let (_, rejected) = try await URLSession.shared.data(for: request)
        #expect((rejected as? HTTPURLResponse)?.statusCode == 409)
    }
}
