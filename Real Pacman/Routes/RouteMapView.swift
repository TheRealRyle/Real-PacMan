import SwiftUI
import MapLibre
import UIKit

struct RouteMapView: UIViewRepresentable {
    let route: GameRoute
    let collected: Set<UUID>
    var cameraRequest: RouteMapCameraRequest? = nil
    var simulatedPlayer: RouteCoordinate? = nil
    var usesDeviceLocation = true
    var followZoom: Double = GameplayRules.defaultZoom
    var isGameplay = false
    var guidancePlayer: RouteCoordinate? = nil
    var onIndicatorChange: ((PelletIndicator?) -> Void)? = nil
    var onMapAvailabilityChange: ((Bool) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: route.mapStyleURL)
        map.showsUserLocation = usesDeviceLocation
        map.isRotateEnabled = usesDeviceLocation
        map.isPitchEnabled = usesDeviceLocation
        map.minimumZoomLevel = 12
        map.maximumZoomLevel = 19
        if let start = route.parcours?.start ?? route.coordinates.first {
            map.setCenter(start.coordinate, zoomLevel: isGameplay ? followZoom : 16.5, animated: false)
        }
        map.showsScale = true
        map.scaleBarMargins = CGPoint(x: 16, y: 86)
        map.showsCompassView = true
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.onMapAvailabilityChange = onMapAvailabilityChange
        context.coordinator.onIndicatorChange = onIndicatorChange
        context.coordinator.guidancePlayer = guidancePlayer
        let zoomChanged = context.coordinator.followZoom != followZoom
        context.coordinator.followZoom = followZoom
        map.showsUserLocation = usesDeviceLocation
        let ids = Set(route.pellets.filter { !collected.contains($0.id) }.map(\.id))
        let routeChanged = context.coordinator.route != route
        if routeChanged { context.coordinator.invalidateGuidance() }
        if routeChanged || context.coordinator.visibleIDs != ids {
            updateAnnotations(map, coordinator: context.coordinator, ids: ids, routeChanged: routeChanged)
        }
        if zoomChanged, isGameplay || context.coordinator.followsSimulatedPlayer || map.userTrackingMode != .none {
            map.setZoomLevel(followZoom, animated: !reduceMotion)
        }
        context.coordinator.updateSimulatedPlayer(simulatedPlayer, on: map, animated: !reduceMotion)
        if let cameraRequest, context.coordinator.cameraRequestID != cameraRequest.id {
            context.coordinator.cameraRequestID = cameraRequest.id
            switch cameraRequest.target {
            case .savedZoom:
                map.setZoomLevel(followZoom, animated: !reduceMotion)
            case .player:
                context.coordinator.needsInitialFraming = false
                if usesDeviceLocation {
                    context.coordinator.pendingTrackingZoom = true
                    map.setZoomLevel(followZoom, animated: false)
                    let tracking: MLNUserTrackingMode = map.userTrackingMode == .follow ? .followWithHeading : .follow
                    let coordinator = context.coordinator
                    map.setUserTrackingMode(tracking, animated: !reduceMotion) { [weak map, weak coordinator] in
                        guard let map, let coordinator, map.userTrackingMode != .none else { return }
                        // Native tracking may adjust zoom while acquiring its first GPS fix.
                        map.setZoomLevel(coordinator.followZoom, animated: false)
                    }
                } else if let simulatedPlayer {
                    context.coordinator.followsSimulatedPlayer = true
                    map.setDirection(0, animated: false)
                    map.setCenter(simulatedPlayer.coordinate, zoomLevel: followZoom, animated: !reduceMotion)
                }
            case .parcours:
                context.coordinator.pendingTrackingZoom = false
                context.coordinator.followsSimulatedPlayer = false
                map.setUserTrackingMode(.none, animated: false, completionHandler: nil)
                map.setDirection(0, animated: false)
                context.coordinator.showParcours(on: map, animated: !reduceMotion)
            }
        }
        context.coordinator.refreshGuidanceTarget()
        context.coordinator.updateIndicator(on: map)
    }

    private func updateAnnotations(_ map: MLNMapView, coordinator: Coordinator, ids: Set<UUID>, routeChanged: Bool) {
        coordinator.route = route
        coordinator.visibleIDs = ids
        map.removeAnnotations(coordinator.annotations)
        coordinator.startAnnotation = nil
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
                coordinator.startAnnotation = point
                annotations.append(point)
            }
        }
        for pellet in route.pellets where ids.contains(pellet.id) {
            let point = MLNPointAnnotation()
            point.coordinate = pellet.coordinate.coordinate
            point.title = "Pellet · \(pellet.value) points"
            annotations.append(point)
        }
        coordinator.annotations = annotations
        map.addAnnotations(annotations)
        if routeChanged {
            if map.styleURL != route.mapStyleURL { map.styleURL = route.mapStyleURL }
            coordinator.needsInitialFraming = !isGameplay
            if isGameplay, let start = route.parcours?.start ?? route.coordinates.first {
                map.setCenter(start.coordinate, zoomLevel: followZoom, animated: false)
            } else {
                coordinator.showParcours(on: map, animated: false)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ map: MLNMapView, coordinator: Coordinator) {
        coordinator.onMapAvailabilityChange = nil
        coordinator.onIndicatorChange = nil
        map.delegate = nil
        map.showsUserLocation = false
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var route: GameRoute?
        var visibleIDs: Set<UUID>?
        var annotations: [MLNAnnotation] = []
        var startAnnotation: MLNPointAnnotation?
        var cameraRequestID: UUID?
        var needsInitialFraming = false
        var onMapAvailabilityChange: ((Bool) -> Void)?
        var simulatedPlayerAnnotation: MLNPointAnnotation?
        var followsSimulatedPlayer = false
        var followZoom = GameplayRules.defaultZoom
        var pendingTrackingZoom = false
        var guidancePlayer: RouteCoordinate?
        var onIndicatorChange: ((PelletIndicator?) -> Void)?
        private var lastIndicator: PelletIndicator?
        private var nearestTarget: Pellet?
        private var nearestPlayer: RouteCoordinate?
        private var nearestVisibleIDs: Set<UUID>?

        func invalidateGuidance() {
            nearestPlayer = nil
            nearestVisibleIDs = nil
            nearestTarget = nil
        }

        func refreshGuidanceTarget() {
            guard guidancePlayer != nearestPlayer || visibleIDs != nearestVisibleIDs else { return }
            nearestPlayer = guidancePlayer
            nearestVisibleIDs = visibleIDs
            guard let route, let player = guidancePlayer else { nearestTarget = nil; return }
            nearestTarget = PelletGuidance.nearest(in: route,
                collected: Set(route.pellets.map(\.id)).subtracting(visibleIDs ?? []), player: player)
        }

        func updateIndicator(on map: MLNMapView) {
            var indicator: PelletIndicator?
            if let player = guidancePlayer, let pellet = nearestTarget {
                let target = map.convert(pellet.coordinate.coordinate, toPointTo: map)
                let visible = CGRect(x: 48, y: 140, width: map.bounds.width - 96, height: map.bounds.height - 240)
                if let edge = PelletGuidance.edgePoint(target: target, visibleRect: visible) {
                    let angle = atan2(target.y - visible.midY, target.x - visible.midX) * 180 / .pi + 90
                    indicator = PelletIndicator(position: edge, angleDegrees: angle,
                        distanceMeters: Int(player.location.distance(from: pellet.coordinate.location).rounded()))
                }
            }
            guard indicator != lastIndicator else { return }
            lastIndicator = indicator
            // Map delegates may run during updateUIView. Deliver outside that update.
            DispatchQueue.main.async { [weak self] in self?.onIndicatorChange?(indicator) }
        }

        func mapViewRegionIsChanging(_ mapView: MLNMapView) { updateIndicator(on: mapView) }
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) { updateIndicator(on: mapView) }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard pendingTrackingZoom, mapView.userTrackingMode != .none,
                  let location = userLocation?.location, location.horizontalAccuracy >= 0 else { return }
            pendingTrackingZoom = false
            mapView.setZoomLevel(followZoom, animated: false)
        }


        func updateSimulatedPlayer(_ coordinate: RouteCoordinate?, on map: MLNMapView, animated: Bool) {
            guard let coordinate else {
                if let simulatedPlayerAnnotation { map.removeAnnotation(simulatedPlayerAnnotation) }
                simulatedPlayerAnnotation = nil
                followsSimulatedPlayer = false
                return
            }
            if let simulatedPlayerAnnotation {
                let old = simulatedPlayerAnnotation.coordinate
                guard old.latitude != coordinate.latitude || old.longitude != coordinate.longitude else { return }
                simulatedPlayerAnnotation.coordinate = coordinate.coordinate
            } else {
                let point = MLNPointAnnotation()
                point.coordinate = coordinate.coordinate
                point.title = "Demo player"
                simulatedPlayerAnnotation = point
                map.addAnnotation(point)
            }
            if followsSimulatedPlayer { map.setCenter(coordinate.coordinate, animated: animated) }
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            let gestures: MLNCameraChangeReason = [.gesturePan, .gesturePinch, .gestureZoomIn,
                                                   .gestureZoomOut, .gestureOneFingerZoom]
            if !reason.intersection(gestures).isEmpty {
                followsSimulatedPlayer = false
                pendingTrackingZoom = false
            }
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            if needsInitialFraming, mapView.userTrackingMode == .none {
                showParcours(on: mapView, animated: false)
            }
            updateIndicator(on: mapView)
            onMapAvailabilityChange?(true)
        }

        func showParcours(on map: MLNMapView, animated: Bool) {
            // SwiftUI can call updateUIView before the map has a usable size.
            // Fit again after loading rather than calculating a city-wide zoom from zero bounds.
            guard map.bounds.width > 106, map.bounds.height > 170,
                  let points = route?.mapCoordinates, let first = points.first else { return }
            needsInitialFraming = false
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: points.map(\.latitude).min() ?? first.latitude,
                                          longitude: points.map(\.longitude).min() ?? first.longitude),
                ne: CLLocationCoordinate2D(latitude: points.map(\.latitude).max() ?? first.latitude,
                                          longitude: points.map(\.longitude).max() ?? first.longitude))
            map.setVisibleCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: 110, left: 36, bottom: 60, right: 70),
                                           animated: animated, completionHandler: nil)
        }

        func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            onMapAvailabilityChange?(false)
        }

        func mapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage? {
            // Keep MapLibre's blue location dot and its accuracy indicator.
            guard annotation is MLNPointAnnotation else { return nil }
            let isStart = (annotation as AnyObject) === startAnnotation
            let isPlayer = (annotation as AnyObject) === simulatedPlayerAnnotation
            let identifier = isPlayer ? "demo-player" : isStart ? "parcours-start" : "pellet"
            if let image = mapView.dequeueReusableAnnotationImage(withIdentifier: identifier) { return image }
            let diameter: CGFloat = isPlayer ? 22 : isStart ? 28 : 16
            let size = CGSize(width: diameter, height: diameter)
            let format = UIGraphicsImageRendererFormat()
            format.scale = mapView.traitCollection.displayScale
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2))
                (isStart || isPlayer ? UIColor.systemBlue : UIColor.systemYellow).setFill()
                circle.fill()
                UIColor.white.setStroke()
                circle.lineWidth = 3
                circle.stroke()
                if isStart {
                    UIImage(systemName: "flag.fill")?
                        .withTintColor(.white, renderingMode: .alwaysOriginal)
                        .draw(in: CGRect(x: 8, y: 7, width: 12, height: 14))
                }
            }
            return MLNAnnotationImage(image: image, reuseIdentifier: identifier)
        }

        func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
            annotation is MLNPointAnnotation
        }

        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            annotation is MLNPolygon ? UIColor.systemGreen.withAlphaComponent(0.55) : UIColor.systemBlue.withAlphaComponent(0.65)
        }

        func mapView(_ mapView: MLNMapView, fillColorForPolygonAnnotation annotation: MLNPolygon) -> UIColor {
            UIColor.systemGreen.withAlphaComponent(0.04)
        }

        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat { 3 }
    }
}
