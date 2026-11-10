import Foundation

/// Everything the user has done to one recording. Saved as `project.json`.
///
/// M1 only uses `source` and `output`. The other parts are here, empty, so later
/// milestones add features without changing the file format.
public struct Project: Codable, Equatable, Sendable {
    public var version: Int = Settings.projectFormatVersion
    public var source: SourceVideo
    public var output: OutputSettings = .init()
    public var timeline: Timeline = .init()
    /// Part of the source to keep, in source pixels. `nil` means the whole frame (M4).
    public var crop: CropRect? = nil
    public var style: FrameStyle = .init()
    /// Cursor positions and clicks from in-app recording (phase 2). Never shown in the MVP.
    public var cursor: CursorTrack = .init()

    public init(source: SourceVideo) { self.source = source }

    enum CodingKeys: String, CodingKey { case version, source, output, timeline, crop, style, cursor }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Settings.projectFormatVersion
        source = try c.decode(SourceVideo.self, forKey: .source)
        output = try c.decodeIfPresent(OutputSettings.self, forKey: .output) ?? .init()
        timeline = try c.decodeIfPresent(Timeline.self, forKey: .timeline) ?? .init()
        crop = try c.decodeIfPresent(CropRect.self, forKey: .crop)
        style = try c.decodeIfPresent(FrameStyle.self, forKey: .style) ?? .init()
        cursor = try c.decodeIfPresent(CursorTrack.self, forKey: .cursor) ?? .init()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(source, forKey: .source)
        try c.encode(output, forKey: .output)
        try c.encode(timeline, forKey: .timeline)
        try c.encode(crop, forKey: .crop)   // written as null when empty
        try c.encode(style, forKey: .style)
        try c.encode(cursor, forKey: .cursor)
    }
}

/// Where the original video lives. The video is never copied into the project.
public struct SourceVideo: Codable, Equatable, Sendable {
    /// Absolute path when the project was saved.
    public var path: String
    /// Path relative to the project package, so moving both together keeps working.
    public var relativePath: String?
    /// macOS bookmark (base64), which follows the file if it's renamed or moved.
    public var bookmark: String?
    /// Source size in pixels and duration in seconds, for display before loading.
    public var width: Int
    public var height: Int
    public var duration: Double

    public init(path: String, relativePath: String? = nil, bookmark: String? = nil,
                width: Int, height: Int, duration: Double) {
        self.path = path; self.relativePath = relativePath; self.bookmark = bookmark
        self.width = width; self.height = height; self.duration = duration
    }
}

/// Size and frame rate of the exported video. A setting from day one, so other
/// aspect ratios are cheap to add later.
public struct OutputSettings: Codable, Equatable, Sendable {
    public var width: Int = Settings.defaultOutputWidth
    public var height: Int = Settings.defaultOutputHeight
    public var fps: Int = Settings.defaultOutputFPS
    public init() {}
}

/// Edits over time. All empty in M1; M3 and M4 fill them in.
public struct Timeline: Codable, Equatable, Sendable {
    /// Start and end of the kept part, in source seconds. `nil` = keep everything.
    public var trim: TimeRange? = nil
    public var cuts: [TimeRange] = []
    public var speedSegments: [SpeedSegment] = []
    public var zooms: [ZoomSegment] = []
    /// Room for sound later. v1 is silent.
    public var audioTracks: [AudioTrack] = []
    public init() {}

    enum CodingKeys: String, CodingKey { case trim, cuts, speedSegments, zooms, audioTracks }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trim = try c.decodeIfPresent(TimeRange.self, forKey: .trim)
        cuts = try c.decodeIfPresent([TimeRange].self, forKey: .cuts) ?? []
        speedSegments = try c.decodeIfPresent([SpeedSegment].self, forKey: .speedSegments) ?? []
        zooms = try c.decodeIfPresent([ZoomSegment].self, forKey: .zooms) ?? []
        audioTracks = try c.decodeIfPresent([AudioTrack].self, forKey: .audioTracks) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(trim, forKey: .trim)
        try c.encode(cuts, forKey: .cuts)
        try c.encode(speedSegments, forKey: .speedSegments)
        try c.encode(zooms, forKey: .zooms)
        try c.encode(audioTracks, forKey: .audioTracks)
    }
}

public struct TimeRange: Codable, Equatable, Sendable {
    public var start: Double, end: Double
    public init(start: Double, end: Double) { self.start = start; self.end = end }
}

public struct SpeedSegment: Codable, Equatable, Sendable {
    public var range: TimeRange
    public var rate: Double
}

public struct ZoomSegment: Codable, Equatable, Sendable {
    public var range: TimeRange
    /// Point to zoom towards, 0–1 across the (cropped) frame.
    public var centerX: Double, centerY: Double
    public var scale: Double
}

public struct AudioTrack: Codable, Equatable, Sendable {
    public var name: String
}

public struct CropRect: Codable, Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
}

/// The frame around the video (M2 adds padding, corners, shadow and wallpapers).
public struct FrameStyle: Codable, Equatable, Sendable {
    public var background: RGBAColor = Settings.defaultBackground
    public init() {}
}

/// Empty slot for phase 2's cursor data.
public struct CursorTrack: Codable, Equatable, Sendable {
    public var samples: [CursorSample] = []
    public var clicks: [CursorClick] = []
    public init() {}
}

public struct CursorSample: Codable, Equatable, Sendable {
    public var time: Double, x: Double, y: Double
}

public struct CursorClick: Codable, Equatable, Sendable {
    public var time: Double, x: Double, y: Double
}
