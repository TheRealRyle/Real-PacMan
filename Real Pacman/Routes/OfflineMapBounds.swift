import Foundation

/// Bound walking-map downloads before asking the map SDK to fetch any tiles.
struct OfflineMapBounds {
    let south: Double
    let north: Double
    let west: Double
    let east: Double
    static let minimumZoom = 12
    static let maximumZoom = 17
    static let tileLimit = 3_000

    init?(route: GameRoute) {
        let points = route.mapCoordinates
        guard !points.isEmpty, points.allSatisfy(\.isValid) else { return nil }
        south = max(-85, points.map(\.latitude).min()! - 0.003)
        north = min(85, points.map(\.latitude).max()! + 0.003)
        west = max(-180, points.map(\.longitude).min()! - 0.003)
        east = min(180, points.map(\.longitude).max()! + 0.003)
        guard north > south, east > west, north - south < 0.25, east - west < 0.25,
              estimatedTileCount <= Self.tileLimit else { return nil }
    }

    var estimatedTileCount: Int {
        (Self.minimumZoom...Self.maximumZoom).reduce(0) { count, zoom in
            let side = pow(2, Double(zoom))
            func x(_ longitude: Double) -> Int { Int(floor((longitude + 180) / 360 * side)) }
            func y(_ latitude: Double) -> Int {
                let radians = latitude * .pi / 180
                return Int(floor((1 - asinh(tan(radians)) / .pi) / 2 * side))
            }
            return count + (x(east) - x(west) + 1) * (y(south) - y(north) + 1)
        }
    }
}
