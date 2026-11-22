import Foundation
import Observation
import CoreLocation

@MainActor @Observable
final class GameStore {
    private(set) var archive = GameArchive()
    var message: String?
    private(set) var isLoading = false
    private(set) var isSyncing = false
    private(set) var isPlaying = false
    private(set) var latestFinishedSession: GameSession?
    private(set) var latestUnlockedAchievements: [Achievement] = []
    private var lastAcceptedAt: Date?
    private var lastAcceptedCoordinate: RouteCoordinate?
    private var previousLocation: CLLocation?
    private let fileURL: URL
    private var canSave = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "RealPacman/progress.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                archive = try JSONDecoder().decode(GameArchive.self, from: Data(contentsOf: self.fileURL))
            }
        } catch {
            canSave = false
            message = "Saved progress could not be read. The original file has been preserved."
        }
    }

    var pendingResults: Int { archive.results.filter { $0.syncedAt == nil }.count }
    var achievements: [AchievementProgress] { AchievementTracker.progress(results: archive.results) }

    private func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(archive).write(to: fileURL, options: .atomic)
        } catch { message = "Could not save progress: \(error.localizedDescription)" }
    }

    func start(_ route: GameRoute, mode: ParcoursMode = .explore) {
        guard archive.activeSession == nil, canSave else { return }
        do { try route.validate() }
        catch { message = error.localizedDescription; return }
        guard route.parcours?.supportedModes.contains(mode) ?? (mode == .explore),
              !mode.hasGhosts || route.parcours != nil else {
            message = "This parcours does not support that mode."; return
        }
        latestFinishedSession = nil
        latestUnlockedAchievements = []
        var session = GameSession(id: UUID(), route: route, startedAt: Date())
        session.mode = mode
        session.rules = ModeProgress(route: route, mode: mode)
        archive.activeSession = session
        lastAcceptedCoordinate = nil
        isPlaying = true
        previousLocation = nil
        save()
    }

    func resume() { isPlaying = true; previousLocation = nil }
    func pause() { isPlaying = false; previousLocation = nil; lastAcceptedCoordinate = nil; save() }

    func collect(at location: CLLocation) {
        guard isPlaying, var session = archive.activeSession,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 20,
              abs(location.timestamp.timeIntervalSinceNow) < 10 else { return }
        if let previous = previousLocation {
            let elapsed = location.timestamp.timeIntervalSince(previous.timestamp)
            guard elapsed > 0 else { return }
            let distance = location.distance(from: previous)
            guard distance / elapsed <= 12 else { return }
            if distance >= 3 { session.distanceMeters += distance; previousLocation = location }
        } else { previousLocation = location }
        lastAcceptedAt = Date()
        lastAcceptedCoordinate = RouteCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        for pellet in session.route.pellets where !session.collectedPelletIDs.contains(pellet.id) {
            if location.distance(from: pellet.coordinate.location) <= GameplayRules.collectionRadiusMeters {
                session.collectedPelletIDs.insert(pellet.id)
            }
        }
        archive.activeSession = session
        if session.collectedPelletIDs.count == session.route.pellets.count { finish() }
        else { save() }
    }

    func advance(by seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        guard isPlaying, var session = archive.activeSession,
              let mode = session.mode, mode != .explore else { return }
        var progress = session.rules ?? ModeProgress(route: session.route, mode: mode)
        let previous = progress.activeElapsed
        progress.advance(by: seconds, route: session.route,
                         player: (lastAcceptedAt.map { Date().timeIntervalSince($0) <= 10 } == true) ? lastAcceptedCoordinate : nil)
        session.rules = progress
        archive.activeSession = session
        if session.rules?.outcome != nil { finish() }
        else if Int(previous) != Int(session.rules?.activeElapsed ?? 0) { save() }
    }

    func finish() {
        guard var session = archive.activeSession else { return }
        let alreadyUnlocked = Set(achievements.filter(\.isUnlocked).map(\.achievement))
        let completed = session.collectedPelletIDs.count == session.route.pellets.count
        if session.rules?.outcome == nil { session.rules?.outcome = completed ? .completed : .stopped }
        session.finishedAt = Date()
        latestFinishedSession = session
        archive.results.append(session)
        latestUnlockedAchievements = achievements.filter { $0.isUnlocked && !alreadyUnlocked.contains($0.achievement) }.map(\.achievement)
        archive.activeSession = nil
        pause()
        save()
    }

    func fetchRoutes(server: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let url = try endpoint(server, path: "routes")
            let (data, response) = try await URLSession.shared.data(from: url)
            try check(response)
            let routes = try JSONDecoder().decode([GameRoute].self, from: data)
            guard Set(routes.map(\.id)).count == routes.count else { throw URLError(.cannotParseResponse) }
            try routes.forEach { try $0.validate() }
            archive.routes = routes
            save()
        } catch { message = "Routes unavailable. Saved routes remain playable. \(error.localizedDescription)" }
    }

    func sync(server: String) async {
        guard !isSyncing, pendingResults > 0 else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let url = try endpoint(server, path: "results")
            for result in archive.results where result.syncedAt == nil {
                try Task.checkCancellation()
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(result.id.uuidString, forHTTPHeaderField: "Idempotency-Key")
                request.httpBody = try JSONEncoder().encode(result)
                let (_, response) = try await URLSession.shared.data(for: request)
                try check(response)
                if let index = archive.results.firstIndex(where: { $0.id == result.id }) {
                    archive.results[index].syncedAt = Date()
                    save()
                }
            }
        } catch { message = "Results are saved and will retry next sync. \(error.localizedDescription)" }
    }

    private func endpoint(_ server: String, path: String) throws -> URL {
        try ServerEndpoint.url(server, path: path)
    }

    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
