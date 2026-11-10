import Testing
import Foundation
import CoreLocation
@testable import ParcoursCore

struct ParcoursTests {
    private func verney() throws -> GameRoute {
        try ParcoursCatalogue.loadVerney(bundle: .module)
    }

    @Test("Verney contains a connected, validated OSM path graph")
    func bundledGraph() throws {
        let route = try verney()
        let graph = try #require(route.parcours)
        #expect(graph.paths.count > 1)
        #expect(graph.junctions.contains { $0.id == graph.startJunctionID })
        #expect(graph.fieldVerified == false)
        #expect(graph.supportedModes == [.explore])
        #expect(route.pathLines.count == graph.paths.count)
        #expect(route.mapCoordinates.count > route.coordinates.count)
        #expect(route.distanceMeters > 1000 && route.distanceMeters < 2000)
        #expect(graph.paths.allSatisfy { $0.osmWayID != nil })
        try route.validate()
    }

    @Test("Old route JSON still decodes with ten-point pellets")
    func legacyCompatibility() throws {
        let coordinate = RouteCoordinate(latitude: 48.85, longitude: 2.35)
        let route = GameRoute(id: UUID(), name: "Legacy", version: 1,
                              coordinates: [coordinate, .init(latitude: 48.851, longitude: 2.35)],
                              pellets: [.init(id: UUID(), coordinate: coordinate)],
                              mapStyleURL: URL(string: "https://example.com/style.json")!)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(route)) as? [String: Any])
        json.removeValue(forKey: "parcours")
        var pellets = try #require(json["pellets"] as? [[String: Any]])
        pellets[0].removeValue(forKey: "value")
        json["pellets"] = pellets
        let restored = try JSONDecoder().decode(GameRoute.self, from: JSONSerialization.data(withJSONObject: json))
        try restored.validate()
        #expect(restored.parcours == nil)
        #expect(restored.pellets[0].value == 10)
        #expect(restored.pathLines == [route.coordinates])
    }

    @Test("Graph definitions survive a JSON round trip")
    func graphRoundTrip() throws {
        let route = try verney()
        let restored = try JSONDecoder().decode(GameRoute.self, from: JSONEncoder().encode(route))
        #expect(restored == route)
        #expect(restored.totalPoints == restored.pellets.count * 10)
    }

    @Test("Malformed networks are rejected", arguments: ["unknownJunction", "disconnected", "outsidePellet", "invalidValue"])
    func invalidGraph(kind: String) throws {
        let route = try verney()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(route)) as? [String: Any])
        var graph = try #require(json["parcours"] as? [String: Any])
        if kind == "unknownJunction" {
            var paths = try #require(graph["paths"] as? [[String: Any]])
            paths[0]["from"] = "missing"
            graph["paths"] = paths
        } else if kind == "disconnected" {
            var nodes = try #require(graph["junctions"] as? [[String: Any]])
            let coordinate = try #require(nodes.first?["coordinate"])
            nodes.append(["id": "isolated", "coordinate": coordinate])
            graph["junctions"] = nodes
        } else {
            var pellets = try #require(json["pellets"] as? [[String: Any]])
            if kind == "outsidePellet" {
                pellets[0]["coordinate"] = ["latitude": 0, "longitude": 0]
            } else { pellets[0]["value"] = -10 }
            json["pellets"] = pellets
        }
        json["parcours"] = graph
        let invalid = try JSONDecoder().decode(GameRoute.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: (any Error).self) { try invalid.validate() }
    }

    @Test("Draft parcours cannot accidentally start a GPS game")
    @MainActor func draftCannotStart() throws {
        let file = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json")
        let store = GameStore(fileURL: file)
        store.start(try verney())
        #expect(store.archive.activeSession == nil)
        #expect(!store.isPlaying)
        #expect(store.message != nil)
    }

    @Test("Server data replaces the bundled draft by stable ID")
    func serverOverridesDraft() throws {
        let route = try verney()
        let published = GameRoute(id: route.id, name: "Published Verney", version: 2,
                                  coordinates: route.coordinates, pellets: route.pellets,
                                  mapStyleURL: route.mapStyleURL)
        let entries = ParcoursCatalogue.entries(saved: [published], prototype: route)
        #expect(entries.count == 3)
        #expect(entries.filter { $0.id == route.id }.count == 1)
        #expect(entries[0].route == published)
        #expect(entries[1].route == nil && entries[2].route == nil)
    }


    @Test("Legacy session JSON restores without mode or graph metadata")
    @MainActor func savedSessionCompatibility() throws {
        let coordinate = RouteCoordinate(latitude: 48.85, longitude: 2.35)
        let pellet = Pellet(id: UUID(), coordinate: coordinate)
        let route = GameRoute(id: UUID(), name: "Old walk", version: 1,
                              coordinates: [coordinate, .init(latitude: 48.851, longitude: 2.35)],
                              pellets: [pellet], mapStyleURL: URL(string: "https://example.com/style.json")!)
        var session = GameSession(id: UUID(), route: route, startedAt: Date())
        session.collectedPelletIDs = [pellet.id]
        var archive = GameArchive()
        archive.activeSession = session
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
        var active = try #require(json["activeSession"] as? [String: Any])
        active.removeValue(forKey: "mode")
        json["activeSession"] = active
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "progress.json")
        try JSONSerialization.data(withJSONObject: json).write(to: file)
        let restored = GameStore(fileURL: file)
        #expect(restored.archive.activeSession?.id == session.id)
        #expect(restored.archive.activeSession?.score == 10)
        #expect(restored.archive.activeSession?.mode == nil)
        #expect(!restored.isPlaying)
    }

    @Test("Saved result points come from the versioned pellet values")
    func versionedScore() throws {
        var route = try verney()
        route.parcours = nil
        let first = try #require(route.pellets.first)
        let special = Pellet(id: first.id, coordinate: first.coordinate, value: 50)
        let scoringRoute = GameRoute(id: route.id, name: route.name, version: route.version,
                                    coordinates: route.coordinates, pellets: [special], mapStyleURL: route.mapStyleURL)
        var session = GameSession(id: UUID(), route: scoringRoute, startedAt: Date())
        session.collectedPelletIDs = [first.id, UUID()]
        #expect(session.score == 50)
        #expect(session.mode == .explore)
    }
}
