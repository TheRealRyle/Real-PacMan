import Testing
import Foundation
import CoreLocation
@testable import ParcoursCore

struct AchievementTests {
    private let origin = Date(timeIntervalSinceReferenceDate: 100_000)

    private func run(start: Double = 0, duration: Double = 900, mode: ParcoursMode = .explore,
                     lives: Int = 3, count: Int? = nil) throws -> GameSession {
        let route = try ParcoursCatalogue.loadVerney(bundle: .module)
        var result = GameSession(id: UUID(), route: route, startedAt: origin.addingTimeInterval(start))
        result.mode = mode
        result.collectedPelletIDs = Set(route.pellets.prefix(count ?? route.pellets.count).map(\.id))
        result.rules = ModeProgress(route: route, mode: mode)
        result.rules?.activeElapsed = duration
        result.rules?.livesRemaining = lives
        result.rules?.outcome = count == nil ? .completed : .stopped
        result.finishedAt = result.startedAt.addingTimeInterval(duration)
        return result
    }

    private func progress(_ achievement: Achievement, in results: [GameSession]) throws -> AchievementProgress {
        try #require(AchievementTracker.progress(results: results).first { $0.achievement == achievement })
    }

    @Test("A new player sees eight locked, achievable milestones")
    func empty() {
        let items = AchievementTracker.progress(results: [])
        #expect(items.count == 8)
        #expect(items.allSatisfy { !$0.isUnlocked && $0.current == 0 })
    }

    @Test("All eight achievements can be earned by replaying the currently bundled parcours")
    func allEight() throws {
        let first = try run(duration: 1_200)
        let second = try run(start: 1_500, duration: 1_200, mode: .ghosts)
        let third = try run(start: 3_000, duration: 1_200, mode: .timed)
        let items = AchievementTracker.progress(results: [third, second, first, first])
        #expect(items.allSatisfy { $0.isUnlocked })
        #expect(try progress(.encore, in: [first, second]).current == 2)
        #expect(try progress(.encore, in: [first, second, third]).unlockedAt == third.finishedAt)
        #expect(try progress(.pocketful, in: [first, second, third]).unlockedAt == second.finishedAt)
        #expect(try progress(.doubleFeature, in: [first, second, third]).unlockedAt == second.finishedAt)
        #expect(items == AchievementTracker.progress(results: [first, second, third]))
    }

    @Test("Partial runs count actual pellets, but not full clears or duplicate saves")
    func partialRuns() throws {
        var partial = try run(count: 8)
        partial.collectedPelletIDs.insert(UUID())
        let result = [partial, partial]
        #expect(try progress(.firstOuting, in: result).isUnlocked)
        #expect(try progress(.pocketful, in: result).current == 8)
        #expect(try !progress(.cleanSweep, in: result).isUnlocked)
        #expect(try !progress(.quickClear, in: result).isUnlocked)
        #expect(try !progress(.doubleFeature, in: result).isUnlocked)
    }

    @Test("Quick Clear includes pauses and accepts exactly 30 minutes", arguments: [1_799.0, 1_800, 1_801])
    func quickBoundary(duration: Double) throws {
        var result = try run(duration: duration)
        // Active play alone must not hide a long pause.
        result.rules?.activeElapsed = 10
        #expect(try progress(.quickClear, in: [result]).isUnlocked == (duration <= 1_800))
    }

    @Test("Double Feature includes both runs and their break", arguments: [-1.0, 0, 1])
    func doubleBoundary(delta: Double) throws {
        let first = try run(duration: 1_200)
        let second = try run(start: 1_800, duration: 3_600 + delta)
        #expect(try progress(.doubleFeature, in: [first, second]).isUnlocked == (delta <= 0))
    }

    @Test("Overlapping or duplicate results cannot fake two completed runs")
    func doubleOverlap() throws {
        let first = try run(duration: 1_200)
        let overlapping = try run(start: 600, duration: 1_200)
        #expect(try !progress(.doubleFeature, in: [first, first]).isUnlocked)
        #expect(try !progress(.doubleFeature, in: [first, overlapping]).isUnlocked)
    }

