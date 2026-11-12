import Foundation

/// One shared set of up to 255 colours for a whole GIF (index 255 is kept for "unchanged").
/// Built by median cut over frames sampled across the video, so the colours fit what is
/// actually on screen. Frames are matched to it with a small ordered dither to hide banding.
struct GIFPalette {
    static let colorCount = 255
    static let transparentIndex: UInt8 = 255

    /// RGB triples, 256 entries (the last is padding).
    private(set) var rgb = [UInt8](repeating: 0, count: 768)
    /// For each 5-bit-per-channel colour, the closest palette entry.
    private var lookup = [UInt8](repeating: 0, count: 32768)

    /// Collects colour counts from BGRA frames, then builds the palette.
    struct Builder {
        fileprivate var histogram = [UInt32](repeating: 0, count: 32768)
        mutating func add(bgra base: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int) {
            // Every other pixel in each direction is plenty for choosing colours.
            for y in stride(from: 0, to: height, by: 2) {
                let row = base + y * bytesPerRow
                for x in stride(from: 0, to: width, by: 2) {
                    let p = row + x * 4
                    histogram[Int(p[2] >> 3) << 10 | Int(p[1] >> 3) << 5 | Int(p[0] >> 3)] += 1
                }
            }
        }
        func build() -> GIFPalette { GIFPalette(histogram: histogram) }
    }

    private struct Box {
        var colors: [Int]          // 5-5-5 colour indices
        var population: Int
        func range(_ shift: Int, _ counts: [UInt32]) -> Int {
            var lo = 31, hi = 0
            for c in colors { let v = (c >> shift) & 31; lo = min(lo, v); hi = max(hi, v) }
            return hi - lo
        }
    }

    private init(histogram: [UInt32]) {
        let used = (0..<32768).filter { histogram[$0] > 0 }
        var boxes = [Box(colors: used, population: used.reduce(0) { $0 + Int(histogram[$1]) })]
        if used.isEmpty { boxes = [Box(colors: [0], population: 1)] }
        while boxes.count < Self.colorCount {
            // Split the box holding the most pixels (that has more than one colour).
            guard let i = boxes.indices.filter({ boxes[$0].colors.count > 1 }).max(by: { boxes[$0].population < boxes[$1].population }) else { break }
            let box = boxes[i]
            let ranges = [(10, box.range(10, histogram)), (5, box.range(5, histogram)), (0, box.range(0, histogram))]
            let shift = ranges.max(by: { $0.1 < $1.1 })!.0
            let sorted = box.colors.sorted { ($0 >> shift) & 31 < ($1 >> shift) & 31 }
            var running = 0, cut = 1
            for (k, c) in sorted.enumerated() {
                running += Int(histogram[c])
                if running * 2 >= box.population { cut = min(max(k + 1, 1), sorted.count - 1); break }
            }
            let a = Array(sorted[..<cut]), b = Array(sorted[cut...])
            let pa = a.reduce(0) { $0 + Int(histogram[$1]) }
            boxes[i] = Box(colors: a, population: pa)
            boxes.append(Box(colors: b, population: box.population - pa))
        }
        for (i, box) in boxes.enumerated() {
            var r = 0.0, g = 0.0, b = 0.0, n = 0.0
            for c in box.colors {
                let w = Double(max(histogram[c], 1))
                r += w * Double((c >> 10) & 31); g += w * Double((c >> 5) & 31); b += w * Double(c & 31); n += w
            }
            // 5-bit value v stands for 8-bit colours v*8 … v*8+7: use the middle.
            rgb[i * 3] = UInt8(min(255, r / n * 8 + 4)); rgb[i * 3 + 1] = UInt8(min(255, g / n * 8 + 4)); rgb[i * 3 + 2] = UInt8(min(255, b / n * 8 + 4))
        }
        let count = boxes.count
        for c in 0..<32768 {
            let r = Int(c >> 10 & 31) * 8 + 4, g = Int(c >> 5 & 31) * 8 + 4, b = Int(c & 31) * 8 + 4
            var best = 0, bestD = Int.max
            for i in 0..<count {
                let dr = r - Int(rgb[i * 3]), dg = g - Int(rgb[i * 3 + 1]), db = b - Int(rgb[i * 3 + 2])
                let d = 2 * dr * dr + 4 * dg * dg + 3 * db * db
                if d < bestD { bestD = d; best = i }
            }
            lookup[c] = UInt8(best)
        }
    }

    private static let bayer4: [Int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    /// Turns a BGRA frame into palette indices (width × height, no row padding).
    func indices(bgra base: UnsafePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int, dither: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: width * height)
        out.withUnsafeMutableBufferPointer { o in
            lookup.withUnsafeBufferPointer { lut in
                Self.bayer4.withUnsafeBufferPointer { bayer in
                    for y in 0..<height {
                        let row = base + y * bytesPerRow
                        for x in 0..<width {
                            let p = row + x * 4
                            // Threshold in -dither/2 … +dither/2.
                            let t = (bayer[(y & 3) << 2 | (x & 3)] * dither) / 15 - dither / 2
                            let r = min(255, max(0, Int(p[2]) + t)), g = min(255, max(0, Int(p[1]) + t)), b = min(255, max(0, Int(p[0]) + t))
                            o[y * width + x] = lut[(r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)]
                        }
                    }
                }
            }
        }
        return out
    }
}
