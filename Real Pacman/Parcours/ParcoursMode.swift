import Foundation

enum ParcoursMode: String, Codable, CaseIterable, Identifiable {
    case explore, timed, ghosts, timedGhosts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .explore: "Explore"
        case .timed: "Timed"
        case .ghosts: "Ghosts"
        case .timedGhosts: "Timed + ghosts"
        }
    }
    var symbol: String {
        switch self {
        case .explore: "figure.walk"
        case .timed: "timer"
        case .ghosts: "eye.fill"
        case .timedGhosts: "bolt.fill"
        }
    }
}
