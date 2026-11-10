import AVFoundation
import Combine

/// Plays the source video silently and hands out decoded frames for the preview to draw.
@MainActor
public final class PlaybackController: ObservableObject {
    @Published public private(set) var isPlaying = false
    /// Current position, in seconds.
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0

    public let player = AVPlayer()
    private var videoOutput: AVPlayerItemVideoOutput?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var lastFrame: (buffer: CVPixelBuffer, time: Double)?

    public init() {
        player.isMuted = true                 // no sound in v1
        player.actionAtItemEnd = .pause
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] t in
            MainActor.assumeIsolated { self?.currentTime = t.seconds }
        }
    }

    public func load(_ info: VideoInfo) {
        let item = AVPlayerItem(asset: AVURLAsset(url: info.url))
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: VideoInfo.decodeSettings)
        item.add(output)
        videoOutput = output
        lastFrame = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isPlaying = false }
        }
        player.replaceCurrentItem(with: item)
        duration = info.duration
        currentTime = 0
        isPlaying = false
    }

    public func togglePlay() { isPlaying ? pause() : play() }

    public func play() {
        guard player.currentItem != nil else { return }
        if currentTime >= duration - 0.05 { seek(to: 0) }   // at the end: start over
        player.play()
        isPlaying = true
    }

    public func pause() {
        player.pause()
        isPlaying = false
    }

    public func seek(to seconds: Double) {
        currentTime = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// The frame that should be on screen right now, plus its source time in seconds.
    /// Keeps returning the last frame while paused, so the preview can redraw on resize.
    public func frameForDisplay() -> (buffer: CVPixelBuffer, time: Double)? {
        guard let output = videoOutput else { return nil }
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        if output.hasNewPixelBuffer(forItemTime: itemTime),
           let buffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
            lastFrame = (buffer, itemTime.seconds)
        }
        return lastFrame
    }
}
