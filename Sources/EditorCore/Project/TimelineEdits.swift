import Foundation

/// The edit operations behind the timeline: split, delete, change speed.
/// Clip numbers refer to `resolvedClips` (the clips as shown on the timeline, in order).
extension Timeline {

    /// The clips in the video. Fills in "the whole recording" when nothing has been edited,
    /// and converts files from the first M3 build (trim, cuts, speed parts).
    public func resolvedClips(sourceDuration d: Double) -> [Clip] {
        let source = clips.isEmpty ? legacyClips(sourceDuration: d) : clips
        let clamped = source.compactMap { c -> Clip? in
            let s = max(0, min(c.start, d)), e = max(0, min(c.end, d))
            return e - s > 0.0001 ? Clip(start: s, end: e, rate: max(0.01, c.rate)) : nil
        }
        return clamped.isEmpty ? [Clip(start: 0, end: max(d, 0))] : clamped
    }

    /// Splits the clip under output moment `t` into two. Returns false if `t` is too close
    /// to an existing edge (or outside the video).
    @discardableResult
    public mutating func split(atOutput t: Double, sourceDuration d: Double) -> Bool {
        var list = resolvedClips(sourceDuration: d)
        var outStart = 0.0
        for (i, c) in list.enumerated() {
            let outEnd = outStart + c.outputDuration
            if t > outStart + Settings.minimumClipSeconds && t < outEnd - Settings.minimumClipSeconds {
                let s = c.start + (t - outStart) * c.rate
                list[i].end = s
                list.insert(Clip(start: s, end: c.end, rate: c.rate), at: i + 1)
                setClips(list)
                return true
            }
            outStart = outEnd
        }
        return false
    }

    /// Removes a clip from the video. The last remaining clip can't be deleted.
    public mutating func deleteClip(_ i: Int, sourceDuration d: Double) {
        var list = resolvedClips(sourceDuration: d)
        guard list.count > 1, list.indices.contains(i) else { return }
        list.remove(at: i)
        setClips(list)
    }

    /// Plays a clip at `rate` (1 = normal speed).
    public mutating func setRate(_ rate: Double, ofClip i: Int, sourceDuration d: Double) {
        var list = resolvedClips(sourceDuration: d)
        guard list.indices.contains(i), rate > 0 else { return }
        list[i].rate = rate
        setClips(list)
    }

    /// Output-time start of each clip, and the total length.
    public func clipLayout(sourceDuration d: Double) -> (starts: [Double], total: Double) {
        var starts: [Double] = [], t = 0.0
        for c in resolvedClips(sourceDuration: d) { starts.append(t); t += c.outputDuration }
        return (starts, t)
    }

    private mutating func setClips(_ list: [Clip]) {
        clips = list
        legacyTrim = nil; legacyCuts = []; legacySpeedSegments = []
    }

    /// Clips equivalent to an old-style trim + cuts + speed parts.
    private func legacyClips(sourceDuration d: Double) -> [Clip] {
        let kept = legacyTrim.map { TimeRange(start: max(0, $0.start), end: min(d, $0.end)) } ?? TimeRange(start: 0, end: d)
        var marks: Set<Double> = [kept.start, kept.end]
        for c in legacyCuts { marks.insert(c.start); marks.insert(c.end) }
        for s in legacySpeedSegments { marks.insert(s.range.start); marks.insert(s.range.end) }
        let sorted = marks.filter { $0 >= kept.start && $0 <= kept.end }.sorted()
        var out: [Clip] = []
        for (a, b) in zip(sorted, sorted.dropFirst()) where b - a > 0.0001 {
            let mid = (a + b) / 2
            if legacyCuts.contains(where: { $0.start <= mid && mid < $0.end }) { continue }
            let rate = legacySpeedSegments.first { $0.range.start <= mid && mid < $0.range.end }?.rate ?? 1
            if let last = out.last, abs(last.end - a) < 0.0001, last.rate == rate { out[out.count - 1].end = b }
            else { out.append(Clip(start: a, end: b, rate: rate)) }
        }
        return out
    }
}
