import Foundation
import CoreGraphics
import CoreLocation

struct PelletIndicator: Equatable {
    let position: CGPoint
    let angleDegrees: Double
    let distanceMeters: Int
}

enum PelletGuidance {
    static func nearest(in route: GameRoute, collected: Set<UUID>, player: RouteCoordinate) -> Pellet? {
        route.pellets.filter { !collected.contains($0.id) }.min {
            player.location.distance(from: $0.coordinate.location) < player.location.distance(from: $1.coordinate.location)
        }
    }

    static func edgePoint(target: CGPoint, visibleRect: CGRect) -> CGPoint? {
        guard !visibleRect.contains(target), visibleRect.width > 0, visibleRect.height > 0,
              target.x.isFinite, target.y.isFinite else { return nil }
        let center = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        let dx = target.x - center.x, dy = target.y - center.y
        let horizontal = dx == 0 ? CGFloat.infinity : visibleRect.width / 2 / abs(dx)
        let vertical = dy == 0 ? CGFloat.infinity : visibleRect.height / 2 / abs(dy)
        let fraction = min(horizontal, vertical)
        return CGPoint(x: center.x + dx * fraction, y: center.y + dy * fraction)
    }
}
