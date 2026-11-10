import AVFoundation

/// Renders the project frame by frame through the shared FrameRenderer and writes an MP4
/// with the Apple-silicon hardware encoder. Silent: no audio track in v1.
public final class Exporter: @unchecked Sendable {

    public enum ExportError: LocalizedError {
        case noGPU, cannotRead(String), cannotWrite(String)
        public var errorDescription: String? {
            switch self {
            case .noGPU: return "This Mac's graphics chip couldn't be used."
            case .cannotRead(let why): return "The video couldn't be read. \(why)"
            case .cannotWrite(let why): return "The MP4 couldn't be written. \(why)"
            }
        }
    }

    private let lock = NSLock()
    private var cancelled = false
    /// True when the last export used the hardware encoder.
    public private(set) var usedHardwareEncoder = false

    public init() {}

    public func cancel() { lock.withLock { cancelled = true } }
    private var isCancelled: Bool { lock.withLock { cancelled } }

    /// Exports and reports progress (0–1) on the main thread. Throws CancellationError if cancelled.
    public func export(project: Project, sourceURL: URL, to outputURL: URL,
                       progress: @escaping @Sendable (Double) -> Void) async throws {
        let info = try await VideoInfo.load(sourceURL)
        let asset = AVURLAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw VideoInfo.LoadError.noVideoTrack }
        try await Task.detached(priority: .userInitiated) {
            try self.run(project: project, info: info, asset: asset, track: track, outputURL: outputURL, progress: progress)
        }.value
        if isCancelled { throw CancellationError() }
    }

    private func run(project: Project, info: VideoInfo, asset: AVAsset, track: AVAssetTrack,
                     outputURL: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        guard let context = MetalContext.shared else { throw ExportError.noGPU }
        let renderer = FrameRenderer(context: context)
        let output = project.output
        let timeMap = TimeMap(project: project, sourceDuration: info.duration)

        // Reader: decodes source frames in order, straight into GPU-friendly buffers.
        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) } catch { throw ExportError.cannotRead(error.localizedDescription) }
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: VideoInfo.decodeSettings)
        trackOutput.alwaysCopiesSampleData = false
        reader.add(trackOutput)

        // Writer: encodes finished frames to MP4.
        try? FileManager.default.removeItem(at: outputURL)
        let writer: AVAssetWriter
        do { writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4) } catch { throw ExportError.cannotWrite(error.localizedDescription) }
        var settings = EncoderSettings.video(for: output, requireHardware: Settings.exportRequireHardwareEncoder)
        usedHardwareEncoder = Settings.exportRequireHardwareEncoder
        if !writer.canApply(outputSettings: settings, forMediaType: .video) {
            settings = EncoderSettings.video(for: output, requireHardware: false)
            usedHardwareEncoder = false
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                           sourcePixelBufferAttributes: EncoderSettings.pixelBuffers(for: output))
        guard writer.canAdd(input) else { throw ExportError.cannotWrite("The encoder refused the settings.") }
        writer.add(input)

        guard reader.startReading() else { throw ExportError.cannotRead(reader.error?.localizedDescription ?? "") }
        guard writer.startWriting() else { throw ExportError.cannotWrite(writer.error?.localizedDescription ?? "") }
        writer.startSession(atSourceTime: .zero)

        func fail(_ error: Error) -> Error {
            reader.cancelReading(); writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            return error
        }

        // Walk the output clock; for each output frame, show the latest source frame at or
        // before the matching source time. TimeMap never goes backwards, so one pass is enough.
        let fps = Double(output.fps)
        let frameCount = max(1, Int((timeMap.outputDuration * fps).rounded()))
        var current = trackOutput.copyNextSampleBuffer()
        var next = trackOutput.copyNextSampleBuffer()
        guard current != nil else { throw fail(ExportError.cannotRead("No frames were found.")) }
        let halfFrame = 0.5 / fps

        for n in 0..<frameCount {
            if isCancelled { _ = fail(CancellationError()); return }
            let sourceTime = info.start + timeMap.sourceTime(forOutput: Double(n) / fps)
            while let candidate = next, candidate.presentationTimeStamp.seconds <= sourceTime + halfFrame {
                current = candidate
                next = trackOutput.copyNextSampleBuffer()
            }
            guard let sample = current, let frame = sample.imageBuffer else { continue }

            while !input.isReadyForMoreMediaData {
                if isCancelled { _ = fail(CancellationError()); return }
                Thread.sleep(forTimeInterval: 0.002)
            }
            guard let pool = adaptor.pixelBufferPool else { throw fail(ExportError.cannotWrite(writer.error?.localizedDescription ?? "No buffer pool.")) }
            var outBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuffer)
            guard let outBuffer, let (target, targetRef) = renderer.texture(for: outBuffer, asTarget: true),
                  let cb = renderer.makeCommandBuffer() else { throw fail(ExportError.cannotWrite("Couldn't prepare a frame.")) }

            let size = CGSize(width: CVPixelBufferGetWidth(frame), height: CVPixelBufferGetHeight(frame))
            let uniforms = FrameLayout.uniforms(project: project, sourceSize: size,
                                                sourceTime: sample.presentationTimeStamp.seconds - info.start)
            renderer.encode(frame: frame, uniforms: uniforms, backgroundImagePath: project.style.kind == .image ? project.style.imagePath : nil, into: target, commandBuffer: cb)
            cb.commit()
            cb.waitUntilCompleted()
            _ = targetRef

            if !adaptor.append(outBuffer, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: CMTimeScale(output.fps))) {
                throw fail(ExportError.cannotWrite(writer.error?.localizedDescription ?? ""))
            }
            if n % 10 == 0 {
                let p = Double(n) / Double(frameCount)
                DispatchQueue.main.async { progress(p) }
            }
        }

        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(output.fps)))
        reader.cancelReading()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        if writer.status != .completed { throw ExportError.cannotWrite(writer.error?.localizedDescription ?? "") }
        DispatchQueue.main.async { progress(1) }
    }
}
