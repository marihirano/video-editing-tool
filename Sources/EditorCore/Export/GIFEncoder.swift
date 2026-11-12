import Foundation

/// Writes an animated GIF one frame at a time. Every frame shares one palette, and a frame
/// only stores the rectangle that changed since the last one (unchanged pixels point at a
/// see-through colour), which keeps screen recordings small.
final class GIFEncoder {
    let width: Int, height: Int
    private let sink: (Data) -> Void
    private var previous: [UInt8]?
    private(set) var bytesWritten = 0

    init(width: Int, height: Int, palette: GIFPalette, sink: @escaping (Data) -> Void) {
        self.width = width; self.height = height; self.sink = sink
        var d = Data("GIF89a".utf8)
        d += le(width); d += le(height)
        d += [0xF7, 0, 0]                      // global colour table, 256 colours
        d += palette.rgb
        d += [0x21, 0xFF, 0x0B] + Data("NETSCAPE2.0".utf8) + [3, 1, 0, 0, 0]   // loop forever
        emit(d)
    }

    private func emit(_ d: Data) { bytesWritten += d.count; sink(d) }
    private func le(_ v: Int) -> [UInt8] { [UInt8(v & 255), UInt8(v >> 8 & 255)] }

    /// Adds a frame (palette indices, width × height). `delay` is in hundredths of a second.
    func addFrame(_ indices: [UInt8], delay: Int) {
        var x0 = 0, y0 = 0, w = width, h = height
        var pixels = indices
        let transparent = GIFPalette.transparentIndex
        if let prev = previous {
            var minX = width, maxX = -1, minY = height, maxY = -1
            indices.withUnsafeBufferPointer { a in prev.withUnsafeBufferPointer { b in
                for y in 0..<height {
                    let r = y * width
                    for x in 0..<width where a[r + x] != b[r + x] {
                        if x < minX { minX = x }; if x > maxX { maxX = x }
                        if y < minY { minY = y }; maxY = y
                    }
                }
            } }
            if maxX < 0 { x0 = 0; y0 = 0; w = 1; h = 1; pixels = [transparent] }       // nothing changed
            else {
                x0 = minX; y0 = minY; w = maxX - minX + 1; h = maxY - minY + 1
                pixels = [UInt8](repeating: 0, count: w * h)
                for y in 0..<h { for x in 0..<w {
                    let i = (y0 + y) * width + x0 + x
                    pixels[y * w + x] = indices[i] == prev[i] ? transparent : indices[i]
                } }
            }
        }
        var d = Data([0x21, 0xF9, 4, previous == nil ? 0x04 : 0x05]) + le(delay) + [transparent, 0]   // keep earlier pixels
        d += [0x2C] + le(x0) + le(y0) + le(w) + le(h) + [0]
        d += [8]
        let packed = Self.lzw(pixels)
        var i = 0
        while i < packed.count { let n = min(255, packed.count - i); d.append(UInt8(n)); d += packed[i..<i + n]; i += n }
        d.append(0)
        emit(d)
        previous = indices
    }

    func finish() { emit(Data([0x3B])) }

    /// GIF's variant of LZW with 8-bit symbols.
    static func lzw(_ pixels: [UInt8]) -> [UInt8] {
        let clear = 256, end = 257
        var out = [UInt8](); out.reserveCapacity(pixels.count / 3)
        var bits: UInt32 = 0, nbits = 0
        var codeSize = 9, next = 258
        var table = [Int32](repeating: -1, count: 4096 * 256)
        func put(_ code: Int) {
            bits |= UInt32(code) << UInt32(nbits); nbits += codeSize
            while nbits >= 8 { out.append(UInt8(bits & 255)); bits >>= 8; nbits -= 8 }
        }
        func emitCode(_ code: Int) {
            put(code)
            if next > (1 << codeSize) - 1 && codeSize < 12 { codeSize += 1 }
        }
        put(clear)
        guard var cur = pixels.first.map(Int.init) else { put(end); if nbits > 0 { out.append(UInt8(bits)) }; return out }
        for k in 1..<pixels.count {
            let p = Int(pixels[k])
            let hit = table[cur << 8 | p]
            if hit >= 0 { cur = Int(hit); continue }
            emitCode(cur)
            if next < 4096 { table[cur << 8 | p] = Int32(next); next += 1 }
            else {
                put(clear)
                for i in table.indices { table[i] = -1 }
                next = 258; codeSize = 9
            }
            cur = p
        }
        emitCode(cur)
        put(end)
        if nbits > 0 { out.append(UInt8(bits & 255)) }
        return out
    }
}
