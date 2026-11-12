import AVFoundation
import CoreGraphics

/// Grabs one still picture of the recording (for the zoom's "where it points" picker),
/// cropped the same way as the video.
enum FrameStill {
    /// - Parameters:
    ///   - time: recording moment in seconds.
    ///   - crop: part to keep, as fractions of the frame (0–1, from the top-left).
    static func image(url: URL, time: Double, crop: CGRect, maxWidth: CGFloat = 640) async -> CGImage? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = false   // same as the renderer (no rotation)
        gen.maximumSize = CGSize(width: maxWidth / max(crop.width, 0.1), height: 0)
        gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
        gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
        guard let (img, _) = try? await gen.image(at: CMTime(seconds: time, preferredTimescale: 600)) else { return nil }
        let w = CGFloat(img.width), h = CGFloat(img.height)
        let r = CGRect(x: crop.minX * w, y: crop.minY * h, width: crop.width * w, height: crop.height * h).integral
        return img.cropping(to: r) ?? img
    }
}
