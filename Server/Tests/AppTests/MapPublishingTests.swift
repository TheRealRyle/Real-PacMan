import Testing
import VaporTesting
import Fluent
@testable import App

private func allowTestPublisher(_ app: Application) async throws -> String {
    let raw = try #require(app.storage[TestTokenKey.self])
    let token = try #require(try await PlayerToken.query(on: app.db).filter(\.$digest == tokenDigest(raw)).first())
    app.storage[MapPublisherIDsKey.self] = [token.$player.id]
    return raw
}

private func publishingMap(_ source: RoutePayload, id: UUID = UUID(), version: Int = 1, name: String = "Builder map") -> RoutePayload {
    RoutePayload(id: id, name: name, version: version, coordinates: source.coordinates,
        pellets: source.pellets, mapStyleURL: source.mapStyleURL, parcours: source.parcours)
}

@Suite("Map publishing authorization, validation and immutable catalogue")
struct MapPublishingTests {
    @Test("Anonymous users and ordinary accounts cannot publish or inspect admin status")
    func authorization() async throws {
        try await withServer { app in
            let route = publishingMap(try await fixture(app))
            let raw = try #require(app.storage[TestTokenKey.self])
            for (token, status) in [(Optional<String>.none, HTTPStatus.unauthorized), ("invalid", .unauthorized), (raw, .forbidden)] {
                try await app.testing().test(.POST, "/api/v1/admin/routes", beforeRequest: { req in
                    if let token { req.headers.bearerAuthorization = .init(token: token) }
                    try req.content.encode(route)
                }, afterResponse: { response async throws in
                    #expect(response.status == status)
                    #expect(try await RouteVersion.query(on: app.db).filter(\.$routeID == route.id).count() == 0)
                })
                try await app.testing().test(.GET, "/api/v1/admin/routes/\(route.id)", beforeRequest: { req in
                    if let token { req.headers.bearerAuthorization = .init(token: token) }
                }, afterResponse: { response async in #expect(response.status == status) })
            }
        }
    }

    @Test("Publishing a new map makes it playable through the existing catalogue; retries do not duplicate rows")
    func publishAndList() async throws {
        try await withServer { app in
            let route = publishingMap(try await fixture(app))
            let raw = try await allowTestPublisher(app)
            try await app.testing().test(.GET, "/api/v1/admin/routes/\(route.id)", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: raw)
            }, afterResponse: { response async throws in
                #expect(response.status == .ok)
                #expect(try response.content.decode(MapPublicationStatus.self).latestVersion == nil)
                #expect(response.headers.first(name: .cacheControl) == "no-store")
            })
            for duplicate in [false, true] {
                try await app.testing().test(.POST, "/api/v1/admin/routes", beforeRequest: { req in
                    req.headers.bearerAuthorization = .init(token: raw)
                    try req.content.encode(route)
                }, afterResponse: { response async throws in
                    #expect(response.status == (duplicate ? .ok : .created))
                    let receipt = try response.content.decode(MapPublicationReceipt.self)
                    #expect(receipt.id == route.id)
                    #expect(receipt.version == route.version)
                    #expect(receipt.duplicate == duplicate)
                    #expect(try await RouteVersion.query(on: app.db).filter(\.$routeID == route.id).count() == 1)
                })
            }
            try await app.testing().test(.GET, "/api/v1/routes") { response async throws in
                let routes = try response.content.decode([RoutePayload].self)
                #expect(routes.contains(route))
                #expect(response.headers.first(name: .cacheControl) == "no-store")
            }
        }
    }

    @Test("Published snapshots cannot be overwritten; higher versions append and stale new versions conflict")
    func versioning() async throws {
        try await withServer { app in
            let route = publishingMap(try await fixture(app))
            let raw = try await allowTestPublisher(app)
            let update = publishingMap(route, id: route.id, version: 3, name: "Updated map")
            let changedSameVersion = publishingMap(route, id: route.id, name: "Attempted overwrite")
            let stale = publishingMap(route, id: route.id, version: 2)
            for (payload, status) in [(route, HTTPStatus.created), (changedSameVersion, .conflict), (update, .created), (stale, .conflict)] {
                try await app.testing().test(.POST, "/api/v1/admin/routes", beforeRequest: { req in
                    req.headers.bearerAuthorization = .init(token: raw)
                    try req.content.encode(payload)
                }, afterResponse: { response async in #expect(response.status == status) })
            }
            let original = try #require(try await RouteVersion.query(on: app.db).filter(\.$routeID == route.id).filter(\.$version == 1).first())
            #expect(try original.route() == route)
            #expect(try await RouteVersion.query(on: app.db).filter(\.$routeID == route.id).count() == 2)
            try await app.testing().test(.GET, "/api/v1/routes") { response async throws in
                let routes = try response.content.decode([RoutePayload].self)
                #expect(routes.first { $0.id == route.id } == update)
            }
        }
    }

    @Test("Invalid maps are rejected before reaching the database", arguments: ["emptyPellets", "duplicatePellets", "invalidCoordinate", "missingJunction", "offPath", "httpStyle", "disconnected"])
    func invalidMap(kind: String) async throws {
        try await withServer { app in
            let route = publishingMap(try await fixture(app))
            let raw = try await allowTestPublisher(app)
            var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(route)) as? [String: Any])
            switch kind {
            case "emptyPellets": object["pellets"] = []
            case "duplicatePellets":
                let pellets = try #require(object["pellets"] as? [[String: Any]])
                object["pellets"] = [pellets[0], pellets[0]]
            case "invalidCoordinate", "offPath":
                var pellets = try #require(object["pellets"] as? [[String: Any]])
                pellets[0]["coordinate"] = ["latitude": kind == "invalidCoordinate" ? 1000.0 : 0.0, "longitude": 0.0]
                object["pellets"] = pellets
            case "missingJunction":
                var graph = try #require(object["parcours"] as? [String: Any])
                graph["startJunctionID"] = "missing"; object["parcours"] = graph
            case "disconnected":
                var graph = try #require(object["parcours"] as? [String: Any])
                var nodes = try #require(graph["junctions"] as? [[String: Any]])
                var extra = nodes[0]; extra["id"] = "unreachable"; nodes.append(extra)
                graph["junctions"] = nodes; object["parcours"] = graph
            default: object["mapStyleURL"] = "http://example.com/style.json"
            }
            let invalid = try JSONDecoder().decode(RoutePayload.self, from: JSONSerialization.data(withJSONObject: object))
            try await app.testing().test(.POST, "/api/v1/admin/routes", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: raw)
                try req.content.encode(invalid)
            }, afterResponse: { response async throws in
                #expect(response.status == .unprocessableEntity)
                #expect(try await RouteVersion.query(on: app.db).filter(\.$routeID == route.id).count() == 0)
            })
        }
    }

    @Test("Revoking publishing access takes effect on the next request")
    func revocation() async throws {
        try await withServer { app in
            let route = publishingMap(try await fixture(app))
            let raw = try await allowTestPublisher(app)
            app.storage[MapPublisherIDsKey.self] = []
            try await app.testing().test(.POST, "/api/v1/admin/routes", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: raw)
                try req.content.encode(route)
            }, afterResponse: { response async in #expect(response.status == .forbidden) })
        }
    }
}
