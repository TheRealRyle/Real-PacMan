import Vapor
import Fluent
import FluentPostgresDriver

public func configure(_ app: Application, configureDatabase: Bool = true) async throws {
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080
    app.routes.defaultMaxBodySize = "4mb"
    if configureDatabase {
        let url = Environment.get("DATABASE_URL")
            ?? "postgres://realpacman:local-development-only@127.0.0.1:5432/realpacman_dev"
        app.databases.use(try .postgres(url: url), as: .psql)
    }
    app.migrations.add(CreateGameSchema())
    app.migrations.add(SeedVerney())
    app.migrations.add(SeedStageTwoVerney())
    try routes(app)
    if Environment.get("AUTO_MIGRATE") == "true" { try await app.autoMigrate() }
}
