import Foundation

/// Converts between output time (the finished video) and source time (the recording).
///
/// Preview and export both ask this one place, so clips and speed changes are handled
/// the same way in both. Source times are seconds from the start of the recording.
public struct TimeMap: Sendable {
    public let sourceDuration: Double

    /// One clip, placed on the finished video's clock.
    public struct Piece: Sendable, Equatable {
        public let source: TimeRange
        public let rate: Double
        /// Where this piece starts in the finished video.
        public let outputStart: Double
        public var outputDuration: Double { (source.end - source.start) / rate }
        public var outputEnd: Double { outputStart + outputDuration }
    }

    /// The clips, in order. Never empty.
    public let pieces: [Piece]

    public init(project: Project, sourceDuration: Double) {
        self.init(timeline: project.timeline, sourceDuration: sourceDuration)
    }

    public init(timeline: Timeline, sourceDuration: Double) {
        self.sourceDuration = sourceDuration
        var out = 0.0
        pieces = timeline.resolvedClips(sourceDuration: sourceDuration).map { c in
            defer { out += c.outputDuration }
            return Piece(source: TimeRange(start: c.start, end: c.end), rate: c.rate, outputStart: out)
        }
    }

    /// Length of the finished video, in seconds.
    public var outputDuration: Double { pieces.last?.outputEnd ?? 0 }

    /// First and last source moments that appear in the video.
    public var firstSourceTime: Double { pieces.first!.source.start }
    public var lastSourceTime: Double { pieces.last!.source.end }

    /// Which clip is playing at an output moment.
    public func pieceIndex(atOutput t: Double) -> Int {
        pieces.lastIndex { $0.outputStart <= t } ?? 0
    }

    /// Source moment shown at a given output moment. Never goes backwards as output time
    /// moves forwards (clips are kept in recording order), which lets export read the source in one pass.
    public func sourceTime(forOutput t: Double) -> Double {
        let piece = pieces[pieceIndex(atOutput: max(0, t))]
        return min(piece.source.end, piece.source.start + (max(0, t) - piece.outputStart) * piece.rate)
    }

    /// Output moment for a source moment. A moment that was deleted maps to where the video carries on after it.
    public func outputTime(forSource s: Double) -> Double {
        for p in pieces {
            if s < p.source.start { return p.outputStart }
            if s <= p.source.end { return p.outputStart + (s - p.source.start) / p.rate }
        }
        return outputDuration
    }

    /// The piece playing at a source moment, or the next one if that moment was removed.
    /// `nil` once past the end of the video.
    public func piece(atSource s: Double) -> Piece? {
        pieces.first { s < $0.source.end - 0.0005 }
    }
}
