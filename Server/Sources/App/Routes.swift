import Vapor
import Fluent

func routes(_ app: Application) throws {
    app.get("health") { req async throws -> HTTPStatus in
        _ = try await RouteVersion.query(on: req.db).first()
        return .ok
    }
    app.get("api", "v1", "routes") { req async throws -> [RoutePayload] in
        let versions = try await RouteVersion.query(on: req.db).sort(\.$version, .descending).all()
        var latest: [UUID: RoutePayload] = [:]
        for version in versions where latest[version.routeID] == nil {
            latest[version.routeID] = try version.route()
        }
        return latest.values.sorted { $0.name < $1.name }
    }
    app.grouped(PlayerAuthenticator()).grouped(Player.guardMiddleware()).post("api", "v1", "results") { req async throws -> ResultReceipt in
        let playerID = try req.auth.require(Player.self).requireID()
        let result = try req.content.decode(ResultPayload.self)
        guard let key = req.headers.first(name: "Idempotency-Key"), UUID(uuidString: key) == result.id else {
            throw Abort(.badRequest, reason: "Idempotency-Key must equal the session UUID")
        }
        let payload = try result.canonicalJSON()
        if let existing = try await StoredResult.find(result.id, on: req.db) {
            guard existing.playerID == playerID else { throw Abort(.conflict, reason: "Result belongs to another player or is a legacy anonymous result") }
            return try receipt(for: existing, matching: payload, id: result.id)
        }
        guard let version = try await RouteVersion.query(on: req.db)
            .filter(\.$routeID == result.route.id).filter(\.$version == result.route.version).first() else {
            throw Abort(.unprocessableEntity, reason: "Unknown parcours version")
        }
        let canonical = try version.route()
        let score = try validate(result, against: canonical)
        let versionID = try version.requireID()
        do {
            try await req.db.transaction { database in
                let stored = StoredResult(id: result.id, routeVersionID: versionID, payload: payload, score: score)
                stored.playerID = playerID
                try await stored.create(on: database)
            }
        } catch {
            // A concurrent identical request can win the primary-key race. Query outside
            // the failed transaction, which PostgreSQL has already rolled back.
            if let existing = try await StoredResult.find(result.id, on: req.db) {
                guard existing.playerID == playerID else { throw Abort(.conflict, reason: "Result belongs to another player or is a legacy anonymous result") }
            return try receipt(for: existing, matching: payload, id: result.id)
            }
            throw error
        }
        return ResultReceipt(id: result.id, score: score, duplicate: false)
    }
}

private func receipt(for existing: StoredResult, matching payload: String, id: UUID) throws -> ResultReceipt {
    guard existing.payload == payload else { throw Abort(.conflict, reason: "Session UUID already contains a different result") }
    return ResultReceipt(id: id, score: existing.score, duplicate: true)
}

func validate(_ result: ResultPayload, against route: RoutePayload, now: Date = Date()) throws -> Int {
    guard result.route == route else { throw Abort(.unprocessableEntity, reason: "Route snapshot differs from published version") }
    guard ["explore", "timed", "ghosts", "timedGhosts"].contains(result.mode ?? "explore") else {
        throw Abort(.unprocessableEntity, reason: "Unsupported mode")
    }
    guard Set(result.collectedPelletIDs).count == result.collectedPelletIDs.count else {
        throw Abort(.unprocessableEntity, reason: "Duplicate collected pellet IDs")
    }
    let members = Set(route.pellets.map(\.id))
    guard Set(result.collectedPelletIDs).isSubset(of: members) else {
        throw Abort(.unprocessableEntity, reason: "Collected pellet does not belong to this parcours version")
    }
    guard let finish = result.finishedAt, finish.isFinite, result.startedAt.isFinite,
          result.startedAt >= 0, finish >= result.startedAt,
          finish <= now.timeIntervalSinceReferenceDate + 300,
          result.distanceMeters.isFinite, result.distanceMeters >= 0,
          // The client's first accepted fix may predate session creation by up to
          // its ten-second freshness window. Include that interval in the bound.
          result.distanceMeters <= (finish - result.startedAt + 10) * 12 + 20 else {
        throw Abort(.unprocessableEntity, reason: "Invalid timestamps or implausible distance")
    }
    let collected = Set(result.collectedPelletIDs)
    try validateRules(result, route: route, finish: finish, allCollected: collected.count == route.pellets.count)
    return route.pellets.filter { collected.contains($0.id) }.reduce(0) { $0 + $1.value }
}
