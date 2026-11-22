import Fluent
import Vapor

struct CreateGameSchema: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(RouteVersion.schema).id()
            .field("route_id", .uuid, .required).field("version", .int, .required)
            .field("payload", .string, .required).unique(on: "route_id", "version").create()
        try await database.schema(StoredResult.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("route_version_id", .uuid, .required, .references(RouteVersion.schema, .id))
            .field("payload", .string, .required).field("score", .int, .required).create()
    }
    func revert(on database: any Database) async throws {
        try await database.schema(StoredResult.schema).delete()
        try await database.schema(RouteVersion.schema).delete()
    }
}

struct SeedVerney: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await seedVerney(resource: "verney-v1", on: database)
    }
    func revert(on database: any Database) async throws {
        // Retain published versions and attached results; schema rollback handles deletion.
    }
}

struct SeedStageTwoVerney: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await seedVerney(resource: "verney-draft", on: database)
    }
    func revert(on database: any Database) async throws {}
}

private func seedVerney(resource: String, on database: any Database) async throws {
    guard let url = Bundle.module.url(forResource: resource, withExtension: "json") else {
        throw Abort(.internalServerError, reason: "Bundled parcours missing")
    }
    let route = try JSONDecoder().decode(RoutePayload.self, from: Data(contentsOf: url))
    if let existing = try await RouteVersion.query(on: database)
        .filter(\.$routeID == route.id).filter(\.$version == route.version).first() {
        guard try existing.route() == route else {
            throw Abort(.internalServerError, reason: "Bundled route version conflicts with stored canonical version")
        }
        return
    }
    try await RouteVersion(route: route).create(on: database)
}
