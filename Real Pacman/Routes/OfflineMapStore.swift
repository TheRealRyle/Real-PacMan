import Foundation
import Observation
import MapLibre

@MainActor @Observable
final class OfflineMapStore {
    private(set) var status = "Download the route map before heading offline."
    private(set) var isDownloading = false
    private var pack: MLNOfflinePack?

    func download(_ route: GameRoute) async {
        guard !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }
        let context = Data("\(route.id.uuidString):\(route.version)".utf8)
        if let existing = MLNOfflineStorage.shared.packs?.first(where: { $0.context == context }) {
            pack = existing
        } else {
            let points = route.coordinates + route.pellets.map(\.coordinate)
            guard let first = points.first else { return }
            let south = max(-85, (points.map(\.latitude).min() ?? first.latitude) - 0.003)
            let north = min(85, (points.map(\.latitude).max() ?? first.latitude) + 0.003)
            let west = max(-180, (points.map(\.longitude).min() ?? first.longitude) - 0.003)
            let east = min(180, (points.map(\.longitude).max() ?? first.longitude) + 0.003)
            guard north - south < 0.25, east - west < 0.25 else {
                status = "This route is too large for a walking map download."; return
            }
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: south, longitude: west),
                ne: CLLocationCoordinate2D(latitude: north, longitude: east))
            let region = MLNTilePyramidOfflineRegion(styleURL: route.mapStyleURL, bounds: bounds,
                                                     fromZoomLevel: 12, toZoomLevel: 17)
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
            if pack.state == .complete { status = "Map downloaded · available offline"; return }
            let progress = pack.progress
            status = "Downloading map: \(progress.countOfResourcesCompleted) / \(progress.countOfResourcesExpected) resources"
            do { try await Task.sleep(for: .seconds(1)) }
            catch { pack.suspend(); status = "Download paused. Tap to resume."; return }
        }
        pack.suspend()
    }
}
