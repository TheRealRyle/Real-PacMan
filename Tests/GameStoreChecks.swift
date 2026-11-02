import Foundation
import CoreLocation

@main
struct GameStoreChecks {
    @MainActor static func main() throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let file = folder.appending(path: "progress.json")
        let coordinate = RouteCoordinate(latitude: 48.85, longitude: 2.35)
        let pellet = Pellet(id: UUID(), coordinate: coordinate)
        let second = Pellet(id: UUID(), coordinate: RouteCoordinate(latitude: 48.86, longitude: 2.35))
        let route = GameRoute(id: UUID(), name: "Test walk", version: 1,
                              coordinates: [coordinate, second.coordinate], pellets: [pellet, second],
                              mapStyleURL: URL(string: "https://example.com/style.json")!)
        try route.validate()
        let store = GameStore(fileURL: file)
        store.start(route)
        func fix(accuracy: Double, age: TimeInterval = 0) -> CLLocation {
            CLLocation(coordinate: coordinate.coordinate, altitude: 0,
                       horizontalAccuracy: accuracy, verticalAccuracy: 0,
                       timestamp: Date().addingTimeInterval(age))
        }
        store.collect(at: fix(accuracy: 100))
        precondition(store.archive.activeSession?.score == 0, "Reject inaccurate GPS")
        store.collect(at: fix(accuracy: 5, age: -60))
        precondition(store.archive.activeSession?.score == 0, "Reject stale GPS")
        store.collect(at: fix(accuracy: 5))
        store.collect(at: fix(accuracy: 5))
        precondition(store.archive.activeSession?.score == 10, "Collect each pellet once")
        store.pause()
        let restored = GameStore(fileURL: file)
        precondition(restored.archive.activeSession?.score == 10, "Restore saved progress")
        precondition(!restored.isPlaying, "Restore in paused state")
        restored.finish()
        restored.finish()
        precondition(restored.archive.results.count == 1, "Finish is idempotent")
        precondition(restored.pendingResults == 1, "Persist result queue")
        let reloaded = GameStore(fileURL: file)
        precondition(reloaded.pendingResults == 1 && reloaded.archive.activeSession == nil)
        print("Passed: GPS accuracy, stale fixes, duplicate collection, restore, finish, durable queue")
    }
}
