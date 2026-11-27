import Vapor

/// Portable counterpart of the game's GameRoute/ParcoursDefinition validation.
/// No CoreLocation dependency: the production backend also runs on Linux.
func validatePublishedMap(_ route: RoutePayload) throws {
    func require(_ valid: Bool, _ reason: String) throws {
        guard valid else { throw Abort(.unprocessableEntity, reason: reason) }
    }
    try require(!route.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && route.name.utf8.count <= 300,
                "Give the map a name of at most 300 UTF-8 bytes.")
    try require(route.version > 0 && route.version <= 1_000_000, "Map version must be between 1 and 1,000,000.")
    try require(route.coordinates.count >= 2 && route.coordinates.count <= 200_000, "A map needs at least two route coordinates.")
    try require((1...10_000).contains(route.pellets.count), "A map needs 1–10,000 pellets.")
    try require(Set(route.pellets.map(\.id)).count == route.pellets.count, "Pellet IDs must be unique.")
    try require(route.coordinates.allSatisfy(\.isValid) && route.pellets.allSatisfy { $0.coordinate.isValid }, "Invalid map coordinates.")
    try require(route.pellets.allSatisfy { (1...1000).contains($0.value) }, "Pellet values must be between 1 and 1,000.")
    let style = URLComponents(string: route.mapStyleURL)
    try require(style?.scheme == "https" && !(style?.host?.isEmpty ?? true)
                && style?.user == nil && style?.password == nil, "The street-map style must use an HTTPS URL without credentials.")
    guard let graph = route.parcours else { return } // Legacy linear maps remain supported.
    let network: PublishingGraph
    do { network = try JSONDecoder().decode(PublishingGraph.self, from: JSONEncoder().encode(graph)) }
    catch { throw Abort(.unprocessableEntity, reason: "Invalid parcours graph or missing required map metadata.") }
    try require(network.boundary.count >= 3 && network.boundary.count <= 10_000
        && network.boundary.allSatisfy(\.isValid), "The boundary needs at least three valid points.")
    let distinct = Set(network.boundary.map { "\($0.latitude):\($0.longitude)" })
    try require(distinct.count >= 3, "The boundary needs three distinct points.")
    try require(!network.junctions.isEmpty && network.junctions.count <= 80_000
        && !network.paths.isEmpty && network.paths.count <= 40_000, "The walking path network is empty or too large.")
    try require(network.paths.reduce(0, { $0 + $1.coordinates.count }) <= 200_000, "The path network has too many coordinates.")
    try require(Set(network.junctions.map(\.id)).count == network.junctions.count, "Junction IDs must be unique.")
    try require(Set(network.paths.map(\.id)).count == network.paths.count, "Path IDs must be unique.")
    let modes: Set<String> = ["explore", "timed", "ghosts", "timedGhosts"]
    try require(!network.supportedModes.isEmpty && Set(network.supportedModes).count == network.supportedModes.count
        && Set(network.supportedModes).isSubset(of: modes), "Choose valid supported game modes.")
    try require(network.estimatedMinutes > 0, "Estimated duration must be positive.")
    let nodes = Dictionary(uniqueKeysWithValues: network.junctions.map { ($0.id, $0.coordinate) })
    try require(nodes[network.startJunctionID] != nil, "The starting junction is missing.")
    try require(network.junctions.allSatisfy { $0.coordinate.isValid && network.contains($0.coordinate) }, "A junction is outside the boundary.")
    var adjacent: [String: Set<String>] = [:]
    for path in network.paths {
        guard let a = nodes[path.from], let b = nodes[path.to], let first = path.coordinates.first,
              let last = path.coordinates.last else { throw Abort(.unprocessableEntity, reason: "A path references a missing junction.") }
        try require(path.from != path.to && path.coordinates.count >= 2
            && path.coordinates.allSatisfy { $0.isValid && network.contains($0) }, "Invalid path geometry or a path outside the boundary.")
        try require(first.distance(to: a) < 1 && last.distance(to: b) < 1
            && zip(path.coordinates, path.coordinates.dropFirst()).contains { $0.distance(to: $1) > 0 }, "Path endpoints must match their junctions.")
        adjacent[path.from, default: []].insert(path.to); adjacent[path.to, default: []].insert(path.from)
    }
    var seen: Set<String> = [network.startJunctionID], queue = [network.startJunctionID]
    while let node = queue.popLast() {
        for next in adjacent[node, default: []] where seen.insert(next).inserted { queue.append(next) }
    }
    try require(seen.count == network.junctions.count, "Every path must be reachable from the start.")
    for pellet in route.pellets {
        try require(network.contains(pellet.coordinate), "A pellet is outside the playable boundary.")
        let onPath = network.paths.contains { path in
            zip(path.coordinates, path.coordinates.dropFirst()).contains { pellet.coordinate.distanceToSegment($0, $1) <= 2 }
        }
        try require(onPath, "Pellets must be within 2 metres of a playable path.")
    }
}

private struct PublishingGraph: Decodable {
    let description: String
    let boundary: [Coordinate]
    let startJunctionID: String
    let junctions: [PublishingJunction]
    let paths: [PublishingPath]
    let supportedModes: [String]
    let estimatedMinutes: Int
    let fieldVerified: Bool
    let sourceURL: URL
    let sourceDate: String

    func contains(_ point: Coordinate) -> Bool {
        var inside = false
        for (a, b) in zip(boundary, boundary.dropFirst() + [boundary[0]]) {
            if point.distanceToSegment(a, b) < 0.5 { return true }
            if (a.latitude > point.latitude) != (b.latitude > point.latitude) {
                let longitude = (b.longitude - a.longitude) * (point.latitude - a.latitude)
                    / (b.latitude - a.latitude) + a.longitude
                if point.longitude < longitude { inside.toggle() }
            }
        }
        return inside
    }
}

private struct PublishingJunction: Decodable { let id: String; let coordinate: Coordinate }
private struct PublishingPath: Decodable {
    let id: String
    let from: String
    let to: String
    let coordinates: [Coordinate]
    let osmWayID: String?
}

private extension Coordinate {
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    func distance(to other: Coordinate) -> Double {
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let a = pow(sin((lat2 - lat1) / 2), 2) + cos(lat1) * cos(lat2) * pow(sin((other.longitude - longitude) * .pi / 360), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, a)), sqrt(max(0, 1 - a)))
    }
    func distanceToSegment(_ a: Coordinate, _ b: Coordinate) -> Double {
        let sx = cos(latitude * .pi / 180) * 111_320
        let ax = (a.longitude - longitude) * sx, ay = (a.latitude - latitude) * 111_320
        let bx = (b.longitude - longitude) * sx, by = (b.latitude - latitude) * 111_320
        let dx = bx - ax, dy = by - ay, length = dx * dx + dy * dy
        let t = length == 0 ? 0 : min(1, max(0, -(ax * dx + ay * dy) / length))
        return hypot(ax + t * dx, ay + t * dy)
    }
}
