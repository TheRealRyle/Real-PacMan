import Vapor
import Fluent

struct MapPublisherIDsKey: StorageKey { typealias Value = Set<UUID> }

struct MapPublisherGuard: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let player = try request.auth.require(Player.self)
        guard request.application.storage[MapPublisherIDsKey.self, default: []].contains(try player.requireID()) else {
            throw Abort(.forbidden, reason: "This account cannot publish maps. The server owner must add your player ID to MAP_PUBLISHER_IDS.")
        }
        return try await next.respond(to: request)
    }
}

struct MapPublicationStatus: Content {
    let id: UUID
    let latestVersion: Int?
    let publisher: PlayerInfo
}

struct MapPublicationReceipt: Content {
    let id: UUID
    let name: String
    let version: Int
    let duplicate: Bool
}

func mapPublishingRoutes(_ app: Application) throws {
    let configured = (Environment.get("MAP_PUBLISHER_IDS") ?? "")
        .split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    let ids = configured.compactMap(UUID.init(uuidString:))
    guard ids.count == configured.count else {
        throw Abort(.internalServerError, reason: "MAP_PUBLISHER_IDS must contain comma-separated player UUIDs")
    }
    app.storage[MapPublisherIDsKey.self] = Set(ids)
    let admin = app.grouped(PlayerAuthenticator()).grouped(Player.guardMiddleware()).grouped(MapPublisherGuard())
    admin.get("api", "v1", "admin", "routes", ":routeID") { req async throws -> MapPublicationStatus in
        guard let id = req.parameters.get("routeID", as: UUID.self) else { throw Abort(.badRequest, reason: "Invalid map ID") }
        let player = try req.auth.require(Player.self)
        let latest = try await RouteVersion.query(on: req.db).filter(\.$routeID == id).sort(\.$version, .descending).first()
        return MapPublicationStatus(id: id, latestVersion: latest?.version,
            publisher: PlayerInfo(id: try player.requireID(), username: player.username))
    }
    admin.post("api", "v1", "admin", "routes") { req async throws -> Response in
        let route = try req.content.decode(RoutePayload.self)
        try validatePublishedMap(route)
        if let existing = try await RouteVersion.query(on: req.db)
            .filter(\.$routeID == route.id).filter(\.$version == route.version).first() {
            return try publicationResponse(existing: existing, route: route)
        }
        if let latest = try await RouteVersion.query(on: req.db).filter(\.$routeID == route.id)
            .sort(\.$version, .descending).first(), route.version <= latest.version {
            throw Abort(.conflict, reason: "This map is already at version \(latest.version). Increase the version before publishing changes.")
        }
        do {
            try await req.db.transaction { db in try await RouteVersion(route: route).create(on: db) }
        } catch {
            // The unique route/version constraint arbitrates concurrent retries, including across instances.
            if let existing = try await RouteVersion.query(on: req.db)
                .filter(\.$routeID == route.id).filter(\.$version == route.version).first() {
                return try publicationResponse(existing: existing, route: route)
            }
            throw error
        }
        let publisherID = try req.auth.require(Player.self).requireID()
        req.logger.info("Published map \(route.id) version \(route.version) by player \(publisherID)")
        let response = Response(status: .created)
        try response.content.encode(MapPublicationReceipt(id: route.id, name: route.name, version: route.version, duplicate: false))
        return response
    }
}

private func publicationResponse(existing: RouteVersion, route: RoutePayload) throws -> Response {
    guard try existing.route() == route else {
        throw Abort(.conflict, reason: "This map ID and version already contain different data. Increase the version; published versions cannot be overwritten.")
    }
    let response = Response(status: .ok)
    try response.content.encode(MapPublicationReceipt(id: route.id, name: route.name, version: route.version, duplicate: true))
    return response
}
