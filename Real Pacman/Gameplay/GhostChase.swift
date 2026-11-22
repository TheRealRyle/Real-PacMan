import Foundation
import CoreLocation

/// Virtual ghosts walk along the published graph; they never cut across unmapped ground.
enum GhostChase {
    static let speedMetersPerSecond = 0.9

    static func spawn(on route: GameRoute) -> [GhostState] {
        guard let graph = route.parcours, let start = graph.start else { return [] }
        // Sample legal paths near the start rather than hiding every ghost at the
        // far end of the park. Stay outside the collection/collision radius.
        var candidates: [GhostState] = []
        for path in graph.paths {
            let length = path.lengthMeters
            let count = max(1, Int(ceil(length / 10)))
            for sample in 0...count {
                let offset = length * Double(sample) / Double(count)
                let coordinate = point(on: path.coordinates, distance: offset)
                candidates.append(GhostState(id: 0, pathID: path.id, distanceAlongPath: offset,
                                             isReversed: false, coordinate: coordinate))
            }
        }
        let nearby = candidates.filter { $0.coordinate.location.distance(from: start.location) >= 24 }
        // Tiny routes still get a ghost; the initial collision grace period applies.
        if nearby.isEmpty {
            return candidates.max(by: {
                $0.coordinate.location.distance(from: start.location) < $1.coordinate.location.distance(from: start.location)
            }).map { [$0] } ?? []
        }
        var result: [GhostState] = []
        for desiredDistance in [40.0, 55.0, 70.0] {
            let ordered = nearby.sorted {
                abs($0.coordinate.location.distance(from: start.location) - desiredDistance)
                < abs($1.coordinate.location.distance(from: start.location) - desiredDistance)
            }
            guard let candidate = ordered.first(where: { candidate in
                result.allSatisfy { $0.coordinate.location.distance(from: candidate.coordinate.location) >= 18 }
            }) else { continue }
            result.append(GhostState(id: result.count, pathID: candidate.pathID,
                                     distanceAlongPath: candidate.distanceAlongPath,
                                     isReversed: candidate.isReversed, coordinate: candidate.coordinate))
        }
        return result
    }

    static func advance(_ ghosts: inout [GhostState], on route: GameRoute, toward player: RouteCoordinate, seconds: Double) {
        guard let graph = route.parcours, let target = target(on: graph.paths, player: player),
              let targetPath = graph.paths.first(where: { $0.id == target.pathID }) else { return }
        // Dijkstra from the target supplies the next legal edge for every chasing ghost.
        var distances: [String: Double] = [targetPath.from: target.offset, targetPath.to: targetPath.lengthMeters - target.offset]
        var unsettled = Set(graph.junctions.map(\.id))
        while let node = unsettled.min(by: { distances[$0, default: .infinity] < distances[$1, default: .infinity] }),
              let distance = distances[node] {
            unsettled.remove(node)
            for path in graph.paths where path.from == node || path.to == node {
                let other = path.from == node ? path.to : path.from
                let candidate = distance + path.lengthMeters
                if candidate < distances[other, default: .infinity] { distances[other] = candidate }
            }
        }
        let paths = Dictionary(uniqueKeysWithValues: graph.paths.map { ($0.id, $0) })
        for index in ghosts.indices {
            var budget = max(0, seconds) * speedMetersPerSecond
            var crossings = 0
            while budget > 0, crossings < graph.paths.count + 1,
                  let path = paths[ghosts[index].pathID] {
                if ghosts[index].pathID == target.pathID {
                    let targetDistance = ghosts[index].isReversed ? path.lengthMeters - target.offset : target.offset
                    if targetDistance < ghosts[index].distanceAlongPath {
                        ghosts[index].distanceAlongPath = path.lengthMeters - ghosts[index].distanceAlongPath
                        ghosts[index].isReversed.toggle()
                    }
                } else {
                    let offset = ghosts[index].isReversed ? path.lengthMeters - ghosts[index].distanceAlongPath : ghosts[index].distanceAlongPath
                    let viaFrom = offset + distances[path.from, default: .infinity]
                    let viaTo = path.lengthMeters - offset + distances[path.to, default: .infinity]
                    // Re-plan at the current position, including reversing mid-path.
                    let reverse = ghosts[index].isReversed ? viaTo + 0.01 < viaFrom : viaFrom + 0.01 < viaTo
                    if reverse {
                        ghosts[index].distanceAlongPath = path.lengthMeters - ghosts[index].distanceAlongPath
                        ghosts[index].isReversed.toggle()
                    }
                }
                if ghosts[index].distanceAlongPath == 0 {
                    let node = ghosts[index].isReversed ? path.to : path.from
                    if let next = graph.paths.filter({ $0.from == node || $0.to == node }).min(by: {
                        cost($0, from: node, target: target, distances: distances) < cost($1, from: node, target: target, distances: distances)
                    }), next.id != path.id {
                        ghosts[index].pathID = next.id
                        ghosts[index].isReversed = next.to == node
                        crossings += 1
                        continue
                    }
                }
                let stop = path.id == target.pathID ? (ghosts[index].isReversed ? path.lengthMeters - target.offset : target.offset) : path.lengthMeters
                let remaining = max(0, stop - ghosts[index].distanceAlongPath)
                let travel = min(remaining, budget)
                ghosts[index].distanceAlongPath += travel
                budget -= travel
                let coordinates = ghosts[index].isReversed ? Array(path.coordinates.reversed()) : path.coordinates
                ghosts[index].coordinate = point(on: coordinates, distance: ghosts[index].distanceAlongPath)
                if path.id == target.pathID, ghosts[index].distanceAlongPath >= stop - 0.0001 { break }
                guard ghosts[index].distanceAlongPath >= path.lengthMeters - 0.0001 else { break }
                let node = ghosts[index].isReversed ? path.from : path.to
                let options = graph.paths.filter { $0.from == node || $0.to == node }
                guard let next = options.min(by: {
                    cost($0, from: node, target: target, distances: distances)
                    < cost($1, from: node, target: target, distances: distances)
                }) else { break }
                ghosts[index].pathID = next.id
                ghosts[index].isReversed = next.to == node
                ghosts[index].distanceAlongPath = 0
                crossings += 1
            }
        }
    }

