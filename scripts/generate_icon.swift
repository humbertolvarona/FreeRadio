import AppKit
import CoreGraphics

let iconsetPath = "/Users/humbertovarona/Lavoro/Papers/freeRadio/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, filename) in sizes {
    let cgSize = CGSize(width: size, height: size)
    let image = NSImage(size: cgSize)
    image.lockFocus()

    if let ctx = NSGraphicsContext.current?.cgContext {
        let rect = CGRect(origin: .zero, size: cgSize)
        let cornerRadius = CGFloat(size) * 0.225
        let path = CGPath(roundedRect: rect.insetBy(dx: CGFloat(size)*0.02, dy: CGFloat(size)*0.02),
                          cornerWidth: cornerRadius,
                          cornerHeight: cornerRadius,
                          transform: nil)
        ctx.addPath(path)
        ctx.clip()

        let colors = [
            NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.28, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.18, green: 0.36, blue: 0.85, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.88, alpha: 1.0).cgColor
        ] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.55, 1.0]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size, y: size),
                options: []
            )
        }

        // Draw subtle radio waves concentric circles
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        ctx.setLineWidth(max(1.5, CGFloat(size) * 0.02))
        for mult in [0.55, 0.72, 0.88] {
            let r = CGFloat(size) * CGFloat(mult)
            let circleRect = CGRect(
                x: (CGFloat(size) - r) / 2.0,
                y: (CGFloat(size) - r) / 2.0,
                width: r,
                height: r
            )
            ctx.strokeEllipse(in: circleRect)
        }
    }

    // Draw SF Symbol radio icon in center
    if let symbol = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.45, weight: .bold)
        if let configured = symbol.withSymbolConfiguration(config) {
            let symSize = configured.size
            let symRect = CGRect(
                x: (CGFloat(size) - symSize.width) / 2.0,
                y: (CGFloat(size) - symSize.height) / 2.0,
                width: symSize.width,
                height: symSize.height
            )
            NSColor.white.set()
            configured.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 0.96)
        }
    }

    image.unlockFocus()

    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let outURL = URL(fileURLWithPath: iconsetPath).appendingPathComponent(filename)
        try? png.write(to: outURL)
    }
}
print("Generated AppIcon.iconset successfully")
