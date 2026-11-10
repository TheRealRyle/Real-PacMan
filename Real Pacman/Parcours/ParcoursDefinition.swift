import Foundation
import CoreLocation

struct ParcoursDefinition: Codable, Equatable {
    let description: String
    /// Open polygon ring (the final coordinate need not repeat the first).
    let boundary: [RouteCoordinate]
    let startJunctionID: String
    let junctions: [ParcoursJunction]
    let paths: [ParcoursPath]
    let supportedModes: [ParcoursMode]
    let estimatedMinutes: Int
    let fieldVerified: Bool
    let sourceURL: URL
    let sourceDate: String

    var start: RouteCoordinate? { junctions.first { $0.id == startJunctionID }?.coordinate }
    var distanceMeters: Double { paths.reduce(0) { $0 + $1.lengthMeters } }

    func contains(_ point: RouteCoordinate) -> Bool {
        guard boundary.count >= 3 else { return false }
        var inside = false
        for (a, b) in zip(boundary, boundary.dropFirst() + [boundary[0]]) {
            // Include points lying on the mapped boundary.
            if point.distanceToSegment(a, b) < 0.5 { return true }
            if (a.latitude > point.latitude) != (b.latitude > point.latitude) {
                let longitude = (b.longitude - a.longitude) * (point.latitude - a.latitude)
                    / (b.latitude - a.latitude) + a.longitude
                if point.longitude < longitude { inside.toggle() }
            }
        }
        return inside
    }

    func validate(pellets: [Pellet]) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw ParcoursValidationError(reason: message) }
        }
        try require(boundary.count >= 3 && boundary.allSatisfy(\.isValid), "Invalid boundary.")
        try require(Set(boundary).count >= 3, "Boundary needs three distinct points.")
        try require(!junctions.isEmpty && !paths.isEmpty, "The path network is empty.")
        try require(Set(junctions.map(\.id)).count == junctions.count, "Duplicate junction IDs.")
        try require(Set(paths.map(\.id)).count == paths.count, "Duplicate path IDs.")
        try require(!supportedModes.isEmpty && Set(supportedModes).count == supportedModes.count,
                    "Invalid supported modes.")
        try require(estimatedMinutes > 0, "Invalid duration estimate.")
        let nodes = Dictionary(uniqueKeysWithValues: junctions.map { ($0.id, $0.coordinate) })
        try require(nodes[startJunctionID] != nil, "Starting junction is missing.")
        try require(junctions.allSatisfy { $0.coordinate.isValid && contains($0.coordinate) },
                    "A junction is outside the boundary.")
        var adjacent: [String: Set<String>] = [:]
        for path in paths {
            guard let a = nodes[path.from], let b = nodes[path.to],
                  let first = path.coordinates.first, let last = path.coordinates.last else {
                throw ParcoursValidationError(reason: "A path references a missing junction.")
            }
            try require(path.from != path.to && path.coordinates.count >= 2 &&
                        path.coordinates.allSatisfy { $0.isValid && contains($0) },
                        "Invalid path geometry.")
            try require(first.location.distance(from: a.location) < 1 &&
                        last.location.distance(from: b.location) < 1 && path.lengthMeters > 0,
                        "Path endpoints must match their junctions.")
            adjacent[path.from, default: []].insert(path.to)
            adjacent[path.to, default: []].insert(path.from)
        }
        var visited: Set<String> = [startJunctionID]
        var queue = [startJunctionID]
        while let node = queue.popLast() {
            for next in adjacent[node, default: []] where visited.insert(next).inserted { queue.append(next) }
        }
        try require(visited.count == junctions.count, "Every path must be reachable from the start.")
        for pellet in pellets {
            try require(contains(pellet.coordinate), "A pellet is outside the boundary.")
            let onPath = paths.contains { path in
                zip(path.coordinates, path.coordinates.dropFirst()).contains {
                    pellet.coordinate.distanceToSegment($0.0, $0.1) <= 2
                }
            }
            try require(onPath, "Pellets must lie on the playable path network.")
        }
    }
}
