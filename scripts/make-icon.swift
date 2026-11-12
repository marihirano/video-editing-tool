// Draws the app icon and packs it into Resources/AppIcon.icns (no Xcode needed).
// Usage: swift scripts/make-icon.swift   (then scripts/build-app.sh picks it up)
//
// The design: a rounded square with the app's "Aurora" wallpaper colours, a light window
// floating on it with a soft shadow (the styled frame the app makes), a play triangle,
// and a purple zoom ring (the zoom colour on the timeline) over its corner.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // macOS icon grid: the shape fills ~80% of the canvas, centred.
    let inset = s * 0.1, side = s - 2 * inset
    let tile = CGRect(x: inset, y: inset, width: side, height: side)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: side * 0.225, cornerHeight: side * 0.225, transform: nil)

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.025, color: rgb(0x000000, 0.35))
    ctx.addPath(tilePath); ctx.setFillColor(rgb(0x101830)); ctx.fillPath()
    ctx.restoreGState()

    // Aurora-style background: navy, blended with violet, blue and mint from the corners.
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let base = CGGradient(colorsSpace: space, colors: [rgb(0x0E1430), rgb(0x1B1F4A)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: tile.minX, y: tile.maxY), end: CGPoint(x: tile.maxX, y: tile.minY), options: [])
    for (hex, x, y, r) in [(0x7B5CF0, 0.05, 0.05, 0.85), (0x3FE0B5, 0.95, 0.95, 0.8), (0x2F7BFF, 0.95, 0.1, 0.7)] as [(UInt32, CGFloat, CGFloat, CGFloat)] {
        let g = CGGradient(colorsSpace: space, colors: [rgb(hex, 0.9), rgb(hex, 0)] as CFArray, locations: [0, 1])!
        let c = CGPoint(x: tile.minX + side * x, y: tile.minY + side * y)
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: side * r, options: [])
    }

    // The floating window (the styled frame), with a soft shadow.
    let win = CGRect(x: tile.minX + side * 0.16, y: tile.minY + side * 0.27, width: side * 0.68, height: side * 0.48)
    let winPath = CGPath(roundedRect: win, cornerWidth: side * 0.045, cornerHeight: side * 0.045, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -side * 0.025), blur: side * 0.06, color: rgb(0x000000, 0.45))
    ctx.addPath(winPath); ctx.setFillColor(rgb(0xF4F6FB)); ctx.fillPath()
    ctx.restoreGState()
    // Title bar dots.
    for (i, hex) in [0xFF6B5E, 0xFFC23D, 0x34C759].enumerated() {
        let d = side * 0.032
        ctx.setFillColor(rgb(UInt32(hex)))
        ctx.fillEllipse(in: CGRect(x: win.minX + side * 0.04 + CGFloat(i) * d * 1.6, y: win.maxY - side * 0.06, width: d, height: d))
    }
    // Play triangle in the window.
    let cx = win.midX - side * 0.01, cy = win.midY - side * 0.02, t = side * 0.11
    ctx.move(to: CGPoint(x: cx - t * 0.45, y: cy + t * 0.6))
    ctx.addLine(to: CGPoint(x: cx + t * 0.65, y: cy))
    ctx.addLine(to: CGPoint(x: cx - t * 0.45, y: cy - t * 0.6))
    ctx.closePath()
    ctx.setFillColor(rgb(0x2F7BFF)); ctx.fillPath()

    // Purple zoom ring over the window's lower-right corner.
    let ringC = CGPoint(x: win.maxX - side * 0.02, y: win.minY + side * 0.02), ringR = side * 0.13
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -side * 0.01), blur: side * 0.03, color: rgb(0x000000, 0.4))
    ctx.setStrokeColor(rgb(0x7B5CF0)); ctx.setLineWidth(side * 0.045)
    ctx.strokeEllipse(in: CGRect(x: ringC.x - ringR, y: ringC.y - ringR, width: ringR * 2, height: ringR * 2))
    ctx.restoreGState()
    ctx.setFillColor(rgb(0xFFFFFF, 0.18))
    ctx.fillEllipse(in: CGRect(x: ringC.x - ringR + side * 0.02, y: ringC.y - ringR + side * 0.02, width: (ringR - side * 0.02) * 2, height: (ringR - side * 0.02) * 2))
    ctx.restoreGState()

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try draw(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try draw(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run(); p.waitUntilExit()
try draw(1024).write(to: root.appendingPathComponent("Resources/AppIcon-preview.png"))
print(p.terminationStatus == 0 ? "Wrote \(out.path)" : "iconutil failed")
