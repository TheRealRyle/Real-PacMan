import Foundation

enum Achievement: String, CaseIterable, Identifiable {
    case firstOuting, cleanSweep, encore, pocketful, quickClear, doubleFeature, untouchable, beatTheClock

    var id: String { rawValue }
    var title: String {
        switch self {
        case .firstOuting: "First Outing"
        case .cleanSweep: "Clean Sweep"
        case .encore: "Encore!"
        case .pocketful: "Pocketful of Pellets"
        case .quickClear: "Quick Clear"
        case .doubleFeature: "Double Feature"
        case .untouchable: "Untouchable"
        case .beatTheClock: "Beat the Clock"
        }
    }
    var requirement: String {
        switch self {
        case .firstOuting: "Save your first real parcours run."
        case .cleanSweep: "Collect every pellet and complete one parcours."
        case .encore: "Complete three parcours runs. Replays count!"
        case .pocketful: "Collect 50 pellets across saved runs. Partial runs count too."
        case .quickClear: "Complete a parcours within 30 minutes, from start to finish."
        case .doubleFeature: "Complete two runs within 90 minutes, from the first start to the second finish. Replays count."
        case .untouchable: "Complete Ghosts or Timed + Ghosts with all three hearts remaining."
        case .beatTheClock: "Complete Timed or Timed + Ghosts with time left."
        }
    }
    var symbol: String {
        switch self {
        case .firstOuting: "shoeprints.fill"
        case .cleanSweep: "flag.checkered"
        case .encore: "arrow.clockwise.circle.fill"
        case .pocketful: "circle.grid.3x3.fill"
        case .quickClear: "stopwatch.fill"
        case .doubleFeature: "2.circle.fill"
        case .untouchable: "heart.shield.fill"
        case .beatTheClock: "timer"
        }
    }
    var target: Int {
        switch self {
        case .encore: 3
        case .pocketful: 50
        case .doubleFeature: 2
        default: 1
        }
    }
    var progressUnit: String {
        switch self {
        case .firstOuting: "runs saved"
        case .pocketful: "pellets collected"
        default: "qualifying clears"
        }
    }
}

struct AchievementProgress: Identifiable, Equatable {
    let achievement: Achievement
    let current: Int
    let unlockedAt: Date?
    var id: Achievement { achievement }
    var isUnlocked: Bool { unlockedAt != nil }
    var fraction: Double { min(1, Double(current) / Double(achievement.target)) }
}
