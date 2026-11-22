import UIKit

enum GhostAnnotationImage {
    static func make(id: Int, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: CGSize(width: 44, height: 46), format: format).image { _ in
            let body = UIBezierPath()
            body.move(to: CGPoint(x: 5, y: 40))
            body.addLine(to: CGPoint(x: 5, y: 21))
            body.addCurve(to: CGPoint(x: 39, y: 21), controlPoint1: CGPoint(x: 5, y: -2), controlPoint2: CGPoint(x: 39, y: -2))
            body.addLine(to: CGPoint(x: 39, y: 40))
            for point in [CGPoint(x: 33, y: 35), CGPoint(x: 27, y: 40), CGPoint(x: 22, y: 35),
                          CGPoint(x: 16, y: 40), CGPoint(x: 10, y: 35)] { body.addLine(to: point) }
            body.close()
            let colors: [UIColor] = [.systemPink, .systemCyan, .systemOrange]
            colors[abs(id % colors.count)].setFill()
            body.fill()
            UIColor.white.setStroke()
            body.lineWidth = 2
            body.stroke()
            for x in [CGFloat(12), CGFloat(25)] {
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: x, y: 17, width: 9, height: 13)).fill()
                UIColor(red: 0.04, green: 0.08, blue: 0.2, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: x + 3, y: 21, width: 5, height: 7)).fill()
            }
        }
    }
}
