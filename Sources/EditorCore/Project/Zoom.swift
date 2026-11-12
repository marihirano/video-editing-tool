import CoreGraphics
import Foundation

/// The spring-like easing used for zooming in and out.
public enum Spring {
    /// Progress (0 → 1) at `p`, the fraction of the transition that has passed (0–1).
    /// Starts at rest like a real spring, moves quickly, then settles. With `bounce` above 0 it
    /// briefly goes past 1 before settling. Always exactly 0 at p = 0 and 1 at p = 1.
    public static func value(_ p: Double, bounce: Double) -> Double {
        let p = min(max(p, 0), 1)
        return raw(p, bounce: bounce) + (1 - raw(1, bounce: bounce)) * p
    }

    /// Step response of a damped spring, scaled so the transition length is 1.
    private static func raw(_ p: Double, bounce: Double) -> Double {
        let zeta = 1 - min(max(bounce, 0), 1) * (1 - Settings.springMinDamping)
        let omega = Settings.springSettle / zeta
        if zeta > 0.999 {
            return 1 - exp(-omega * p) * (1 + omega * p)
        }
        let wd = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * p) * (cos(wd * p) + zeta * omega / wd * sin(wd * p))
    }
}

/// Zoom edits on the timeline. Positions are in seconds of the finished video, the way the
/// zoom track shows them; they are stored in source seconds (see `ZoomSegment`).
extension Timeline {

    /// Where each zoom sits on the finished video, in output seconds (same order as `zooms`).
    public func zoomOutputRanges(_ map: TimeMap) -> [TimeRange] {
        zooms.map { TimeRange(start: map.outputTime(forSource: $0.range.start), end: map.outputTime(forSource: $0.range.end)) }
    }

    /// The free space around output moment `t` that isn't taken by another zoom (except `ignoring`).
    private func freeGap(around t: Double, map: TimeMap, ignoring: Int? = nil) -> TimeRange? {
        var lo = 0.0, hi = map.outputDuration
        for (i, r) in zoomOutputRanges(map).enumerated() where i != ignoring {
            if t >= r.start && t < r.end { return nil }
            if r.end <= t { lo = max(lo, r.end) }
            if r.start > t { hi = min(hi, r.start) }
        }
        return TimeRange(start: lo, end: hi)
    }

    /// Adds a zoom from output moment `a` to `b` (either order), trimmed so it doesn't overlap
    /// another zoom. Returns its number, or nil if there isn't room.
    @discardableResult
    public mutating func addZoom(fromOutput a: Double, to b: Double, map: TimeMap, template: ZoomSegment? = nil) -> Int? {
        let start = min(a, b), end = max(a, b)
        guard let gap = freeGap(around: start, map: map) else { return nil }
        let s = max(start, gap.start), e = min(end, gap.end)
        guard e - s >= Settings.minimumZoomSeconds - 1e-9 else { return nil }
        var z = template ?? ZoomSegment(range: TimeRange(start: 0, end: 0))
        z.range = TimeRange(start: map.sourceTime(forOutput: s), end: sourceEnd(forOutput: e, map: map))
        zooms.append(z)
        return sortZooms(keeping: zooms.count - 1)
    }

    /// Moves zoom `i` so it starts at output moment `start`, keeping its length in the video.
    /// Stops at the neighbouring zooms and the ends of the video. Returns its (possibly new) number.
    @discardableResult
    public mutating func moveZoom(_ i: Int, toOutputStart start: Double, map: TimeMap) -> Int {
        guard zooms.indices.contains(i) else { return i }
        let ranges = zoomOutputRanges(map)
        let length = ranges[i].end - ranges[i].start
        var lo = 0.0, hi = map.outputDuration
        for (j, r) in ranges.enumerated() where j != i {
            if r.end <= ranges[i].start + 1e-9 { lo = max(lo, r.end) } else { hi = min(hi, r.start) }
        }
        let s = min(max(start, lo), max(lo, hi - length))
        zooms[i].range = TimeRange(start: map.sourceTime(forOutput: s), end: sourceEnd(forOutput: s + length, map: map))
        return i
    }

