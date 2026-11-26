import AppKit

// Matches the existing yellow player marker and cyan street-map palette.
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: 1)
}
let navy = color(0.025, 0.05, 0.12)
context.setFillColor(navy); context.fill(CGRect(x: 0, y: 0, width: size, height: size))
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0.04, 0.20, 0.34), navy] as CFArray, locations: [0, 1])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: 420, y: 560), startRadius: 20,
                          endCenter: CGPoint(x: 480, y: 520), endRadius: 750, options: [.drawsAfterEndLocation])
func street(_ points: [(CGFloat, CGFloat)]) {
    context.beginPath()
    context.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() { context.addLine(to: CGPoint(x: point.0, y: point.1)) }
    context.strokePath()
}
context.setLineCap(.round); context.setLineJoin(.round)
context.setStrokeColor(color(0.06, 0.45, 0.64)); context.setLineWidth(24)
street([(105, 290), (105, 820), (360, 820), (360, 920)])
street([(100, 150), (510, 150), (510, 280), (900, 280), (900, 390)])
street([(560, 925), (560, 790), (900, 790), (900, 635)])
context.setStrokeColor(color(0.12, 0.78, 0.94)); context.setLineWidth(7)
street([(105, 290), (105, 820), (360, 820), (360, 920)])
street([(100, 150), (510, 150), (510, 280), (900, 280), (900, 390)])
street([(560, 925), (560, 790), (900, 790), (900, 635)])
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.5).cgColor)
context.setFillColor(color(1, 0.84, 0))
context.move(to: CGPoint(x: 425, y: 510))
context.addArc(center: CGPoint(x: 425, y: 510), radius: 239,
               startAngle: .pi / 5, endAngle: 2 * .pi - .pi / 5, clockwise: false)
context.closePath(); context.fillPath()
context.restoreGState()
context.setFillColor(navy)
context.fillEllipse(in: CGRect(x: 410, y: 629, width: 30, height: 30))
for (x, radius): (CGFloat, CGFloat) in [(703, 30), (814, 25), (914, 20)] {
    context.setFillColor(color(1, 0.91, 0.42))
    context.fillEllipse(in: CGRect(x: x - radius, y: 510 - radius, width: radius * 2, height: radius * 2))
}
let output = CommandLine.arguments.dropFirst().first ?? "Real Pacman/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Generated opaque 1024 × 1024 app icon: \(output)")
