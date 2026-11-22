import Foundation
import CoreLocation

struct ModeProgress: Codable, Equatable {
    enum Outcome: String, Codable {
        case completed, timedOut, caught, stopped
        var title: String {
            switch self {
            case .completed: "PARCOURS COMPLETE!"
            case .timedOut: "TIME'S UP"
            case .caught: "GHOSTS CAUGHT YOU"
            case .stopped: "WALK SAVED"
            }
        }
    }
    var activeElapsed: Double = 0
    var timeLimitSeconds: Double?
    var livesRemaining = 3
    var collisionCooldownUntil: Double = 10
    var ghosts: [GhostState] = []
    var outcome: Outcome?

    init(route: GameRoute, mode: ParcoursMode) {
        timeLimitSeconds = mode.isTimed ? max(60, route.parcours.map { Double($0.estimatedMinutes) * 60 } ?? route.distanceMeters / 1.2) : nil
        if mode.hasGhosts { ghosts = GhostChase.spawn(on: route) }
    }

    var remainingSeconds: Int? { timeLimitSeconds.map { max(0, Int(ceil($0 - activeElapsed))) } }

    mutating func advance(by seconds: Double, route: GameRoute, player: RouteCoordinate?) {
        guard outcome == nil, seconds.isFinite, seconds > 0, seconds <= 60 else { return }
        let before = activeElapsed
        let elapsed = min(seconds, max(0, (timeLimitSeconds ?? .infinity) - before))
        if let player, !ghosts.isEmpty {
            // Substeps keep movement on paths and prevent a delayed tick skipping collisions.
            var left = elapsed
            var collisionTime = before
            while left > 0, outcome == nil {
                let step = min(0.5, left)
                collisionTime += step
                activeElapsed = collisionTime
                GhostChase.advance(&ghosts, on: route, toward: player, seconds: step)
                if collisionTime >= collisionCooldownUntil,
                   ghosts.contains(where: { $0.coordinate.location.distance(from: player.location) <= 8 }) {
                    livesRemaining = max(0, livesRemaining - 1)
                    collisionCooldownUntil = collisionTime + 8
                    if livesRemaining == 0 { outcome = .caught }
                }
                left -= step
            }
        }
        if ghosts.isEmpty || player == nil { activeElapsed += elapsed }
        if outcome == nil, let limit = timeLimitSeconds, activeElapsed >= limit { outcome = .timedOut }
    }
}
