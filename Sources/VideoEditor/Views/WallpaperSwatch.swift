import CoreGraphics
import Foundation
import EditorCore

/// Small pictures of the built-in wallpapers for the side panel, drawn with the same four-colour
/// blend the shader uses (`backgroundColor`, kind 0 in Shaders.swift), so each swatch looks like the real thing.
enum WallpaperSwatch {
    /// Pixel size of a swatch picture (twice the swatch's size on screen, for sharp Retina display).
    static let pixelWidth = 120
    static let pixelHeight = 76

    @MainActor private static var cache: [String: CGImage] = [:]

    @MainActor static func image(_ w: WallpaperPreset) -> CGImage {
        if let c = cache[w.name] { return c }
        let img = draw(w)
        cache[w.name] = img
        return img
    }

    private static func draw(_ w: WallpaperPreset) -> CGImage {
        let width = pixelWidth, height = pixelHeight
        // Same points and weights as the shader: one colour near each corner.
        let pts: [(Double, Double)] = [(0.1, 0.1), (0.9, 0.15), (0.15, 0.9), (0.9, 0.85)]
        let aspect = Double(width) / Double(height)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let u = (Double(x) + 0.5) / Double(width), v = (Double(y) + 0.5) / Double(height)
                var r = 0.0, g = 0.0, b = 0.0, total = 0.0
                for (i, p) in pts.enumerated() {
                    let dx = (u - p.0) * aspect, dy = v - p.1
                    let wt = 1 / pow(dx * dx + dy * dy + 0.04, 1.6)
                    let c = w.colors[i]
                    r += c.r * wt; g += c.g * wt; b += c.b * wt; total += wt
                }
                let o = (y * width + x) * 4
                bytes[o] = UInt8(min(max(r / total, 0), 1) * 255)
                bytes[o + 1] = UInt8(min(max(g / total, 0), 1) * 255)
                bytes[o + 2] = UInt8(min(max(b / total, 0), 1) * 255)
            }
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }
}