    @Test("Untouchable requires a full ghost-mode clear with three hearts",
          arguments: [ParcoursMode.explore, .ghosts, .timedGhosts], [2, 3])
    func perfectGhosts(mode: ParcoursMode, lives: Int) throws {
        let result = try run(mode: mode, lives: lives)
        #expect(try progress(.untouchable, in: [result]).isUnlocked == (mode.hasGhosts && lives == 3))
        var caught = result
        caught.rules?.outcome = .caught
        #expect(try !progress(.untouchable, in: [caught]).isUnlocked)
    }

    @Test("Beat the Clock requires real remaining time", arguments: [1_559.0, 1_560, 1_561, .nan, .infinity])
    func timedBoundary(active: Double) throws {
        var result = try run(mode: .timed)
        result.rules?.activeElapsed = active
        result.rules?.timeLimitSeconds = 1_560
        #expect(try progress(.beatTheClock, in: [result]).isUnlocked == (active.isFinite && active < 1_560))
    }

    @Test("Unfinished and failed runs do not award completion achievements")
    func invalidCompletion() throws {
        var unfinished = try run()
        unfinished.finishedAt = nil
        #expect(AchievementTracker.progress(results: [unfinished]).allSatisfy { !$0.isUnlocked })
        var timedOut = try run(mode: .timed)
        timedOut.rules?.outcome = .timedOut
        #expect(try !progress(.cleanSweep, in: [timedOut]).isUnlocked)
        #expect(try !progress(.beatTheClock, in: [timedOut]).isUnlocked)
    }

    @Test("Legacy saved clears backfill generic achievements without inventing ghost wins")
    @MainActor func legacyBackfill() throws {
        var legacy = try run()
        legacy.rules = nil
        legacy.mode = nil
        let file = URL.temporaryDirectory.appending(path: UUID().uuidString + ".json")
        var archive = GameArchive()
        archive.results = [legacy]
        try JSONEncoder().encode(archive).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let restored = GameStore(fileURL: file)
        #expect(restored.achievements.filter(\.isUnlocked).map(\.achievement) == [.firstOuting, .cleanSweep, .quickClear])
        #expect(restored.latestUnlockedAchievements.isEmpty)
    }

    @Test("Actual GPS completion awards once and earned badges survive relaunch")
    @MainActor func storeIntegration() throws {
        let coordinate = RouteCoordinate(latitude: 45, longitude: 5)
        let route = GameRoute(id: UUID(), name: "Achievement walk", version: 1,
            coordinates: [coordinate, RouteCoordinate(latitude: 45.001, longitude: 5)],
            pellets: [Pellet(id: UUID(), coordinate: coordinate)],
            mapStyleURL: URL(string: "https://example.com/style.json")!)
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let file = folder.appending(path: "progress.json")
        defer { try? FileManager.default.removeItem(at: folder) }
        let game = GameStore(fileURL: file)
        let demo = DemoSession(route: route)
        #expect(demo.isComplete)
        #expect(game.achievements.allSatisfy { !$0.isUnlocked })
        game.start(route)
        game.collect(at: CLLocation(coordinate: coordinate.coordinate, altitude: 0,
            horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date()))
        #expect(game.archive.activeSession == nil)
        #expect(game.latestUnlockedAchievements == [.firstOuting, .cleanSweep, .quickClear])
        game.finish()
        #expect(game.archive.results.count == 1)
        let restored = GameStore(fileURL: file)
        #expect(restored.achievements == game.achievements)
        #expect(restored.latestUnlockedAchievements.isEmpty)
        restored.start(route)
        #expect(restored.latestUnlockedAchievements.isEmpty)
        restored.finish()
        #expect(restored.latestUnlockedAchievements.isEmpty)
    }
}
