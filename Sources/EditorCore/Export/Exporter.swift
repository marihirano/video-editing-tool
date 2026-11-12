import AVFoundation

/// Renders the project frame by frame through the shared FrameRenderer and writes an MP4
/// (Apple-silicon hardware encoder) or a GIF. Silent: no audio track in v1.
public final class Exporter: @unchecked Sendable {

    public enum ExportError: LocalizedError {
        case noGPU, cannotRead(String), cannotWrite(String)
        public var errorDescription: String? {
            switch self {
            case .noGPU: return "This Mac's graphics chip couldn't be used."
            case .cannotRead(let why): return "The video couldn't be read. \(why)"
            case .cannotWrite(let why): return "The file couldn't be written. \(why)"
            }
        }
    }

    private let lock = NSLock()
    private var cancelled = false
    /// True when the last MP4 export used the hardware encoder.
    public private(set) var usedHardwareEncoder = false

    public init() {}

    public func cancel() { lock.withLock { cancelled = true } }
    var isCancelled: Bool { lock.withLock { cancelled } }

    /// The project with the chosen format's size and frame rate filled into `output`.
    static func effective(_ project: Project) -> Project {
        var p = project
        if p.output.format == .gif {
            p.output.width = p.output.gifSize.width; p.output.height = p.output.gifSize.height; p.output.fps = p.output.gifFPS
        }
        return p
    }

    func makeJob(project: Project, sourceURL: URL) async throws -> RenderJob {
        let info = try await VideoInfo.load(sourceURL)
        let asset = AVURLAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw VideoInfo.LoadError.noVideoTrack }
        return try RenderJob(project: Self.effective(project), info: info, asset: asset, track: track)
    }

    /// Exports (MP4 or GIF, as the project's output says) and reports progress (0–1) on the main
    /// thread. Throws CancellationError if cancelled.
    public func export(project: Project, sourceURL: URL, to outputURL: URL,
                       progress: @escaping @Sendable (Double) -> Void) async throws {
        let job = try await makeJob(project: project, sourceURL: sourceURL)
        try await Task.detached(priority: .userInitiated) {
            if job.project.output.format == .gif { try self.runGIF(job, outputURL: outputURL, progress: progress) }
            else { try self.runMP4(job, outputURL: outputURL, progress: progress) }
        }.value
        if isCancelled { throw CancellationError() }
    }

    // MARK: MP4

    private func runMP4(_ job: RenderJob, outputURL: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let output = job.project.output
        let (reader, feeder) = try job.makeReader()

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
        guard writer.startWriting() else { throw ExportError.cannotWrite(writer.error?.localizedDescription ?? "") }
        writer.startSession(atSourceTime: .zero)

        func fail(_ error: Error) -> Error {
            reader.cancelReading(); writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            return error
        }
        guard feeder.hasFrames else { throw fail(ExportError.cannotRead("No frames were found.")) }

        let fps = job.fps, frameCount = job.frameCount
        let timescale = CMTimeScale(output.fps)
        // The GPU draws a few frames ahead while the encoder works on earlier ones.
        var inFlight: [(n: Int, buffer: CVPixelBuffer, cb: MTLCommandBuffer)] = []

        func appendOldest() throws {
            let item = inFlight.removeFirst()
            item.cb.waitUntilCompleted()
            while !input.isReadyForMoreMediaData {
                if isCancelled { throw CancellationError() }
                Thread.sleep(forTimeInterval: 0.001)
            }
            if !adaptor.append(item.buffer, withPresentationTime: CMTime(value: CMTimeValue(item.n), timescale: timescale)) {
                throw ExportError.cannotWrite(writer.error?.localizedDescription ?? "")
            }
        }

        do {
            for n in 0..<frameCount {
                if isCancelled { throw CancellationError() }
                let t = Double(n) / fps
                guard let frame = feeder.frame(atSource: job.sourceTime(forOutput: t), tolerance: 0.5 / fps) else { continue }
                guard let pool = adaptor.pixelBufferPool else { throw ExportError.cannotWrite(writer.error?.localizedDescription ?? "No buffer pool.") }
                var out: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
                guard let out else { throw ExportError.cannotWrite("Couldn't prepare a frame.") }
                inFlight.append((n, out, try job.render(frame: frame, outputTime: t, into: out)))
                if inFlight.count >= Settings.exportFramesInFlight { try appendOldest() }
                if n % 10 == 0 {
                    let p = Double(n) / Double(frameCount)
                    DispatchQueue.main.async { progress(p) }
                }
            }
            while !inFlight.isEmpty { try appendOldest() }
        } catch { throw fail(error) }

        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: timescale))
        reader.cancelReading()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        if writer.status != .completed { throw ExportError.cannotWrite(writer.error?.localizedDescription ?? "") }
        DispatchQueue.main.async { progress(1) }
    }
}
