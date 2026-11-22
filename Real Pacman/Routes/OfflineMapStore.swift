import Foundation
import Observation
import MapLibre

@MainActor @Observable
final class OfflineMapStore {
    private(set) var status = "Checking offline download…"
    private(set) var isChecking = true
    private(set) var isDownloading = false
    private(set) var isDownloaded = false
    private(set) var canResume = false
    private(set) var progress: Double?
    private var pack: MLNOfflinePack?

    func refreshStatus(for route: GameRoute) async {
        guard !isDownloading else { return }
        isChecking = true
        isDownloaded = false
        canResume = false
        defer { isChecking = false }
        do {
            try await waitForPacks()
            try Task.checkCancellation()
            let context = Data("\(route.id.uuidString):\(route.version)".utf8)
            if let existing = MLNOfflineStorage.shared.packs?.first(where: { $0.context == context }) {
                existing.requestProgress()
                // Persisted pack states are initially unknown; requestProgress is asynchronous.
                for _ in 0..<100 {
                    if existing.state != .unknown { break }
                    try await Task.sleep(for: .milliseconds(50))
                }
                guard existing.state != .unknown else { throw URLError(.timedOut) }
                isDownloaded = existing.state == .complete
                canResume = !isDownloaded
                status = isDownloaded ? "Street map saved on this device." : "Map partially downloaded · resume to finish."
            } else { status = "Not downloaded · save the street map for offline play." }
        } catch is CancellationError {
            return
        } catch { status = "Offline map storage is unavailable. Try again." }
    }

    private func waitForPacks() async throws {
        // packs is nil during asynchronous SDK startup. Do not create a duplicate pack.
        for _ in 0..<100 {
            if MLNOfflineStorage.shared.packs != nil { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw URLError(.timedOut)
    }

    func download(_ route: GameRoute) async {
        guard !isDownloading, !isChecking else { return }
        isDownloading = true
        isDownloaded = false
        progress = nil
        status = "Preparing download…"
        defer { isDownloading = false }
        do { try await waitForPacks(); try Task.checkCancellation() }
        catch is CancellationError { status = "Download paused. Tap to resume."; return }
        catch { status = "Offline map storage is unavailable. Try again."; return }
        let context = Data("\(route.id.uuidString):\(route.version)".utf8)
        if let existing = MLNOfflineStorage.shared.packs?.first(where: { $0.context == context }) {
            pack = existing
        } else {
            guard let area = OfflineMapBounds(route: route) else {
                status = "This route is too large for a walking map download."; return
            }
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: area.south, longitude: area.west),
                ne: CLLocationCoordinate2D(latitude: area.north, longitude: area.east))
            let region = MLNTilePyramidOfflineRegion(styleURL: route.mapStyleURL, bounds: bounds,
                                                     fromZoomLevel: Double(OfflineMapBounds.minimumZoom),
                                                     toZoomLevel: Double(OfflineMapBounds.maximumZoom))
            do {
                pack = try await withCheckedThrowingContinuation { continuation in
                    MLNOfflineStorage.shared.addPack(for: region, withContext: context) { pack, error in
                        if let error { continuation.resume(throwing: error) }
                        else if let pack { continuation.resume(returning: pack) }
                        else { continuation.resume(throwing: URLError(.unknown)) }
                    }
                }
            } catch { status = error.localizedDescription; return }
        }
        guard let pack else { return }
        canResume = true
        guard !Task.isCancelled else {
            pack.suspend(); status = "Download paused. Tap to resume."; return
        }
        pack.resume()
        // Poll only while this view's download task remains alive. MapLibre owns persistent packs.
        let deadline = Date().addingTimeInterval(300)
        while !Task.isCancelled {
            if Date() > deadline {
                pack.suspend()
                status = "Download paused after five minutes. Check your connection and tap to resume."
                return
            }
            pack.requestProgress()
            if pack.state == .complete {
                isDownloaded = true
                canResume = false
                progress = 1
                status = "Street map saved on this device."
                return
            }
            let counts = pack.progress
            progress = counts.countOfResourcesExpected > 0
                ? min(0.99, Double(counts.countOfResourcesCompleted) / Double(counts.countOfResourcesExpected)) : nil
            status = counts.countOfResourcesExpected > 0
                ? "Downloading map: \(counts.countOfResourcesCompleted) / \(counts.countOfResourcesExpected) resources"
                : "Preparing offline map resources…"
            do { try await Task.sleep(for: .seconds(1)) }
            catch { pack.suspend(); status = "Download paused. Tap to resume."; return }
        }
        pack.suspend()
    }
}
