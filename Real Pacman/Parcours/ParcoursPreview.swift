import SwiftUI

/// Bundled vector preview, available with no tile cache or network connection.
struct ParcoursPreview: View {
    let route: GameRoute
    var collected: Set<UUID> = []
    var player: RouteCoordinate?
    var height: CGFloat? = 180
    var ghosts: [GhostState] = []
    var playerBearing = 90.0

    var body: some View {
        Canvas { context, size in
            let points = route.mapCoordinates
            guard let first = points.first else { return }
            let minLat = points.map(\.latitude).min() ?? first.latitude
            let maxLat = points.map(\.latitude).max() ?? first.latitude
            let minLon = points.map(\.longitude).min() ?? first.longitude
            let maxLon = points.map(\.longitude).max() ?? first.longitude
            let aspect = cos(first.latitude * .pi / 180)
            let width = max((maxLon - minLon) * aspect, 0.00001)
            let height = max(maxLat - minLat, 0.00001)
            let scale = min((size.width - 32) / width, (size.height - 32) / height)
            func project(_ point: RouteCoordinate) -> CGPoint {
                CGPoint(x: (size.width - width * scale) / 2 + (point.longitude - minLon) * aspect * scale,
                        y: (size.height - height * scale) / 2 + (maxLat - point.latitude) * scale)
            }
            if let boundary = route.parcours?.boundary {
                let polygon = Path { path in
                    path.addLines(boundary.map(project))
                    path.closeSubpath()
                }
                context.fill(polygon, with: .color(.green.opacity(0.15)))
                context.stroke(polygon, with: .color(.green.opacity(0.5)), lineWidth: 2)
            }
            for line in route.pathLines {
                let path = Path { $0.addLines(line.map(project)) }
                context.stroke(path, with: .color(.cyan), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            for pellet in route.pellets where !collected.contains(pellet.id) {
                let center = project(pellet.coordinate)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)),
                             with: .color(.yellow))
            }
            if let start = route.parcours?.start {
                let center = project(start)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)),
                             with: .color(.white))
            }
            for ghost in ghosts {
                let center = project(ghost.coordinate)
                let dot = Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))
                context.fill(dot, with: .color(.pink))
                context.stroke(dot, with: .color(.white), lineWidth: 2)
            }
            if let player {
                let center = project(player)
                var marker = context
                marker.translateBy(x: center.x, y: center.y)
                marker.rotate(by: .degrees(playerBearing - 90))
                marker.draw(Image("PlayerMarker").renderingMode(.original), in: CGRect(x: -16, y: -16, width: 32, height: 32))
            }
        }
        .frame(height: height)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel(player == nil
            ? "Parcours preview: paths in blue, pellets in yellow, proposed start in white."
            : "Parcours map: your player is the large yellow character, paths in blue, pellets are small yellow dots.")
    }
}