    /// Moves one end of zoom `i` to output moment `t`, keeping the zoom at least the minimum length
    /// and clear of its neighbours.
    public mutating func resizeZoom(_ i: Int, startEdge: Bool, toOutput t: Double, map: TimeMap) {
        guard zooms.indices.contains(i) else { return }
        let ranges = zoomOutputRanges(map)
        let r = ranges[i]
        var lo = 0.0, hi = map.outputDuration
        for (j, o) in ranges.enumerated() where j != i {
            if o.end <= r.start + 1e-9 { lo = max(lo, o.end) } else { hi = min(hi, o.start) }
        }
        let minLen = Settings.minimumZoomSeconds
        if startEdge {
            let s = min(max(t, lo), r.end - minLen)
            zooms[i].range.start = map.sourceTime(forOutput: max(s, lo))
        } else {
            let e = max(min(t, hi), r.start + minLen)
            zooms[i].range.end = sourceEnd(forOutput: min(e, hi), map: map)
        }
    }

    public mutating func deleteZoom(_ i: Int) {
        guard zooms.indices.contains(i) else { return }
        zooms.remove(at: i)
    }

    /// Drops zooms that no longer appear in the video (all of their moments were deleted).
    public mutating func pruneHiddenZooms(sourceDuration d: Double) {
        let map = TimeMap(timeline: self, sourceDuration: d)
        zooms.removeAll { map.outputTime(forSource: $0.range.end) - map.outputTime(forSource: $0.range.start) < 0.01 }
    }

    /// Source moment for the END of a range at output moment `t`: at a join between clips this is
    /// the end of the earlier clip, so the zoom doesn't reach into the next clip.
    private func sourceEnd(forOutput t: Double, map: TimeMap) -> Double {
        if let p = map.pieces.first(where: { abs($0.outputEnd - t) < 1e-9 }) { return p.source.end }
        return map.sourceTime(forOutput: t)
    }

    private mutating func sortZooms(keeping i: Int) -> Int {
        let tagged = zooms.enumerated().sorted { $0.element.range.start < $1.element.range.start }
        zooms = tagged.map(\.element)
        return tagged.firstIndex { $0.offset == i } ?? i
    }
}

/// Works out the zoom at a moment of the finished video: how far in, and towards where.
public struct ZoomCamera: Sendable {
    struct Placed: Sendable {
        let start: Double, end: Double   // output seconds
        let zoom: ZoomSegment
    }
    let placed: [Placed]

    public init(zooms: [ZoomSegment], map: TimeMap) {
        placed = zooms.map {
            Placed(start: map.outputTime(forSource: $0.range.start), end: map.outputTime(forSource: $0.range.end), zoom: $0)
        }.filter { $0.end - $0.start > 0.001 }
    }

    /// How "zoomed" the moment is (0 = not at all, 1 = fully, a bit above 1 while bouncing),
    /// and which zoom is active.
    public func weight(atOutput t: Double) -> (Double, ZoomSegment?) {
        guard let p = placed.first(where: { t >= $0.start && t <= $0.end }) else { return (0, nil) }
        let d = min(max(p.zoom.transition, 0.001), (p.end - p.start) / 2)
        if t < p.start + d { return (Spring.value((t - p.start) / d, bounce: p.zoom.bounce), p.zoom) }
        if t > p.end - d { return (1 - Spring.value((t - (p.end - d)) / d, bounce: p.zoom.bounce), p.zoom) }
        return (1, p.zoom)
    }

    /// The part of `cropped` (source pixels) visible at output moment `t`.
    public func visibleRect(atOutput t: Double, cropped: CGRect) -> CGRect {
        let (w, zoom) = weight(atOutput: t)
        guard let zoom, w > 0 else { return cropped }
        let target = Self.targetRect(zoom, cropped: cropped)
        // Zoom about the one point that stays still between the whole frame and the target,
        // so the content grows towards it without drifting sideways.
        let S = max(zoom.scale, 1.0001)
        let k = 1 - 1 / S
        let anchor = CGPoint(x: (target.minX - cropped.minX / S) / k, y: (target.minY - cropped.minY / S) / k)
        let s = max(1, exp(w * log(S)))   // even steps in perceived size
        return CGRect(x: anchor.x + (cropped.minX - anchor.x) / s, y: anchor.y + (cropped.minY - anchor.y) / s,
                      width: cropped.width / s, height: cropped.height / s)
    }

    /// What a zoom shows once it's fully in: `1/scale` of the frame around its point, kept inside the frame.
    public static func targetRect(_ zoom: ZoomSegment, cropped: CGRect) -> CGRect {
        let s = max(zoom.scale, 1)
        let w = cropped.width / s, h = cropped.height / s
        let cx = cropped.minX + zoom.centerX * cropped.width, cy = cropped.minY + zoom.centerY * cropped.height
        let x = min(max(cx - w / 2, cropped.minX), cropped.maxX - w)
        let y = min(max(cy - h / 2, cropped.minY), cropped.maxY - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
