import Vapor

func validateRules(_ result: ResultPayload, route: RoutePayload, finish: Double, allCollected: Bool) throws {
    let mode = result.mode ?? "explore"
    let timed = mode == "timed" || mode == "timedGhosts"
    let chasing = mode == "ghosts" || mode == "timedGhosts"
    guard let rules = result.rules else {
        guard mode == "explore" else { throw invalid("This mode requires rules metadata") }
        return // Existing Explore uploads and stored canonical retry strings remain compatible.
    }
    if mode != "explore" {
        let supported = route.parcours?.objectValue?["supportedModes"]?.arrayValue ?? []
        guard supported.contains(.string(mode)) else { throw invalid("Mode is unavailable on this route version") }
    }
    guard rules.activeElapsed.isFinite, rules.activeElapsed >= 0,
          rules.activeElapsed <= finish - result.startedAt + 10,
          (0...3).contains(rules.livesRemaining),
          rules.collisionCooldownUntil.isFinite, rules.collisionCooldownUntil >= 0 else {
        throw invalid("Invalid active duration or lives metadata")
    }
    if timed {
        guard let limit = rules.timeLimitSeconds, limit.isFinite, limit > 0 else {
            throw invalid("Timed mode requires a valid time limit")
        }
        let expected = timeLimit(for: route)
        guard abs(limit - expected) <= max(1, expected * 0.01), rules.activeElapsed <= limit + 1 else {
            throw invalid("Time limit differs from the route rules")
        }
    } else if rules.timeLimitSeconds != nil {
        throw invalid("Untimed mode cannot contain a time limit")
    }
    let pathIDs = Set((route.parcours?.objectValue?["paths"]?.arrayValue ?? []).compactMap {
        $0.objectValue?["id"]?.stringValue
    })
    guard Set(rules.ghosts.map(\.id)).count == rules.ghosts.count,
          rules.ghosts.count <= 3 else { throw invalid("Invalid ghost identities") }
    if chasing {
        guard !rules.ghosts.isEmpty else { throw invalid("Chasing mode requires a ghost") }
    } else {
        guard rules.ghosts.isEmpty, rules.livesRemaining == 3 else {
            throw invalid("This mode cannot contain ghost collisions")
        }
    }
    for ghost in rules.ghosts {
        guard chasing, (0...2).contains(ghost.id), pathIDs.contains(ghost.pathID),
              ghost.distanceAlongPath.isFinite, ghost.distanceAlongPath >= 0,
              ghost.coordinate.latitude.isFinite, ghost.coordinate.longitude.isFinite,
              (-90...90).contains(ghost.coordinate.latitude), (-180...180).contains(ghost.coordinate.longitude) else {
            throw invalid("Invalid ghost state")
        }
    }
    guard let outcome = rules.outcome else { throw invalid("Finished session requires an outcome") }
    switch outcome {
    case "completed":
        guard allCollected, rules.livesRemaining > 0,
              !timed || rules.activeElapsed < (rules.timeLimitSeconds ?? 0) else {
            throw invalid("Completed result must contain every pellet before a loss")
        }
    case "timedOut":
        guard timed, !allCollected, rules.livesRemaining > 0,
              let limit = rules.timeLimitSeconds, rules.activeElapsed >= limit else {
            throw invalid("Timeout outcome requires an expired timer")
        }
    case "caught":
        guard chasing, rules.livesRemaining == 0 else { throw invalid("Caught outcome requires zero lives") }
    case "stopped":
        guard !allCollected, rules.livesRemaining > 0,
              !timed || rules.activeElapsed < (rules.timeLimitSeconds ?? 0) else {
            throw invalid("Stopped result cannot already be won or lost")
        }
    default: throw invalid("Unknown result outcome")
    }
}

private func invalid(_ reason: String) -> Abort { Abort(.unprocessableEntity, reason: reason) }

private func timeLimit(for route: RoutePayload) -> Double {
    if let value = route.parcours?.objectValue?["estimatedMinutes"], case .number(let minutes) = value {
        return max(60, minutes * 60)
    }
    let metres = zip(route.coordinates, route.coordinates.dropFirst()).reduce(0.0) { total, segment in
        let a = segment.0, b = segment.1
        let latA = a.latitude * .pi / 180, latB = b.latitude * .pi / 180
        let dLat = latB - latA, dLon = (b.longitude - a.longitude) * .pi / 180
        let h = pow(sin(dLat / 2), 2) + cos(latA) * cos(latB) * pow(sin(dLon / 2), 2)
        return total + 6_371_000 * 2 * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
    return max(60, metres / 1.2)
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? { if case .object(let value) = self { value } else { nil } }
    var arrayValue: [JSONValue]? { if case .array(let value) = self { value } else { nil } }
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
}
