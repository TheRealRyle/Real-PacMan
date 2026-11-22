import Foundation

enum ParcoursMode: String, Codable, CaseIterable, Identifiable {
    case explore, timed, ghosts, timedGhosts
    var isTimed: Bool { self == .timed || self == .timedGhosts }
    var hasGhosts: Bool { self == .ghosts || self == .timedGhosts }
    var instructions: String {
        switch self {
        case .explore: "Collect every pellet in any order. No timer."
        case .timed: "Collect pellets before the active-play timer expires. Pausing stops the clock."
        case .ghosts: "Avoid virtual ghosts on mapped paths. Three lives, with a grace period after each hit. Walk safely; never run into traffic."
        case .timedGhosts: "Beat the clock while avoiding virtual ghosts. Three lives. Stay on safe public paths; never run into traffic."
        }
    }
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
