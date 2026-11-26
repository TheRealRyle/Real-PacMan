import Vapor
import Fluent
import FluentPostgresDriver

public func configure(_ app: Application, configureDatabase: Bool = true) async throws {
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080
    app.routes.defaultMaxBodySize = "4mb"
    if configureDatabase {
        if app.environment == .production, Environment.get("DATABASE_URL") == nil {
            throw Abort(.internalServerError, reason: "DATABASE_URL is required in production")
        }
        let url = Environment.get("DATABASE_URL")
            ?? "postgres://realpacman:local-development-only@127.0.0.1:5432/realpacman_dev"
        var components = URLComponents(string: url)
        if let mode = Environment.get("DATABASE_TLS_MODE") ?? (app.environment == .production ? "require" : nil) {
            guard ["require", "disable", "prefer"].contains(mode) else {
                throw Abort(.internalServerError, reason: "Invalid DATABASE_TLS_MODE")
            }
            var items = components?.queryItems ?? []
            items.removeAll { ["tlsmode", "sslmode", "tls", "ssl"].contains($0.name) }
            items.append(URLQueryItem(name: "tlsmode", value: mode))
            components?.queryItems = items
        }
        guard let databaseURL = components?.string else {
            throw Abort(.internalServerError, reason: "Invalid DATABASE_URL")
        }
        app.databases.use(try .postgres(url: databaseURL), as: .psql)
    }
    app.migrations.add(CreateGameSchema())
    app.migrations.add(SeedVerney())
    app.migrations.add(SeedStageTwoVerney())
    try routes(app)
    if Environment.get("AUTO_MIGRATE") == "true" {
        guard app.environment != .production else {
            throw Abort(.internalServerError, reason: "Run production migrations explicitly before serving")
        }
        try await app.autoMigrate()
    }
}
