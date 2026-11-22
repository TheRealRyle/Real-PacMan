import App
import Fluent
import FluentSQLiteDriver
import Vapor

/// Test-only HTTP harness. Production Run always configures PostgreSQL.
@main
enum IntegrationServer {
    static func main() async throws {
        let app = try await Application.make(.testing)
        do {
            app.databases.use(.sqlite(.memory), as: .sqlite)
            try await configure(app, configureDatabase: false)
            try await app.autoMigrate()
            app.logger.notice("Integration server uses an isolated in-memory SQLite database")
            try await app.execute()
            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }
}
