import Testing
import VaporTesting
import Fluent
import FluentPostgresDriver
@testable import App

@Suite("Production PostgreSQL persistence")
struct PostgreSQLTests {
    @Test("Migrations, concurrent retries and persistence across application restarts",
          .enabled(if: Environment.get("POSTGRES_TEST_URL") != nil))
    func postgresPersistence() async throws {
        let url = try #require(Environment.get("POSTGRES_TEST_URL"))
        // Use a dedicated test database: migrations seed immutable route versions.
        let database = URLComponents(string: url)?.path ?? ""
        try #require(database.hasSuffix("_test"), "POSTGRES_TEST_URL must name a database ending in _test")
        let id = UUID()
        let testPlayerID = UUID()
        let testToken = UUID().uuidString
        var saved: ResultPayload?
        func configurePostgres(_ app: Application) async throws {
            app.databases.use(try .postgres(url: url), as: .psql)
            try await configure(app, configureDatabase: false)
            try await app.autoMigrate()
            try await seedTestAccount(app, id: testPlayerID, token: testToken)
        }
        try await withApp(configure: configurePostgres) { app in
            // Reapplying migrations must preserve both published versions.
            try await app.autoMigrate()
            let route = try await fixture(app)
            #expect(try await RouteVersion.query(on: app.db).filter(\.$routeID == route.id).count() == 2)
            let now = Date().timeIntervalSinceReferenceDate
            let payload = ResultPayload(id: id, route: route, startedAt: now - 60,
                finishedAt: now, collectedPelletIDs: [route.pellets[0].id],
                distanceMeters: 10, mode: "explore", syncedAt: nil)
            saved = payload
            try await app.testing().test(.GET, "/health") { response async in
                #expect(response.status == .ok)
            }
            @Sendable func upload() async throws {
                try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.bearerAuthorization = .init(token: app.storage[TestTokenKey.self]!)
                    request.headers.add(name: "Idempotency-Key", value: id.uuidString)
                    try request.content.encode(payload)
                }, afterResponse: { response async throws in
                    #expect(response.status == .ok)
                    #expect(try response.content.decode(ResultReceipt.self).score == route.pellets[0].value)
                })
            }
            async let first: Void = upload()
            async let second: Void = upload()
            try await first
            try await second
            #expect(try await StoredResult.query(on: app.db).filter(\.$id == id).count() == 1)
        }
        // A second Application opens fresh connections to the same PostgreSQL DB.
        try await withApp(configure: configurePostgres) { app in
            let payload = try #require(saved)
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.bearerAuthorization = .init(token: app.storage[TestTokenKey.self]!)
                request.headers.add(name: "Idempotency-Key", value: id.uuidString)
                try request.content.encode(payload)
            }, afterResponse: { response async throws in
                #expect(response.status == .ok)
                #expect(try response.content.decode(ResultReceipt.self).duplicate)
            })
            let conflict = ResultPayload(id: id, route: payload.route, startedAt: payload.startedAt,
                finishedAt: payload.finishedAt, collectedPelletIDs: [], distanceMeters: 0,
                mode: "explore", syncedAt: nil)
            try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
                request.headers.bearerAuthorization = .init(token: app.storage[TestTokenKey.self]!)
                request.headers.add(name: "Idempotency-Key", value: id.uuidString)
                try request.content.encode(conflict)
            }, afterResponse: { response async in
                #expect(response.status == .conflict)
            })
            // Remove only this test's synthetic result, retaining canonical versions.
            try await StoredResult.find(id, on: app.db)?.delete(on: app.db)
        }
    }
}
