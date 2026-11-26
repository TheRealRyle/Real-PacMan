import Vapor
import Fluent
import Crypto

final class Player: Model, Authenticatable, @unchecked Sendable {
    static let schema = "players"
    @ID(key: .id) var id: UUID?
    @Field(key: "username") var username: String
    @Field(key: "password_hash") var passwordHash: String
    init() {}
    init(username: String, passwordHash: String) {
        self.username = username; self.passwordHash = passwordHash
    }
}
final class PlayerToken: Model, @unchecked Sendable {
    static let schema = "player_tokens"
    @ID(key: .id) var id: UUID?
    @Field(key: "digest") var digest: String
    @Parent(key: "player_id") var player: Player
    @Field(key: "expires_at") var expiresAt: Date
    init() {}
    init(raw: String, playerID: UUID, expiresAt: Date) {
        digest = tokenDigest(raw); $player.id = playerID; self.expiresAt = expiresAt
    }
}
func tokenDigest(_ token: String) -> String {
    SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
}
struct PlayerInfo: Content { let id: UUID; let username: String }
struct LoginReceipt: Content { let player: PlayerInfo; let token: String; let expiresAt: Double }
struct Credentials: Content { let username: String; let password: String }
struct PlayerAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        guard bearer.token.utf8.count <= 128,
              let token = try await PlayerToken.query(on: request.db).filter(\.$digest == tokenDigest(bearer.token))
                .filter(\.$expiresAt > Date()).first(),
              let player = try await Player.find(token.$player.id, on: request.db) else { return }
        request.auth.login(player)
    }
}
actor LoginThrottle {
    private var attempts: [String: [Date]] = [:]
    func check(_ key: String) throws {
        let cutoff = Date().addingTimeInterval(-60)
        attempts = attempts.mapValues { $0.filter { $0 > cutoff } }.filter { !$0.value.isEmpty }
        var recent = attempts[key] ?? []
        guard recent.count < 10 else { throw Abort(.tooManyRequests, reason: "Please wait a minute before trying again.") }
        recent.append(Date()); attempts[key] = recent
    }
}
func accountRoutes(_ app: Application) {
    app.middleware.use(AccountResponseHeaders())
    let throttle = LoginThrottle()
    @Sendable func issue(_ player: Player, _ req: Request) async throws -> LoginReceipt {
        let raw = Data([UInt8].random(count: 32)).base64EncodedString()
        let expiry = Date().addingTimeInterval(30 * 86400)
        try await PlayerToken(raw: raw, playerID: player.requireID(), expiresAt: expiry).create(on: req.db)
        return LoginReceipt(player: PlayerInfo(id: try player.requireID(), username: player.username), token: raw, expiresAt: expiry.timeIntervalSinceReferenceDate)
    }
    app.post("api", "v1", "auth", "register") { req async throws -> LoginReceipt in
        try await throttle.check(req.remoteAddress?.ipAddress ?? "unknown")
        let input = try req.content.decode(Credentials.self)
        let name = input.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard name.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil,
              (10...72).contains(input.password.utf8.count) else {
            throw Abort(.badRequest, reason: "Use 3–24 letters, digits or underscores for your username and a password of 10–72 bytes.")
        }
        let hash = try await req.password.async.hash(input.password).get()
        let player = Player(username: name, passwordHash: hash)
        do { try await player.create(on: req.db) }
        catch {
            if try await Player.query(on: req.db).filter(\.$username == name).first() != nil {
                throw Abort(.conflict, reason: "That username is already taken.")
            }
            throw error
        }
        return try await issue(player, req)
    }
    app.post("api", "v1", "auth", "login") { req async throws -> LoginReceipt in
        try await throttle.check(req.remoteAddress?.ipAddress ?? "unknown")
        let input = try req.content.decode(Credentials.self)
        guard input.password.utf8.count <= 72, input.username.utf8.count <= 100 else { throw Abort(.unauthorized) }
        let name = input.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let player = try await Player.query(on: req.db).filter(\.$username == name).first()
        // A real bcrypt digest keeps unknown-user attempts on the same expensive path.
        let digest = player?.passwordHash ?? "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxAqkKz5PzrKM7gRHfMBcNwG1Ka"
        let valid = (try? await req.password.async.verify(input.password, created: digest).get()) ?? false
        guard valid, let player else { throw Abort(.unauthorized, reason: "Incorrect username or password.") }
        return try await issue(player, req)
    }
    let secure = app.grouped(PlayerAuthenticator()).grouped(Player.guardMiddleware())
    secure.get("api", "v1", "auth", "me") { req async throws -> PlayerInfo in
        let player = try req.auth.require(Player.self)
        return PlayerInfo(id: try player.requireID(), username: player.username)
    }
    secure.post("api", "v1", "auth", "logout") { req async throws -> HTTPStatus in
        if let raw = req.headers.bearerAuthorization?.token {
            try await PlayerToken.query(on: req.db).filter(\.$digest == tokenDigest(raw)).delete()
        }
        return .noContent
    }
    secure.get("api", "v1", "results") { req async throws -> [ResultReceipt] in
        let id = try req.auth.require(Player.self).requireID()
        return try await StoredResult.query(on: req.db).filter(\.$playerID == id).all().map {
            ResultReceipt(id: try $0.requireID(), score: $0.score, duplicate: true)
        }
    }
}
struct AddPlayerAccounts: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema(Player.schema).id().field("username", .string, .required)
            .field("password_hash", .string, .required).unique(on: "username").create()
        try await db.schema(PlayerToken.schema).id().field("digest", .string, .required).unique(on: "digest")
            .field("player_id", .uuid, .required, .references(Player.schema, .id))
            .field("expires_at", .datetime, .required).create()
        try await db.schema(StoredResult.schema).field("player_id", .uuid, .references(Player.schema, .id)).update()
    }
    func revert(on db: any Database) async throws {
        try await db.schema(StoredResult.schema).deleteField("player_id").update()
        try await db.schema(PlayerToken.schema).delete()
        try await db.schema(Player.schema).delete()
    }
}

struct AccountResponseHeaders: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        if request.url.path.hasPrefix("/api/v1/auth/") || request.url.path == "/api/v1/results" {
            response.headers.replaceOrAdd(name: .cacheControl, value: "no-store")
        }
        return response
    }
}
