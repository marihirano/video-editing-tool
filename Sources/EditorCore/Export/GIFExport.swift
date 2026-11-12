import AVFoundation

/// A guess at how big the GIF will be, worked out by really drawing and encoding a few moments.
public struct GIFEstimate: Sendable {
    public let bytes: Int
    public let frames: Int
    public let width: Int, height: Int
}

extension Exporter {
    /// Copies of finished frames (BGRA, tightly packed) drawn at a few moments across the video.
    /// Each moment gives a pair: the frame, and the one a GIF-frame later (to see how much moves).
    private func sampleFrames(_ job: RenderJob) throws -> [(a: [UInt8], b: [UInt8])] {
        let output = job.project.output
        let w = output.width, h = output.height, fps = job.fps
        let duration = job.timeMap.outputDuration
        let attrs = EncoderSettings.pixelBuffers(for: output) as CFDictionary
        func grab(_ feeder: FrameFeeder, _ t: Double) throws -> [UInt8]? {
            guard let frame = feeder.frame(atSource: job.sourceTime(forOutput: t), tolerance: 0.5 / fps) else { return nil }
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, attrs, &pb)
            guard let pb else { return nil }
            try job.render(frame: frame, outputTime: t, into: pb).waitUntilCompleted()
            return Self.pixels(of: pb)
        }
        var pairs: [(a: [UInt8], b: [UInt8])] = []
        let count = max(1, min(Settings.gifSampleCount, job.frameCount - 1))
        for i in 0..<count {
            if isCancelled { throw CancellationError() }
            let t = min(duration - 1 / fps, duration * (Double(i) + 0.5) / Double(count))
            let src = job.sourceTime(forOutput: max(0, t))
            let range = CMTimeRange(start: CMTime(seconds: max(job.info.start, src - 1), preferredTimescale: 600),
                                    duration: CMTime(seconds: 1 + 1.5 / fps + 0.2, preferredTimescale: 600))
            let (reader, feeder) = try job.makeReader(timeRange: range)
            defer { reader.cancelReading() }
            guard let a = try grab(feeder, max(0, t)) else { continue }
            let b = try grab(feeder, min(duration, max(0, t) + 1 / fps)) ?? a
            pairs.append((a, b))
        }
        guard !pairs.isEmpty else { throw ExportError.cannotRead("No frames were found.") }
        return pairs
    }

    private static func pixels(of pb: CVPixelBuffer) -> [UInt8] {
        CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), bpr = CVPixelBufferGetBytesPerRow(pb)
        let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
        var out = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h { out.withUnsafeMutableBufferPointer { memcpy($0.baseAddress! + y * w * 4, base + y * bpr, w * 4) } }
        return out
    }

    private static func palette(from pairs: [(a: [UInt8], b: [UInt8])], width: Int, height: Int) -> GIFPalette {
        var builder = GIFPalette.Builder()
        for pair in pairs { pair.a.withUnsafeBufferPointer { builder.add(bgra: $0.baseAddress!, width: width, height: height, bytesPerRow: width * 4) } }
        return builder.build()
    }

    /// Works out the GIF's size by drawing and encoding a few sample moments (takes a second or two).
    public func estimateGIF(project: Project, sourceURL: URL) async throws -> GIFEstimate {
        var p = project; p.output.format = .gif
        let job = try await makeJob(project: p, sourceURL: sourceURL)
        return try await Task.detached(priority: .userInitiated) {
            let w = job.project.output.width, h = job.project.output.height
            let pairs = try self.sampleFrames(job)
            let palette = Self.palette(from: pairs, width: w, height: h)
            var first = 0, delta = 0, header = 0
            for pair in pairs {
                let enc = GIFEncoder(width: w, height: h, palette: palette) { _ in }
                header = enc.bytesWritten
                func idx(_ px: [UInt8]) -> [UInt8] { px.withUnsafeBufferPointer { palette.indices(bgra: $0.baseAddress!, width: w, height: h, bytesPerRow: w * 4, dither: Settings.gifDither) } }
                enc.addFrame(idx(pair.a), delay: 7); first += enc.bytesWritten - header
                let before = enc.bytesWritten
                enc.addFrame(idx(pair.b), delay: 7); delta += enc.bytesWritten - before
            }
            let n = pairs.count
            let frames = job.frameCount
            return GIFEstimate(bytes: header + first / n + (frames - 1) * (delta / n), frames: frames, width: w, height: h)
        }.value
    }

    func runGIF(_ job: RenderJob, outputURL: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let output = job.project.output
        let w = output.width, h = output.height, fps = job.fps, frameCount = job.frameCount

        // Pick the colours from a few moments across the video first.
        let palette = Self.palette(from: try sampleFrames(job), width: w, height: h)

        try? FileManager.default.removeItem(at: outputURL)
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil),
              let file = try? FileHandle(forWritingTo: outputURL) else { throw ExportError.cannotWrite("Couldn't create the file.") }
        defer { try? file.close() }
        var writeError: Error?
        let encoder = GIFEncoder(width: w, height: h, palette: palette) { data in
            do { try file.write(contentsOf: data) } catch { writeError = error }
        }
        let (reader, feeder) = try job.makeReader()
        defer { reader.cancelReading() }
        guard feeder.hasFrames else { throw ExportError.cannotRead("No frames were found.") }

        var poolRef: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, EncoderSettings.pixelBuffers(for: output) as CFDictionary, &poolRef)
        guard let pool = poolRef else { throw ExportError.cannotWrite("Couldn't prepare frames.") }

        var inFlight: [(n: Int, buffer: CVPixelBuffer, cb: MTLCommandBuffer)] = []
        func finishOldest() throws {
            let item = inFlight.removeFirst()
            item.cb.waitUntilCompleted()
            CVPixelBufferLockBaseAddress(item.buffer, .readOnly)
            let base = CVPixelBufferGetBaseAddress(item.buffer)!.assumingMemoryBound(to: UInt8.self)
            let indices = palette.indices(bgra: base, width: w, height: h, bytesPerRow: CVPixelBufferGetBytesPerRow(item.buffer), dither: Settings.gifDither)
            CVPixelBufferUnlockBaseAddress(item.buffer, .readOnly)
            // GIF delays are whole hundredths of a second; spread the rounding so the total length is exact.
            let delay = Int((Double(item.n + 1) * 100 / fps).rounded()) - Int((Double(item.n) * 100 / fps).rounded())
            encoder.addFrame(indices, delay: max(delay, 1))
            if let writeError { throw ExportError.cannotWrite(writeError.localizedDescription) }
        }
        do {
            for n in 0..<frameCount {
                if isCancelled { throw CancellationError() }
                let t = Double(n) / fps
                guard let frame = feeder.frame(atSource: job.sourceTime(forOutput: t), tolerance: 0.5 / fps) else { continue }
                var out: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
                guard let out else { throw ExportError.cannotWrite("Couldn't prepare a frame.") }
                inFlight.append((n, out, try job.render(frame: frame, outputTime: t, into: out)))
                if inFlight.count >= Settings.exportFramesInFlight { try finishOldest() }
                if n % 4 == 0 {
                    let p = Double(n) / Double(frameCount)
                    DispatchQueue.main.async { progress(p) }
                }
            }
            while !inFlight.isEmpty { try finishOldest() }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
        encoder.finish()
        DispatchQueue.main.async { progress(1) }
    }
}
