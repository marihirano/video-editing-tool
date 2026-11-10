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
    /// Plain colour used when the background is "Color" (RGBA, 0–1).
    public static let defaultBackground = RGBAColor(r: 0.09, g: 0.09, b: 0.11, a: 1)
    /// Which background a new project starts with, and which built-in one.
    public static let defaultBackgroundKind = BackgroundKind.wallpaper
    public static let defaultWallpaper = 0
    public static let defaultGradient = 2

    /// Space around the video, as a percentage of the canvas height (same on all sides).
    public static let defaultPadding = 8.0
    public static let paddingRange = 0.0...25.0
    /// Rounded-corner size, in pixels on a 1080-tall canvas (scales with the output size).
    public static let defaultCornerRadius = 14.0
    public static let cornerRadiusRange = 0.0...60.0
    /// Drop shadow. Blur and distance are in pixels on a 1080-tall canvas.
    public static let defaultShadowOpacity = 0.45
    public static let shadowOpacityRange = 0.0...1.0
    public static let defaultShadowBlur = 40.0
    public static let shadowBlurRange = 0.0...120.0
    public static let defaultShadowOffset = 16.0
    public static let shadowOffsetRange = 0.0...60.0
    /// Direction used when a gradient is picked from a swatch (degrees, 180 = top to bottom).
    public static let defaultGradientAngle = 135.0

    /// Built-in gradients (original colour pairs).
    public static let gradients: [GradientPreset] = [
        .init(name: "Sunrise", start: RGBAColor(hex: 0xF6D365), end: RGBAColor(hex: 0xFD8A6B), angle: 135),
        .init(name: "Ocean", start: RGBAColor(hex: 0x1E5AA8), end: RGBAColor(hex: 0x5FD3E8), angle: 135),
        .init(name: "Violet", start: RGBAColor(hex: 0x5B5BE0), end: RGBAColor(hex: 0x9B4FC7), angle: 135),
        .init(name: "Mint", start: RGBAColor(hex: 0x0F8F7E), end: RGBAColor(hex: 0x6EE59A), angle: 135),
        .init(name: "Slate", start: RGBAColor(hex: 0x1E2024), end: RGBAColor(hex: 0x4A4F58), angle: 135),
        .init(name: "Blush", start: RGBAColor(hex: 0xE8A0B4), end: RGBAColor(hex: 0xFBE3E8), angle: 135),
    ]

    /// Built-in wallpapers: soft blends of four colours, drawn by the shader (no image files).
    public static let wallpapers: [WallpaperPreset] = [
        .init(name: "Aurora", colors: [RGBAColor(hex: 0x0B1026), RGBAColor(hex: 0x3EE6B0), RGBAColor(hex: 0x7A5CFF), RGBAColor(hex: 0x2A7BFF)]),
        .init(name: "Dusk", colors: [RGBAColor(hex: 0x2B1B4E), RGBAColor(hex: 0xFF7E67), RGBAColor(hex: 0xC84B9B), RGBAColor(hex: 0x5B3FA8)]),
        .init(name: "Meadow", colors: [RGBAColor(hex: 0x0F3B2E), RGBAColor(hex: 0x7BD88F), RGBAColor(hex: 0xE8F5A3), RGBAColor(hex: 0x1F7A6B)]),
        .init(name: "Ember", colors: [RGBAColor(hex: 0x1A0F1F), RGBAColor(hex: 0xFF5F3D), RGBAColor(hex: 0xFFB347), RGBAColor(hex: 0xB8325A)]),
    ]
    /// Colour of the app window behind the preview.
    public static let previewSurround = RGBAColor(r: 0.11, g: 0.11, b: 0.12, a: 1)

    // MARK: Preview
    public static let previewMaxFPS = 60

    // MARK: Timeline
    /// Speed-ups offered in the Speed menu (a custom value can also be typed in).
    public static let speedPresets: [Double] = [2, 4, 8]
    public static let customSpeedRange = 1.1...32.0
    /// Shortest video the trim handles allow, in seconds.
    public static let minimumKeptSeconds = 0.2
    /// Thumbnails generated across the recording for the timeline strip.
    public static let timelineThumbnailCount = 40
    /// Height of the timeline track, in points.
    public static let timelineTrackHeight: Double = 56
    /// Slider drags and handle drags closer together than this count as one undo step.
    public static let undoCoalesceSeconds = 0.6
    /// How many edits Undo remembers.
    public static let undoLimit = 200

    // MARK: Export
    /// Video bitrate in bits per second per million output pixels. Screen content has
    /// sharp text, so this is generous: about 16 Mbit/s at 1080p.
    public static let exportBitsPerMegapixel: Double = 7_700_000
    /// Seconds between keyframes in the exported MP4.
    public static let exportKeyframeIntervalSeconds: Double = 2
    /// Try the Apple-silicon hardware encoder first; fall back to software only if it refuses.
    public static let exportRequireHardwareEncoder = true
}

public struct GradientPreset: Sendable {
    public let name: String
    public let start: RGBAColor, end: RGBAColor
    public let angle: Double
}

public struct WallpaperPreset: Sendable {
    public let name: String
    /// Four colours, placed at the top-left, top-right, bottom-left and bottom-right.
    public let colors: [RGBAColor]
}

/// A colour with red, green, blue and alpha from 0 to 1.
public struct RGBAColor: Codable, Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(hex: UInt32) {
        self.init(r: Double((hex >> 16) & 255) / 255, g: Double((hex >> 8) & 255) / 255,
                  b: Double(hex & 255) / 255, a: 1)
    }
    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}
