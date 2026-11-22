import Foundation

enum DemoDirection: Double, CaseIterable {
    case north = 0
    case east = 90
    case south = 180
    case west = 270

    var symbol: String {
        switch self {
        case .north: "arrow.up"
        case .east: "arrow.right"
        case .south: "arrow.down"
        case .west: "arrow.left"
        }
    }

    var label: String {
        switch self {
        case .north: "Move north"
        case .east: "Move east"
        case .south: "Move south"
        case .west: "Move west"
        }
    }
}
