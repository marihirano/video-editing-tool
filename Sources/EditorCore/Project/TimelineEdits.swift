import Foundation

/// The edit operations behind the timeline buttons. All times are source seconds.
/// Each one leaves the timeline tidy: cuts sorted and merged, speed parts sorted and not overlapping.
extension Timeline {

    /// Kept part of the recording (the trim, or everything).
    public func keptRange(sourceDuration d: Double) -> TimeRange {
        guard let t = trim else { return TimeRange(start: 0, end: d) }
        return TimeRange(start: max(0, min(t.start, d)), end: max(0, min(t.end, d)))
    }

    /// Sets the trim. A trim covering the whole recording is stored as "no trim".
    public mutating func setTrim(start: Double, end: Double, sourceDuration d: Double) {
        let s = max(0, min(start, d)), e = max(0, min(end, d))
        guard e - s >= Settings.minimumKeptSeconds else { return }
        trim = (s <= 0.0005 && e >= d - 0.0005) ? nil : TimeRange(start: s, end: e)
    }

    /// Removes a section from the middle.
    public mutating func addCut(_ r: TimeRange) {
        guard r.end - r.start > 0.0005 else { return }
        cuts = Self.merge(cuts + [r])
    }

    /// Plays a section at `rate` (1 = normal speed, which removes any speed-up there).
    public mutating func setSpeed(_ r: TimeRange, rate: Double) {
        guard r.end - r.start > 0.0005 else { return }
        var kept: [SpeedSegment] = []
        for seg in speedSegments {
            for piece in Self.subtract(seg.range, r) { kept.append(SpeedSegment(range: piece, rate: seg.rate)) }
        }
        if abs(rate - 1) > 0.0001 { kept.append(SpeedSegment(range: r, rate: rate)) }
        speedSegments = kept.sorted { $0.range.start < $1.range.start }
    }

    /// Undoes cuts and speed-ups inside a section, so it plays normally again.
    public mutating func clearEdits(in r: TimeRange) {
        cuts = cuts.flatMap { Self.subtract($0, r) }
        setSpeed(r, rate: 1)
    }

    // MARK: Range helpers

    static func merge(_ ranges: [TimeRange]) -> [TimeRange] {
        var out: [TimeRange] = []
        for r in ranges.sorted(by: { $0.start < $1.start }) {
            if let last = out.last, r.start <= last.end + 0.0005 {
                out[out.count - 1].end = max(last.end, r.end)
            } else { out.append(r) }
        }
        return out
    }

    /// `a` with `b` taken out: zero, one or two pieces.
    static func subtract(_ a: TimeRange, _ b: TimeRange) -> [TimeRange] {
        if b.end <= a.start || b.start >= a.end { return [a] }
        var out: [TimeRange] = []
        if b.start - a.start > 0.0005 { out.append(TimeRange(start: a.start, end: b.start)) }
        if a.end - b.end > 0.0005 { out.append(TimeRange(start: b.end, end: a.end)) }
        return out
    }
}
