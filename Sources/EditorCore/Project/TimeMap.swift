import Foundation

/// Converts between output time (the finished video) and source time (the recording).
///
/// Preview and export both ask this one place, so trims, cuts and speed-ups are handled
/// the same way in both. All times are seconds from the start of the recording.
public struct TimeMap: Sendable {
    public let sourceDuration: Double
    public let timeline: Timeline

    /// One stretch of the recording that ends up in the video, played at one speed.
    public struct Piece: Sendable, Equatable {
        public let source: TimeRange
        public let rate: Double
        /// Where this piece starts in the finished video.
        public let outputStart: Double
        public var outputDuration: Double { (source.end - source.start) / rate }
    }

    /// The kept stretches, in order. Never empty.
    public let pieces: [Piece]

    public init(project: Project, sourceDuration: Double) {
        self.init(timeline: project.timeline, sourceDuration: sourceDuration)
    }

    public init(timeline: Timeline, sourceDuration: Double) {
        self.sourceDuration = sourceDuration
        self.timeline = timeline
        let kept = timeline.keptRange(sourceDuration: sourceDuration)
        var marks: Set<Double> = [kept.start, kept.end]
        for c in timeline.cuts { marks.insert(c.start); marks.insert(c.end) }
        for s in timeline.speedSegments { marks.insert(s.range.start); marks.insert(s.range.end) }
        let sorted = marks.filter { $0 >= kept.start && $0 <= kept.end }.sorted()

        var built: [Piece] = []
        var out = 0.0
        for (a, b) in zip(sorted, sorted.dropFirst()) where b - a > 0.0001 {
            let mid = (a + b) / 2
            if timeline.cuts.contains(where: { $0.start <= mid && mid < $0.end }) { continue }
            let rate = max(0.01, timeline.speedSegments.first { $0.range.start <= mid && mid < $0.range.end }?.rate ?? 1)
            // Join with the previous piece when it carries straight on at the same speed.
            if let last = built.last, abs(last.source.end - a) < 0.0001, last.rate == rate {
                built[built.count - 1] = Piece(source: TimeRange(start: last.source.start, end: b), rate: rate, outputStart: last.outputStart)
            } else {
                built.append(Piece(source: TimeRange(start: a, end: b), rate: rate, outputStart: out))
            }
            out += (b - a) / rate
        }
        if built.isEmpty { built = [Piece(source: TimeRange(start: kept.start, end: kept.start), rate: 1, outputStart: 0)] }
        pieces = built
    }

    /// Length of the finished video, in seconds.
    public var outputDuration: Double { pieces.last.map { $0.outputStart + $0.outputDuration } ?? 0 }

    /// First and last source moments that appear in the video.
    public var firstSourceTime: Double { pieces.first!.source.start }
    public var lastSourceTime: Double { pieces.last!.source.end }

    /// Source moment shown at a given output moment. Never goes backwards as output time
    /// moves forwards, which lets export read the source in one pass.
    public func sourceTime(forOutput t: Double) -> Double {
        let t = max(0, t)
        let piece = pieces.last { $0.outputStart <= t } ?? pieces[0]
        return min(piece.source.end, piece.source.start + (t - piece.outputStart) * piece.rate)
    }

    /// Output moment for a source moment. A moment that was cut or trimmed away maps to
    /// where the video carries on after it.
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
