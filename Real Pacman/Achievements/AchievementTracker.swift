import Foundation

/// Saved real results are the durable source of truth, including pre-achievement history.
/// Demos never enter this archive. Syncing a result cannot award it a second time.
enum AchievementTracker {
    static let quickClearSeconds: TimeInterval = 30 * 60
    static let doubleFeatureSeconds: TimeInterval = 90 * 60

    static func progress(results: [GameSession]) -> [AchievementProgress] {
        var seen = Set<UUID>()
        let saved = results.filter { result in
            guard let finish = result.finishedAt else { return false }
            let duration = finish.timeIntervalSince(result.startedAt)
            return duration.isFinite && duration >= 0
        }.sorted {
            if $0.finishedAt != $1.finishedAt { return $0.finishedAt! < $1.finishedAt! }
            return $0.id.uuidString < $1.id.uuidString
        }.filter { seen.insert($0.id).inserted }
        let clears = saved.filter { isComplete($0) }
        var dates: [Achievement: Date] = [:]
        var counts: [Achievement: Int] = [:]

        counts[.firstOuting] = saved.count
        dates[.firstOuting] = saved.first?.finishedAt
        counts[.cleanSweep] = clears.count
        dates[.cleanSweep] = clears.first?.finishedAt
        counts[.encore] = clears.count
        if clears.count >= 3 { dates[.encore] = clears[2].finishedAt }

        var pellets = 0
        for result in saved {
            pellets += Set(result.route.pellets.map(\.id)).intersection(result.collectedPelletIDs).count
            if pellets >= Achievement.pocketful.target, dates[.pocketful] == nil {
                dates[.pocketful] = result.finishedAt
            }
        }
        counts[.pocketful] = pellets

        for clear in clears {
            let duration = clear.finishedAt!.timeIntervalSince(clear.startedAt)
            if duration <= quickClearSeconds, dates[.quickClear] == nil {
                dates[.quickClear] = clear.finishedAt
            }
            if duration <= doubleFeatureSeconds { counts[.doubleFeature] = max(1, counts[.doubleFeature, default: 0]) }
            if dates[.doubleFeature] == nil, clears.contains(where: { earlier in
                earlier.id != clear.id && earlier.finishedAt! <= clear.startedAt &&
                clear.finishedAt!.timeIntervalSince(earlier.startedAt) <= doubleFeatureSeconds
            }) {
                dates[.doubleFeature] = clear.finishedAt
                counts[.doubleFeature] = 2
            }
            if clear.mode?.hasGhosts == true, let rules = clear.rules,
               !rules.ghosts.isEmpty, rules.livesRemaining == 3,
               dates[.untouchable] == nil {
                dates[.untouchable] = clear.finishedAt
            }
            if clear.mode?.isTimed == true, let rules = clear.rules,
               let limit = rules.timeLimitSeconds, limit.isFinite, limit > 0,
               rules.activeElapsed.isFinite, rules.activeElapsed >= 0, rules.activeElapsed < limit,
               dates[.beatTheClock] == nil {
                dates[.beatTheClock] = clear.finishedAt
            }
        }
        return Achievement.allCases.map { achievement in
            AchievementProgress(achievement: achievement,
                current: min(achievement.target, counts[achievement] ?? (dates[achievement] == nil ? 0 : 1)),
                unlockedAt: dates[achievement])
        }
    }

    private static func isComplete(_ session: GameSession) -> Bool {
        let pellets = Set(session.route.pellets.map(\.id))
        return !pellets.isEmpty && pellets.isSubset(of: session.collectedPelletIDs) &&
            (session.rules?.outcome == nil || session.rules?.outcome == .completed)
    }
}
