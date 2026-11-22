import Testing
import VaporTesting
import Fluent
import FluentSQLiteDriver
@testable import App

func withServer(_ body: (Application) async throws -> Void) async throws {
    try await withApp(configure: { app in
        app.databases.use(.sqlite(.memory), as: .sqlite)
        try await configure(app, configureDatabase: false)
        try await app.autoMigrate()
    }, body)
}

func fixture(_ app: Application, version: Int = 2) async throws -> RoutePayload {
    let row = try #require(try await RouteVersion.query(on: app.db).filter(\.$version == version).first())
    return try row.route()
}

private func result(_ route: RoutePayload, id: UUID = UUID(), pellets: [UUID]? = nil,
                    distance: Double = 10, finishedAt: Double? = Date().timeIntervalSinceReferenceDate) -> ResultPayload {
    ResultPayload(id: id, route: route, startedAt: Date().timeIntervalSinceReferenceDate - 600,
                  finishedAt: finishedAt, collectedPelletIDs: pellets ?? [route.pellets[0].id],
                  distanceMeters: distance, mode: "explore", syncedAt: nil)
}

@Suite("HTTP and database contract")
struct APITests {
    @Test("Health checks the database; catalogue preserves the canonical bundled graph")
    func catalogue() async throws {
        try await withServer { app in
            try await app.testing().test(.GET, "/health") { response async in
                #expect(response.status == .ok)
            }
            try await app.testing().test(.GET, "/api/v1/routes") { response async throws in
                #expect(response.status == .ok)
                let routes = try response.content.decode([RoutePayload].self)
                let route = try #require(routes.first)
                #expect(routes.count == 1)
                #expect(route.id == UUID(uuidString: "7DAB402C-797E-4B41-A47D-54D01D1CF361"))
                #expect(route.version == 2)
                #expect(route.parcours != nil)
                #expect(route.pellets.count == 25)
            }
        }
    }

