import Testing
import VaporTesting
import Fluent
@testable import App

private func modeResult(route: RoutePayload, mode: String, outcome: String = "stopped",
                        elapsed: Double = 30, lives: Int = 3, limit: Double? = nil,
                        ghosts: [GhostPayload] = [], pellets: [UUID] = []) -> ResultPayload {
    let now = Date().timeIntervalSinceReferenceDate
    var states = ghosts
    if states.isEmpty, mode == "ghosts" || mode == "timedGhosts",
       let graph = route.parcours, case .object(let object) = graph,
       let pathsValue = object["paths"], case .array(let paths) = pathsValue,
       let first = paths.first, case .object(let path) = first,
       let idValue = path["id"], case .string(let pathID) = idValue {
        states = [GhostPayload(id: 0, pathID: pathID, distanceAlongPath: 0, isReversed: false,
                               coordinate: route.coordinates[0])]
    }
    return ResultPayload(id: UUID(), route: route, startedAt: now - 2400, finishedAt: now,
                         collectedPelletIDs: pellets, distanceMeters: 10, mode: mode, syncedAt: nil,
                         rules: ResultRules(activeElapsed: elapsed, timeLimitSeconds: limit,
                             livesRemaining: lives, collisionCooldownUntil: 10, ghosts: states, outcome: outcome))
}

private func upload(_ result: ResultPayload, to app: Application, expecting status: HTTPStatus = .ok) async throws {
    try await app.testing().test(.POST, "/api/v1/results", beforeRequest: { request in
        request.headers.add(name: "Idempotency-Key", value: result.id.uuidString)
        try request.content.encode(result)
    }, afterResponse: { response async in #expect(response.status == status) })
}

@Suite("Mode results and version upgrade")
struct ModeResultTests {
    @Test("All four modes accept valid stopped sessions", arguments: [
        ("explore", Optional<Double>.none), ("timed", 1560), ("ghosts", nil), ("timedGhosts", 1560)
    ])
    func acceptedModes(mode: String, limit: Double?) async throws {
        try await withServer { app in
            let route = try await fixture(app)
            try await upload(modeResult(route: route, mode: mode, limit: limit), to: app)
        }
    }

    @Test("Expired timer and lost lives outcomes are accepted")
    func terminalOutcomes() async throws {
        try await withServer { app in
            let route = try await fixture(app)
            try await upload(modeResult(route: route, mode: "timed", outcome: "timedOut", elapsed: 1560, limit: 1560), to: app)
            try await upload(modeResult(route: route, mode: "ghosts", outcome: "caught", lives: 0), to: app)
            try await upload(modeResult(route: route, mode: "timedGhosts", outcome: "caught", lives: 0, limit: 1560), to: app)
            try await upload(modeResult(route: route, mode: "timed", outcome: "completed", limit: 1560,
                                        pellets: route.pellets.map(\.id)), to: app)
        }
    }

    @Test("Legacy Explore retries preserve the pre-upgrade canonical JSON shape")
    func legacyCanonicalShape() async throws {
        try await withServer { app in
            let route = try await fixture(app, version: 1)
            let now = Date().timeIntervalSinceReferenceDate
            let legacy = ResultPayload(id: UUID(), route: route, startedAt: now - 60, finishedAt: now,
                                       collectedPelletIDs: [], distanceMeters: 0, mode: nil, syncedAt: nil)
            let object = try #require(JSONSerialization.jsonObject(with: Data(try legacy.canonicalJSON().utf8)) as? [String: Any])
            #expect(object["rules"] == nil)
            #expect(object["mode"] as? String == "explore")
            try await upload(legacy, to: app)
            try await upload(legacy, to: app)
            #expect(try await StoredResult.query(on: app.db).count() == 1)
        }
    }

    @Test("Unsupported old capabilities and inconsistent outcomes are rejected", arguments: [
        "oldVersionTimed", "missingRules", "earlyTimeout", "incompleteSuccess", "caughtWithLives",
        "wrongTimeLimit", "negativeElapsed", "excessElapsed", "tooManyLives", "unknownGhostPath",
        "missingGhosts", "untimedLostLife", "stoppedExpired", "completedCaught", "timeoutAlreadyCollected"
    ])
    func invalidModes(kind: String) async throws {
        try await withServer { app in
            let route = try await fixture(app, version: kind == "oldVersionTimed" ? 1 : 2)
            var payload = modeResult(route: route, mode: "timed", limit: 1560)
            switch kind {
            case "missingRules": payload.rules = nil
            case "earlyTimeout": payload = modeResult(route: route, mode: "timed", outcome: "timedOut", limit: 1560)
            case "incompleteSuccess": payload = modeResult(route: route, mode: "timed", outcome: "completed", limit: 1560)
            case "caughtWithLives": payload = modeResult(route: route, mode: "ghosts", outcome: "caught")
            case "wrongTimeLimit": payload = modeResult(route: route, mode: "timed", limit: 60)
            case "negativeElapsed": payload = modeResult(route: route, mode: "timed", elapsed: -1, limit: 1560)
            case "excessElapsed": payload = modeResult(route: route, mode: "explore", elapsed: 10_000)
            case "tooManyLives": payload = modeResult(route: route, mode: "ghosts", lives: 4)
            case "missingGhosts":
                payload = modeResult(route: route, mode: "ghosts")
                payload.rules = ResultRules(activeElapsed: 30, timeLimitSeconds: nil, livesRemaining: 3,
                                            collisionCooldownUntil: 10, ghosts: [], outcome: "stopped")
            case "untimedLostLife": payload = modeResult(route: route, mode: "explore", lives: 2)
            case "stoppedExpired": payload = modeResult(route: route, mode: "timed", elapsed: 1560, limit: 1560)
            case "completedCaught":
                payload = modeResult(route: route, mode: "ghosts", outcome: "completed", lives: 0,
                                     pellets: route.pellets.map(\.id))
            case "timeoutAlreadyCollected":
                payload = modeResult(route: route, mode: "timed", outcome: "timedOut", elapsed: 1560, limit: 1560,
                                     pellets: route.pellets.map(\.id))
            case "unknownGhostPath":
                let ghost = GhostPayload(id: 0, pathID: "missing", distanceAlongPath: 0, isReversed: false,
                                         coordinate: route.coordinates[0])
                payload = modeResult(route: route, mode: "ghosts", ghosts: [ghost])
            default: break
            }
            try await upload(payload, to: app, expecting: .unprocessableEntity)
            #expect(try await StoredResult.query(on: app.db).count() == 0)
        }
    }

    @Test("Changing rules on a retry conflicts rather than replacing a stored result")
    func changedRulesConflict() async throws {
        try await withServer { app in
            let route = try await fixture(app)
            var payload = modeResult(route: route, mode: "timed", limit: 1560)
            try await upload(payload, to: app)
            try await upload(payload, to: app)
            payload.rules = ResultRules(activeElapsed: 31, timeLimitSeconds: 1560, livesRemaining: 3,
                                        collisionCooldownUntil: 10, ghosts: [], outcome: "stopped")
            try await upload(payload, to: app, expecting: .conflict)
        }
    }
}
