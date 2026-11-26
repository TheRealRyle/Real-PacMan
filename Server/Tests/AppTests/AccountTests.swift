import Testing
import VaporTesting
import Fluent
@testable import App

@Suite("Accounts and player authorization")
struct AccountTests {
    @Test("Registration, login, private result lists, ownership, logout and expiry")
    func accountLifecycle() async throws {
        try await withServer { app in
            var alice: LoginReceipt?
            var bob: LoginReceipt?
            func register(_ name: String) async throws -> LoginReceipt {
                var receipt: LoginReceipt?
                try await app.testing().test(.POST, "/api/v1/auth/register", beforeRequest: { req in
                    try req.content.encode(Credentials(username: name, password: "correct-horse-test-password"))
                }, afterResponse: { response async throws in
                    #expect(response.status == .ok)
                    receipt = try response.content.decode(LoginReceipt.self)
                })
                return try #require(receipt)
            }
            alice = try await register("Alice")
            bob = try await register("bob")
            let a = try #require(alice)
            let b = try #require(bob)
            #expect(a.player.username == "alice")
            let stored = try #require(try await Player.find(a.player.id, on: app.db))
            #expect(stored.passwordHash != "correct-horse-test-password")
            #expect(try Bcrypt.verify("correct-horse-test-password", created: stored.passwordHash))
            let storedToken = try #require(try await PlayerToken.query(on: app.db).filter(\.$player.$id == a.player.id).first())
            #expect(storedToken.digest != a.token)
            try await app.testing().test(.POST, "/api/v1/auth/register", beforeRequest: { req in
                try req.content.encode(Credentials(username: "ALICE", password: "another-good-password"))
            }, afterResponse: { response async in #expect(response.status == .conflict) })
            try await app.testing().test(.POST, "/api/v1/auth/login", beforeRequest: { req in
                try req.content.encode(Credentials(username: "alice", password: "incorrect-password"))
            }, afterResponse: { response async in #expect(response.status == .unauthorized) })
            try await app.testing().test(.POST, "/api/v1/auth/login", beforeRequest: { req in
                try req.content.encode(Credentials(username: "ALICE", password: "correct-horse-test-password"))
            }, afterResponse: { response async throws in
                #expect(response.status == .ok)
                #expect(try response.content.decode(LoginReceipt.self).player.id == a.player.id)
            })
            let route = try await fixture(app)
            let now = Date().timeIntervalSinceReferenceDate
            let result = ResultPayload(id: UUID(), route: route, startedAt: now - 60, finishedAt: now,
                collectedPelletIDs: [], distanceMeters: 0, mode: "explore", syncedAt: nil)
            for (token, status) in [(Optional<String>.none, HTTPStatus.unauthorized),
                                    ("invalid", .unauthorized), (a.token, .ok), (b.token, .conflict), (a.token, .ok)] {
                try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { req in
                    if let token { req.headers.bearerAuthorization = .init(token: token) }
                    req.headers.add(name: "Idempotency-Key", value: result.id.uuidString)
                    try req.content.encode(result)
                }, afterResponse: { response async in #expect(response.status == status) })
            }
            #expect(try await StoredResult.find(result.id, on: app.db)?.playerID == a.player.id)
            for (token, expected) in [(a.token, 1), (b.token, 0)] {
                try await app.testing().test(.GET, "/api/v1/results", beforeRequest: { req in
                    req.headers.bearerAuthorization = .init(token: token)
                }, afterResponse: { response async throws in
                    #expect(response.status == .ok)
                    #expect(try response.content.decode([ResultReceipt].self).count == expected)
                })
            }
            try await app.testing().test(.POST, "/api/v1/auth/logout", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: a.token)
            }, afterResponse: { response async in #expect(response.status == .noContent) })
            try await app.testing().test(.GET, "/api/v1/auth/me", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: a.token)
            }, afterResponse: { response async in #expect(response.status == .unauthorized) })
            let expired = PlayerToken(raw: "expired", playerID: b.player.id, expiresAt: .distantPast)
            try await expired.create(on: app.db)
            try await app.testing().test(.GET, "/api/v1/auth/me", beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: "expired")
            }, afterResponse: { response async in #expect(response.status == .unauthorized) })
        }
    }
    @Test("Weak registrations are rejected", arguments: [
        ("ab", "correct-horse-test-password"), ("valid", "short"), ("bad name", "correct-horse-test-password")
    ])
    func invalidRegistration(name: String, password: String) async throws {
        try await withServer { app in
            try await app.testing().test(.POST, "/api/v1/auth/register", beforeRequest: { req in
                try req.content.encode(Credentials(username: name, password: password))
            }, afterResponse: { response async in #expect(response.status == .badRequest) })
        }
    }
}
