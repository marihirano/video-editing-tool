import AVFoundation

/// Basic facts about a video file, read before playing or exporting it.
public struct VideoInfo: Sendable {
    public let url: URL
    public let width: Int
    public let height: Int
    /// Seconds of video, measured on the video track.
    public let duration: Double
    /// When the video track starts, in seconds (almost always 0).
    public let start: Double

    public enum LoadError: LocalizedError {
        case noVideoTrack
        public var errorDescription: String? { "This file doesn't contain any video." }
    }

    public static func load(_ url: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw LoadError.noVideoTrack
        }
        let (size, range) = try await track.load(.naturalSize, .timeRange)
        return VideoInfo(url: url, width: Int(size.width.rounded()), height: Int(size.height.rounded()),
                         duration: range.duration.seconds, start: range.start.seconds)
    }

    public var sourceVideo: SourceVideo {
        SourceVideo(path: url.path, width: width, height: height, duration: duration)
    }

    /// Settings that make AVFoundation decode frames straight into GPU-friendly BGRA buffers.
    static let decodeSettings: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
    ]
}
