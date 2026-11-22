import UIKit
import MapLibre

final class PlayerAnnotationView: MLNAnnotationView {
    private let artwork = UIImageView(image: UIImage(named: "PlayerMarker")?.withRenderingMode(.alwaysOriginal))

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        artwork.frame = bounds
        addSubview(artwork)
        scalesWithViewingDistance = false
        rotatesToMatchCamera = false
        accessibilityLabel = "Demo player"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(bearing: Double, mapDirection: Double) {
        artwork.transform = CGAffineTransform(rotationAngle: PlayerHeading.screenRotation(bearing: bearing, mapDirection: mapDirection) * .pi / 180)
    }
}

/// Native location tracking stays enabled; the blue halo represents GPS uncertainty.
final class PlayerLocationAnnotationView: MLNUserLocationAnnotationView {
    private var heading = PlayerHeading()
    private let artwork = UIImageView(image: UIImage(named: "PlayerMarker")?.withRenderingMode(.alwaysOriginal))
    private let accuracy = CAShapeLayer()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        accuracy.fillColor = UIColor.systemBlue.withAlphaComponent(0.14).cgColor
        accuracy.strokeColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        accuracy.lineWidth = 1
        layer.addSublayer(accuracy)
        artwork.frame = bounds
        addSubview(artwork)
        scalesWithViewingDistance = false
        rotatesToMatchCamera = false
        clipsToBounds = false
        accessibilityLabel = "Your position"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func update() {
        guard let mapView, let location = userLocation?.location else { return }
        if location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 20,
           abs(location.timestamp.timeIntervalSinceNow) < 10 {
            heading.update(coordinate: RouteCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                           course: location.course, speed: location.speed)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let metersPerPoint = mapView.metersPerPoint(atLatitude: location.coordinate.latitude)
        if location.horizontalAccuracy.isFinite, location.horizontalAccuracy >= 0, metersPerPoint > 0 {
            let radius = location.horizontalAccuracy / metersPerPoint
            accuracy.path = UIBezierPath(ovalIn: CGRect(x: 20 - radius, y: 20 - radius, width: radius * 2, height: radius * 2)).cgPath
            accuracy.isHidden = false
        } else {
            accuracy.isHidden = true
        }
        artwork.transform = CGAffineTransform(rotationAngle: PlayerHeading.screenRotation(bearing: heading.degrees, mapDirection: mapView.direction) * .pi / 180)
        CATransaction.commit()
    }
}
