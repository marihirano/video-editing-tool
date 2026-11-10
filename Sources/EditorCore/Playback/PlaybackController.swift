import AVFoundation
import Combine

/// Plays the source video silently and hands out decoded frames for the preview to draw.
///
/// Follows the timeline's TimeMap while playing: starts at the trim, jumps over cuts,
/// changes speed for sped-up parts and stops at the end of the trim, so the preview
/// plays what the export will contain.
@MainActor
public final class PlaybackController: ObservableObject {
    @Published public private(set) var isPlaying = false
    /// Current position in the recording (source seconds).
    @Published public private(set) var currentTime: Double = 0
    /// Length of the recording (source seconds).
    @Published public private(set) var duration: Double = 0

    /// How the edits map the recording onto the finished video. Set by the editor on every edit.
    public var timeMap: TimeMap? {
        didSet { if oldValue?.pieces != timeMap?.pieces { installBoundaries(); if isPlaying { followTimeline() } } }
    }

    public let player = AVPlayer()
    private var videoOutput: AVPlayerItemVideoOutput?
    private var timeObserver: Any?
    private var boundaryObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var lastFrame: (buffer: CVPixelBuffer, time: Double)?

    public init() {
        player.isMuted = true                 // no sound in v1
        player.actionAtItemEnd = .pause
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = t.seconds
                if self.isPlaying { self.followTimeline() }
            }
        }
    }

    // MARK: Output (finished-video) clock

    /// Current position in the finished video, in seconds.
    public var outputTime: Double { timeMap?.outputTime(forSource: currentTime) ?? currentTime }
    public var outputDuration: Double { timeMap?.outputDuration ?? duration }

    public func seek(toOutput t: Double) {
        seek(to: timeMap?.sourceTime(forOutput: t) ?? t)
    }

    // MARK: Loading and transport

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
        isPlaying = false
        seek(to: timeMap?.firstSourceTime ?? 0)
    }

    public func togglePlay() { isPlaying ? pause() : play() }

    public func play() {
        guard player.currentItem != nil else { return }
        let map = timeMap
        // At the end (or past the trim): start over from the beginning of the video.
        if let map, map.piece(atSource: currentTime) == nil { seek(to: map.firstSourceTime) }
        else if map == nil, currentTime >= duration - 0.05 { seek(to: 0) }
        isPlaying = true
        followTimeline()
        if map == nil { player.play() }
    }

    public func pause() {
        player.pause()
        isPlaying = false
    }

    /// Jumps to a moment in the recording (source seconds). Allowed anywhere, even inside a cut,
    /// so the timeline can show removed parts; playing from there skips ahead.
    public func seek(to seconds: Double) {
        let s = min(max(seconds, 0), max(duration, 0))
        currentTime = s
        player.seek(to: CMTime(seconds: s, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// While playing: skip removed parts, use the right speed, stop at the end.
    private func followTimeline() {
        guard isPlaying, let map = timeMap else { return }
        guard let piece = map.piece(atSource: currentTime) else {
            pause()
            seek(to: map.lastSourceTime)
            return
        }
        if currentTime < piece.source.start - 0.001 { seek(to: piece.source.start) }
        let rate = Float(piece.rate)
        if player.rate != rate { player.rate = rate }
    }

    /// Exact-time callbacks at the end of every kept piece, so cuts are jumped over promptly
    /// (the regular 60-a-second check alone could show a few removed frames at high speed).
    private func installBoundaries() {
        if let boundaryObserver { player.removeTimeObserver(boundaryObserver) }
        boundaryObserver = nil
        guard let map = timeMap else { return }
        let times = map.pieces.map { NSValue(time: CMTime(seconds: $0.source.end, preferredTimescale: 600)) }
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: times, queue: .main) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return }
                self.currentTime = self.player.currentTime().seconds
                self.followTimeline()
            }
        }
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