    private struct Target {
        let pathID: String
        let offset: Double
    }

    private static func cost(_ path: ParcoursPath, from node: String, target: Target, distances: [String: Double]) -> Double {
        if path.id == target.pathID { return node == path.from ? target.offset : path.lengthMeters - target.offset }
        return distances[node == path.from ? path.to : path.from, default: .infinity] + path.lengthMeters
    }

    private static func target(on paths: [ParcoursPath], player: RouteCoordinate) -> Target? {
        var nearest: Target?
        var best = Double.infinity
        let longitudeScale = cos(player.latitude * .pi / 180)
        for path in paths {
            var offset = 0.0
            for (a, b) in zip(path.coordinates, path.coordinates.dropFirst()) {
                let dx = (b.longitude - a.longitude) * longitudeScale
                let dy = b.latitude - a.latitude
                let squared = dx * dx + dy * dy
                let fraction = squared > 0 ? max(0, min(1, ((player.longitude - a.longitude) * longitudeScale * dx + (player.latitude - a.latitude) * dy) / squared)) : 0
                let projected = RouteCoordinate(latitude: a.latitude + (b.latitude - a.latitude) * fraction,
                    longitude: a.longitude + (b.longitude - a.longitude) * fraction)
                let distance = projected.location.distance(from: player.location)
                let length = a.location.distance(from: b.location)
                if distance < best { best = distance; nearest = Target(pathID: path.id, offset: offset + length * fraction) }
                offset += length
            }
        }
        return nearest
    }

    static func point(on coordinates: [RouteCoordinate], distance: Double) -> RouteCoordinate {
        guard let first = coordinates.first else { return RouteCoordinate(latitude: 0, longitude: 0) }
        var left = max(0, distance)
        for (a, b) in zip(coordinates, coordinates.dropFirst()) {
            let length = a.location.distance(from: b.location)
            if left <= length, length > 0 {
                let fraction = left / length
                return RouteCoordinate(latitude: a.latitude + (b.latitude - a.latitude) * fraction,
                                       longitude: a.longitude + (b.longitude - a.longitude) * fraction)
            }
            left -= length
        }
        return coordinates.last ?? first
    }
}
