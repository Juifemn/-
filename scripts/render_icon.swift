import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: render_icon.swift <iconset-dir>")
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

struct IconSize {
    let points: Int
    let scale: Int
    let name: String

    var pixels: Int { points * scale }
}

let sizes = [
    IconSize(points: 16, scale: 1, name: "icon_16x16.png"),
    IconSize(points: 16, scale: 2, name: "icon_16x16@2x.png"),
    IconSize(points: 32, scale: 1, name: "icon_32x32.png"),
    IconSize(points: 32, scale: 2, name: "icon_32x32@2x.png"),
    IconSize(points: 128, scale: 1, name: "icon_128x128.png"),
    IconSize(points: 128, scale: 2, name: "icon_128x128@2x.png"),
    IconSize(points: 256, scale: 1, name: "icon_256x256.png"),
    IconSize(points: 256, scale: 2, name: "icon_256x256@2x.png"),
    IconSize(points: 512, scale: 1, name: "icon_512x512.png"),
    IconSize(points: 512, scale: 2, name: "icon_512x512@2x.png")
]

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xff) / 255
    let g = CGFloat((hex >> 8) & 0xff) / 255
    let b = CGFloat(hex & 0xff) / 255
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawShadowedPath(_ path: NSBezierPath, fill: NSColor, shadowColor: NSColor, blur: CGFloat, y: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = shadowColor
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = CGSize(width: 0, height: y)
    shadow.set()
    fill.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawIcon(size: Int) -> NSImage {
    let canvas = CGFloat(size)
    let image = NSImage(size: CGSize(width: canvas, height: canvas))

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("No graphics context")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let s = canvas / 1024
    func r(_ value: CGFloat) -> CGFloat { value * s }
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: r(x), y: r(y), width: r(width), height: r(height))
    }

    NSColor.clear.setFill()
    CGRect(x: 0, y: 0, width: canvas, height: canvas).fill()

    let bg = roundedRect(rect(64, 64, 896, 896), radius: r(210))
    let bgGradient = NSGradient(colors: [
        color(0xf9fbff),
        color(0xeaf3ff),
        color(0xd8e9ff)
    ])!
    bgGradient.draw(in: bg, angle: 315)

    color(0xffffff, 0.62).setStroke()
    bg.lineWidth = r(8)
    bg.stroke()

    let rear = roundedRect(rect(242, 284, 332, 244), radius: r(42))
    drawShadowedPath(rear, fill: color(0xd1d6de), shadowColor: color(0x5d6b80, 0.18), blur: r(36), y: -r(20))
    color(0xf7f9fc, 0.78).setStroke()
    rear.lineWidth = r(9)
    rear.stroke()

    let rearInset = roundedRect(rect(276, 320, 264, 172), radius: r(28))
    color(0xe8edf4).setFill()
    rearInset.fill()

    let front = roundedRect(rect(404, 388, 382, 276), radius: r(48))
    drawShadowedPath(front, fill: color(0xcfd5df), shadowColor: color(0x33445c, 0.22), blur: r(42), y: -r(22))
    color(0xffffff, 0.84).setStroke()
    front.lineWidth = r(10)
    front.stroke()

    let frontInset = roundedRect(rect(442, 428, 306, 194), radius: r(32))
    let screenGradient = NSGradient(colors: [
        color(0xf4f7fb),
        color(0xdce4ee)
    ])!
    screenGradient.draw(in: frontInset, angle: 300)

    let ringRect = rect(510, 468, 142, 142)
    let ring = NSBezierPath(ovalIn: ringRect)
    color(0x2388ff, 0.13).setFill()
    ring.fill()
    color(0x1477eb, 0.96).setStroke()
    ring.lineWidth = r(16)
    ring.stroke()

    let ringHighlight = NSBezierPath(ovalIn: ringRect.insetBy(dx: r(24), dy: r(24)))
    color(0xffffff, 0.55).setStroke()
    ringHighlight.lineWidth = r(5)
    ringHighlight.stroke()

    let cursor = NSBezierPath()
    cursor.move(to: CGPoint(x: r(322), y: r(652)))
    cursor.line(to: CGPoint(x: r(322), y: r(372)))
    cursor.line(to: CGPoint(x: r(514), y: r(532)))
    cursor.line(to: CGPoint(x: r(426), y: r(548)))
    cursor.line(to: CGPoint(x: r(482), y: r(668)))
    cursor.line(to: CGPoint(x: r(420), y: r(696)))
    cursor.line(to: CGPoint(x: r(366), y: r(578)))
    cursor.close()

    drawShadowedPath(cursor, fill: color(0xffffff), shadowColor: color(0x1b2a3f, 0.28), blur: r(22), y: -r(10))
    color(0x6f7d8f).setStroke()
    cursor.lineJoinStyle = .round
    cursor.lineWidth = r(10)
    cursor.stroke()

    let travel = NSBezierPath()
    travel.move(to: CGPoint(x: r(502), y: r(642)))
    travel.curve(
        to: CGPoint(x: r(576), y: r(600)),
        controlPoint1: CGPoint(x: r(532), y: r(642)),
        controlPoint2: CGPoint(x: r(560), y: r(622))
    )
    color(0x1477eb, 0.34).setStroke()
    travel.lineWidth = r(10)
    travel.lineCapStyle = .round
    travel.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to encode PNG")
    }
    try! png.write(to: url)
}

for iconSize in sizes {
    let image = drawIcon(size: iconSize.pixels)
    writePNG(image, to: outputURL.appendingPathComponent(iconSize.name))
}
