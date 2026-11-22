import Foundation
import CoreLocation

/// Virtual ghosts walk along the published graph; they never cut across unmapped ground.
enum GhostChase {
    static let speedMetersPerSecond = 0.9

    static func spawn(on route: GameRoute) -> [GhostState] {
        guard let graph = route.parcours, let start = graph.start else { return [] }
        let junctions = graph.junctions.sorted {
            $0.coordinate.location.distance(from: start.location) > $1.coordinate.location.distance(from: start.location)
        }
        // Separate spawns where possible, rather than three overlapping markers.
        var chosen: [RouteCoordinate] = []
        var result: [GhostState] = []
        for node in junctions where result.count < 3 {
            guard chosen.allSatisfy({ $0.location.distance(from: node.coordinate.location) >= 35 }),
                  let path = graph.paths.first(where: { $0.from == node.id || $0.to == node.id }) else { continue }
            result.append(GhostState(id: result.count, pathID: path.id, distanceAlongPath: 0,
                                     isReversed: path.to == node.id, coordinate: node.coordinate))
            chosen.append(node.coordinate)
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
