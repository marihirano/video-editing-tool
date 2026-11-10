import AVFoundation

/// Small pictures spread evenly across the recording, for the timeline strip.
public enum Thumbnails {
    /// `count` images, evenly spaced; each slot is `nil` if that frame couldn't be read.
    public static func generate(url: URL, duration: Double, count: Int, maxHeight: Double) async -> [CGImage?] {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: maxHeight * 4, height: maxHeight)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        let times = (0..<count).map { CMTime(seconds: duration * (Double($0) + 0.5) / Double(count), preferredTimescale: 600) }
        var images = [CGImage?](repeating: nil, count: count)
        for await result in gen.images(for: times) {
            if let i = times.firstIndex(of: result.requestedTime), let img = try? result.image { images[i] = img }
        }
        return images
    }
}
