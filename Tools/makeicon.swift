// Generates AppIcon.iconset PNGs for Health Tracker using CoreGraphics (no external deps).
// Usage: swift Tools/makeicon.swift [outputDir]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

func render(size px: Int) -> CGImage? {
    let s = CGFloat(px)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: px, height: px,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

    // Helpers in normalized (centered, fraction-of-size, y-up) coordinates.
    func p(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint { CGPoint(x: (0.5 + nx) * s, y: (0.5 + ny) * s) }

    // 1) Squircle background with a teal→green gradient.
    let radius = s * 0.2237
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let grad = CGGradient(colorsSpace: space,
                          colors: [rgb(0, 199, 190), rgb(45, 175, 95)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Subtle top highlight.
    let hi = CGGradient(colorsSpace: space,
                        colors: [rgb(255, 255, 255, 0.18), rgb(255, 255, 255, 0)] as CFArray,
                        locations: [0, 1])!
    ctx.drawRadialGradient(hi, startCenter: p(0, 0.35), startRadius: 0,
                           endCenter: p(0, 0.35), endRadius: s * 0.7, options: [])
    ctx.restoreGState()

    // 2) White progress ring (≈80% complete, opening at top).
    let center = p(0, 0)
    let ringR = s * 0.295
    ctx.setLineCap(.round)
    ctx.setStrokeColor(rgb(255, 255, 255))
    ctx.setLineWidth(s * 0.072)
    let start = -CGFloat.pi / 2 + 0.55          // leave a gap near the top
    let end = -CGFloat.pi / 2 - 0.55 + 2 * .pi
    ctx.addArc(center: center, radius: ringR, startAngle: start, endAngle: end, clockwise: false)
    ctx.strokePath()

    // 3) Centered checkmark.
    ctx.setLineWidth(s * 0.078)
    ctx.setLineJoin(.round)
    ctx.beginPath()
    ctx.move(to: p(-0.135, 0.01))
    ctx.addLine(to: p(-0.03, -0.105))
    ctx.addLine(to: p(0.155, 0.13))
    ctx.strokePath()

    return ctx.makeImage()
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (filename, pixel size) pairs required by an .iconset.
let specs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, px) in specs {
    if let img = render(size: px) {
        write(img, to: "\(outDir)/\(name)")
        print("✓ \(name)")
    } else {
        print("✗ failed \(name)")
    }
}
