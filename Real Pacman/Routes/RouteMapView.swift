import SwiftUI
import MapLibre

struct RouteMapView: UIViewRepresentable {
    let route: GameRoute
    let collected: Set<UUID>

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: route.mapStyleURL)
        map.showsUserLocation = true
        map.minimumZoomLevel = 12
        map.maximumZoomLevel = 17
        if let first = route.coordinates.first {
            map.setCenter(first.coordinate, zoomLevel: 15, animated: false)
        }
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let ids = Set(route.pellets.filter { !collected.contains($0.id) }.map(\.id))
        guard context.coordinator.visibleIDs != ids else { return }
        context.coordinator.visibleIDs = ids
        if let annotations = map.annotations { map.removeAnnotations(annotations) }
        var coordinates = route.coordinates.map(\.coordinate)
        let line = MLNPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
        map.addAnnotation(line)
        for pellet in route.pellets where ids.contains(pellet.id) {
            let point = MLNPointAnnotation()
            point.coordinate = pellet.coordinate.coordinate
            point.title = "Pellet"
            map.addAnnotation(point)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var visibleIDs: Set<UUID>?
    }
}
