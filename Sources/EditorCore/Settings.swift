import CoreGraphics
import Foundation

/// Every tunable value in the app lives here, so tuning never means hunting through code.
public enum Settings {

    // MARK: Project files
    /// Extension of the project package (a folder that Finder shows as one file).
    public static let projectExtension = "vetproj"
    /// Uniform type id declared in the app's Info.plist for project packages.
    public static let projectTypeIdentifier = "com.marihirano.video-editing-tool.project"
    /// Name of the edits file inside the project package.
    public static let projectFileName = "project.json"
    /// Version written into project.json, bumped when the format changes.
    public static let projectFormatVersion = 1

    // MARK: Output canvas (the size of the exported video)
    public static let defaultOutputWidth = 1920
    public static let defaultOutputHeight = 1080
    public static let defaultOutputFPS = 60

    // MARK: Look
    /// Colour around the video when its shape doesn't match the canvas (RGBA, 0–1).
    public static let defaultBackground = RGBAColor(r: 0, g: 0, b: 0, a: 1)
    /// Colour of the app window behind the preview.
    public static let previewSurround = RGBAColor(r: 0.11, g: 0.11, b: 0.12, a: 1)

    // MARK: Preview
    public static let previewMaxFPS = 60

    // MARK: Export
    /// Video bitrate in bits per second per million output pixels. Screen content has
    /// sharp text, so this is generous: about 16 Mbit/s at 1080p.
    public static let exportBitsPerMegapixel: Double = 7_700_000
    /// Seconds between keyframes in the exported MP4.
    public static let exportKeyframeIntervalSeconds: Double = 2
    /// Try the Apple-silicon hardware encoder first; fall back to software only if it refuses.
    public static let exportRequireHardwareEncoder = true
}

/// A colour with red, green, blue and alpha from 0 to 1.
public struct RGBAColor: Codable, Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}
