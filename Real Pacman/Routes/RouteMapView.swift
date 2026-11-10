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
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let ids = Set(route.pellets.filter { !collected.contains($0.id) }.map(\.id))
        let routeChanged = context.coordinator.route != route
        guard routeChanged || context.coordinator.visibleIDs != ids else { return }
        context.coordinator.route = route
        context.coordinator.visibleIDs = ids
        map.removeAnnotations(context.coordinator.annotations)
        var annotations: [MLNAnnotation] = []
        for line in route.pathLines {
            var coordinates = line.map(\.coordinate)
            annotations.append(MLNPolyline(coordinates: &coordinates, count: UInt(coordinates.count)))
        }
        if let definition = route.parcours {
            var boundary = definition.boundary.map(\.coordinate)
            annotations.append(MLNPolygon(coordinates: &boundary, count: UInt(boundary.count)))
            if let start = definition.start {
                let point = MLNPointAnnotation()
                point.coordinate = start.coordinate
                point.title = "Starting point"
                annotations.append(point)
            }
        }
        for pellet in route.pellets where ids.contains(pellet.id) {
            let point = MLNPointAnnotation()
            point.coordinate = pellet.coordinate.coordinate
            point.title = "Pellet · \(pellet.value) points"
            annotations.append(point)
        }
        context.coordinator.annotations = annotations
        map.addAnnotations(annotations)
        if routeChanged, let first = route.mapCoordinates.first {
            let points = route.mapCoordinates
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: points.map(\.latitude).min() ?? first.latitude,
                                          longitude: points.map(\.longitude).min() ?? first.longitude),
                ne: CLLocationCoordinate2D(latitude: points.map(\.latitude).max() ?? first.latitude,
                                          longitude: points.map(\.longitude).max() ?? first.longitude))
            map.setVisibleCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                                           animated: false, completionHandler: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var route: GameRoute?
        var visibleIDs: Set<UUID>?
        var annotations: [MLNAnnotation] = []

        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            annotation is MLNPolygon ? .systemGreen : .systemCyan
        }

        func mapView(_ mapView: MLNMapView, fillColorForPolygonAnnotation annotation: MLNPolygon) -> UIColor {
            UIColor.systemGreen.withAlphaComponent(0.12)
        }

        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat { 4 }
    }
}