    @Test("Result is committed once; retry order is semantic and changed result conflicts")
    func idempotency() async throws {
        try await withServer { app in
            let route = try await fixture(app)
            let payload = result(route, pellets: Array(route.pellets.prefix(2).map(\.id)))
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.add(name: "Idempotency-Key", value: payload.id.uuidString)
                try request.content.encode(payload)
            }, afterResponse: { response async throws in
                #expect(response.status == .ok)
                let receipt = try response.content.decode(ResultReceipt.self)
                #expect(receipt.score == 20)
                #expect(!receipt.duplicate)
            })
            let retry = ResultPayload(id: payload.id, route: route, startedAt: payload.startedAt,
                finishedAt: payload.finishedAt, collectedPelletIDs: Array(payload.collectedPelletIDs.reversed()),
                distanceMeters: payload.distanceMeters, mode: payload.mode, syncedAt: nil)
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.add(name: "Idempotency-Key", value: payload.id.uuidString)
                try request.content.encode(retry)
            }, afterResponse: { response async throws in
                #expect(response.status == .ok)
                #expect(try response.content.decode(ResultReceipt.self).duplicate)
                #expect(try await StoredResult.query(on: app.db).count() == 1)
            })
            let conflict = ResultPayload(id: payload.id, route: route, startedAt: payload.startedAt,
                finishedAt: payload.finishedAt, collectedPelletIDs: payload.collectedPelletIDs,
                distanceMeters: 20, mode: payload.mode, syncedAt: nil)
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.add(name: "Idempotency-Key", value: payload.id.uuidString)
                try request.content.encode(conflict)
            }, afterResponse: { response async in #expect(response.status == .conflict) })
        }
    }

    @Test("Missing idempotency key cannot create a result")
    func missingKey() async throws {
        try await withServer { app in
            let payload = result(try await fixture(app))
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                try request.content.encode(payload)
            }, afterResponse: { response async throws in
                #expect(response.status == .badRequest)
                #expect(try await StoredResult.query(on: app.db).count() == 0)
            })
        }
    }

    @Test("A fresh GPS fix recorded before session creation permits its accepted distance")
    func initialGPSFreshnessWindow() async throws {
        try await withServer { app in
            let route = try await fixture(app)
            let now = Date().timeIntervalSinceReferenceDate
            let payload = ResultPayload(id: UUID(), route: route, startedAt: now, finishedAt: now,
                collectedPelletIDs: [], distanceMeters: 90, mode: "explore", syncedAt: nil)
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.add(name: "Idempotency-Key", value: payload.id.uuidString)
                try request.content.encode(payload)
            }, afterResponse: { response async in #expect(response.status == .ok) })
        }
    }

    @Test("Concurrent identical uploads persist one accepted result")
    func concurrentRetries() async throws {
        try await withServer { app in
            let payload = result(try await fixture(app))
            @Sendable func upload() async throws {
                try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                    request.headers.add(name: "Idempotency-Key", value: payload.id.uuidString)
                    try request.content.encode(payload)
                }, afterResponse: { response async in #expect(response.status == .ok) })
            }
            async let first: Void = upload()
            async let second: Void = upload()
            try await first
            try await second
            #expect(try await StoredResult.query(on: app.db).count() == 1)
        }
    }

    @Test("Invalid uploads never enter the result table", arguments: [
        "unknownPellet", "duplicatePellet", "negativeDistance", "missingFinish", "unknownVersion", "alteredValue",
        "futureFinish", "reversedDates", "implausibleDistance", "demoMode"
    ])
    func invalidResult(kind: String) async throws {
        try await withServer { app in
            let route = try await fixture(app)
            var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(result(route))) as? [String: Any])
            switch kind {
            case "unknownPellet": object["collectedPelletIDs"] = [UUID().uuidString]
            case "duplicatePellet": object["collectedPelletIDs"] = [route.pellets[0].id.uuidString, route.pellets[0].id.uuidString]
            case "negativeDistance": object["distanceMeters"] = -1
            case "missingFinish": object.removeValue(forKey: "finishedAt")
            case "futureFinish": object["finishedAt"] = Date().timeIntervalSinceReferenceDate + 3600
            case "reversedDates": object["finishedAt"] = (object["startedAt"] as! Double) - 1
            case "implausibleDistance": object["distanceMeters"] = 1_000_000
            case "demoMode": object["mode"] = "demo"
            case "unknownVersion":
                var snapshot = object["route"] as! [String: Any]
                snapshot["version"] = 999
                object["route"] = snapshot
            default:
                var snapshot = object["route"] as! [String: Any]
                var pellets = snapshot["pellets"] as! [[String: Any]]
                pellets[0]["value"] = 999
                snapshot["pellets"] = pellets
                object["route"] = snapshot
            }
            let data = try JSONSerialization.data(withJSONObject: object)
            let id = try #require(object["id"] as? String)
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.add(name: "Idempotency-Key", value: id)
                request.headers.contentType = .json
                request.body = ByteBuffer(data: data)
            }, afterResponse: { response async throws in
                #expect(response.status == .unprocessableEntity)
                #expect(try await StoredResult.query(on: app.db).count() == 0)
            })
        }
    }

    @Test("New catalogue version does not invalidate a walk recorded on the previous version")
    func oldVersionResult() async throws {
        try await withServer { app in
            let old = try await fixture(app, version: 1)
            let newer = RoutePayload(id: old.id, name: "Updated Verney", version: 3,
                coordinates: old.coordinates, pellets: old.pellets, mapStyleURL: old.mapStyleURL, parcours: old.parcours)
            try await RouteVersion(route: newer).create(on: app.db)
            try await app.testing().test(.GET, "/api/v1/routes") { response async throws in
                let routes = try response.content.decode([RoutePayload].self)
                #expect(routes.count == 1)
                #expect(routes.first?.version == 3)
            }
            let payload = result(old)
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.add(name: "Idempotency-Key", value: payload.id.uuidString)
                try request.content.encode(payload)
            }, afterResponse: { response async in #expect(response.status == .ok) })
        }
    }
}
