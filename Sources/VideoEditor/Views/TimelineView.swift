import AppKit
import EditorCore
import SwiftUI

/// The bottom of the window, across its whole width: a time ruler and two tracks, with a small icon
/// per track in a gutter on the left. (The tools / play / time row sits under the preview.)
/// Top track: the clips (orange) that make up the video. Bottom track: the zooms (purple).
/// The white line (with a handle in the ruler) is the playhead; the thin blue line follows the
/// mouse (the preview shows that moment, its time shows in the ruler) and stays where you click.
/// Clicking or dragging in the ruler works like clicking empty time. With the scissors tool out, a click cuts there.
/// Clicking a clip or a zoom selects it and shows its settings in the side panel.
/// On the zoom track: click empty space to add a zoom (10% of the video) (a "+" placeholder shows
/// where while hovering), or drag across it to add one of any length; drag a zoom to move it,
/// drag its ends to make it longer or shorter.
struct TimelineView: View {
    @EnvironmentObject private var model: EditorModel
    @EnvironmentObject private var playback: PlaybackController
    /// What the current mouse drag is doing (decided when it starts).
    @State private var drag: DragKind?
    @State private var moved = false
    /// The new zoom being drawn, in output seconds.
    @State private var ghost: TimeRange?
    /// The zoom a click would add where the mouse is on the empty zoom track (output seconds).
    @State private var placeholder: TimeRange?

    private enum DragKind {
        case scrub
        case create(from: Double)
        case move(Int, grab: Double)
        case resize(Int, startEdge: Bool)
    }

    private let trackH = Settings.timelineTrackHeight
    private let trackGap = Settings.timelineTrackGap
    private let rulerH = Settings.timelineRulerHeight
    private let gutterW = Settings.timelineGutterWidth
    /// Top of the clip track and of the zoom track, from the top of the ruler.
    private var clipTop: CGFloat { rulerH + Settings.timelineRulerToTrackGap }
    private var zoomTop: CGFloat { clipTop + trackH + trackGap }
    private var totalH: CGFloat { zoomTop + trackH }

    var body: some View {
        HStack(spacing: 0) {
            gutter
            GeometryReader { geo in
                tracks(width: max(geo.size.width, 1))
            }
        }
        .frame(height: totalH)
        .padding(.horizontal, Theme.timelineMargin)
        .padding(.top, Theme.s5)
        .padding(.bottom, Theme.s4 + 16)
        .onAppear {
            // For Claude's debug snapshot: VET_SNAPSHOT_PLACEHOLDER=1 shows the "+" placeholder at 70%.
            guard ProcessInfo.processInfo.environment["VET_SNAPSHOT_PLACEHOLDER"] != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {   // after the snapshot's own edits
                if let map = model.timeMap { placeholder = model.project?.timeline.clickZoomRange(atOutput: map.outputDuration * 0.7, map: map) }
            }
        }
    }

    // MARK: Gutter and ruler

    /// A small icon left of each track: a film strip for clips, a magnifier for zooms.
    private var gutter: some View {
        ZStack(alignment: .topLeading) {
            trackIcon("film", help: "Clips").offset(y: clipTop)
            trackIcon("magnifyingglass", help: "Zooms").offset(y: zoomTop)
        }
        .frame(width: gutterW, height: totalH, alignment: .topLeading)
    }

    private func trackIcon(_ name: String, help: String) -> some View {
        Image(systemName: name).font(.system(size: 13, weight: .light)).foregroundStyle(Theme.trackIcon)
            .frame(width: gutterW, height: trackH, alignment: .leading)
            .accessibilityLabel(help)
            .help(help)
    }

    /// Dots and times along the top. The step (1 s, 2 s, 5 s…) is the smallest that keeps labels apart.
    private func ruler(width w: CGFloat, total: Double) -> some View {
        let step = Settings.timelineRulerSteps.first { $0 / total * w >= Settings.timelineRulerMinLabelSpacing }
            ?? Settings.timelineRulerSteps.last!
        let count = Int(total / step)
        let ticks = (0...max(count, 0)).map { Double($0) * step }
            .filter { CGFloat($0 / total) * w <= w - 30 }   // room for the last label
        return ZStack(alignment: .topLeading) {
            ForEach(ticks, id: \.self) { t in
                HStack(alignment: .center, spacing: Theme.s1) {
                    Circle().fill(Theme.rulerTick).frame(width: 4, height: 4)
                    Text(TransportBar.format(t)).font(Theme.fontSmall.monospacedDigit()).foregroundStyle(Theme.rulerText)
                        .fixedSize()
                }
                .offset(x: CGFloat(t / total) * w)
            }
            Rectangle().fill(Theme.rulerLine).frame(width: w, height: 1).offset(y: rulerH - 1)
        }
        .frame(width: w, height: rulerH, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // MARK: Tracks

    private func tracks(width w: CGFloat) -> some View {
        let map = model.timeMap
        let total = max(map?.outputDuration ?? 1, 0.001)
        let x = { (t: Double) in CGFloat(t / total) * w }
        let t = { (x: CGFloat) in min(max(Double(x / w) * total, 0), total) }
        let clips = model.clips
        let starts = map?.pieces.map(\.outputStart) ?? []
        let zoomRanges = model.zoomRanges
        let zooms = model.zooms

        /// Which zoom (and which part of it) is under x on the zoom track.
        func zoomHit(_ px: CGFloat) -> (Int, Part)? {
            let grab = CGFloat(Settings.timelineZoomEdgeGrab)
            for (i, r) in zoomRanges.enumerated() {
                let l = x(r.start), rt = x(r.end)
                guard px >= l - grab / 2 && px <= rt + grab / 2 else { continue }
                if rt - l > grab * 3 {
                    if px <= l + grab { return (i, .start) }
                    if px >= rt - grab { return (i, .end) }
                }
                return (i, .body)
            }
            return nil
        }
        func onZoomTrack(_ y: CGFloat) -> Bool { y >= zoomTop && y <= zoomTop + trackH }

        return ZStack(alignment: .topLeading) {
            ruler(width: w, total: total)
            // Clips.
            ForEach(Array(clips.enumerated()), id: \.offset) { i, c in
                let gap = clips.count > 1 ? Settings.timelineClipGap / 2 : 0
                let left = x(starts.indices.contains(i) ? starts[i] : 0) + (i > 0 ? gap : 0)
                let right = x((starts.indices.contains(i) ? starts[i] : 0) + c.outputDuration) - (i < clips.count - 1 ? gap : 0)
                ClipBar(clip: c, selected: model.selectedClip == i)
                    .frame(width: max(right - left, 2), height: trackH)
                    .offset(x: left, y: clipTop)
            }
            // Zoom track.
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Color(rgba: Settings.timelineZoomTrackColor))
                .overlay {
                    if zooms.isEmpty && ghost == nil && placeholder == nil {
                        Text("Click or drag to add a zoom").font(Theme.fontCallout).foregroundStyle(Theme.tertiaryText)
                    }
                }
                .frame(width: w, height: trackH)
                .offset(y: zoomTop)
            ForEach(Array(zoomRanges.enumerated()), id: \.offset) { i, r in
                ZoomBar(scale: zooms.indices.contains(i) ? zooms[i].scale : 1, selected: model.selectedZoom == i)
                    .frame(width: max(x(r.end) - x(r.start), 3), height: trackH)
                    .offset(x: x(r.start), y: zoomTop)
            }
            if let p = placeholder, ghost == nil, drag == nil {
                ZoomPlaceholder()
                    .frame(width: max(x(p.end) - x(p.start), 2), height: trackH)
                    .offset(x: x(p.start), y: zoomTop)
            }
            if let g = ghost {
                ZoomBar(scale: Settings.defaultZoomScale, selected: false)
                    .opacity(0.55)
                    .frame(width: max(x(g.end) - x(g.start), 2), height: trackH)
                    .offset(x: x(g.start), y: zoomTop)
            }
            // Blue line: under the mouse, or where you last clicked, with its time in the ruler.
            if let b = model.blueLineTime {
                editLine(at: x(min(b, total)), time: min(b, total), width: w)
            }
            // White line on top: the playhead, with its handle in the ruler.
            if let map {
                playheadLine.offset(x: x(map.outputTime(forSource: playback.playheadTime)) - Self.handleW / 2)
            }
        }
        .frame(width: w, height: totalH, alignment: .topLeading)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let p):
                model.hover(at: t(p.x))
                // Pointer hints on the zoom track: ↔ on a zoom's ends, an open hand on a zoom, and on empty
                // space a "+" placeholder showing the zoom a click would add.
                guard !model.isCutMode, drag == nil else { placeholder = nil; break }
                if onZoomTrack(p.y) {
                    switch zoomHit(p.x)?.1 {
                    case .start?, .end?: placeholder = nil; NSCursor.resizeLeftRight.set()
                    case .body?: placeholder = nil; NSCursor.openHand.set()
                    case nil:
                        placeholder = map.flatMap { model.project?.timeline.clickZoomRange(atOutput: t(p.x), map: $0) }
                        NSCursor.arrow.set()
                    }
                } else {
                    placeholder = nil
                    NSCursor.arrow.set()
                }
            case .ended:
                placeholder = nil
                model.hover(at: nil)
                if !model.isCutMode { NSCursor.arrow.set() }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if model.isCutMode { return }
                    if drag == nil {
                        let s = g.startLocation
                        if onZoomTrack(s.y) {
                            switch zoomHit(s.x) {
                            case let (i, .start)?: drag = .resize(i, startEdge: true)
                            case let (i, .end)?: drag = .resize(i, startEdge: false)
                            case let (i, .body)?: drag = .move(i, grab: t(s.x) - zoomRanges[i].start)
                            case nil: drag = .create(from: t(s.x))
                            }
                        } else {
                            drag = .scrub
                        }
                    }
                    if abs(g.translation.width) > 3 { moved = true }
                    guard moved, let drag else { return }
                    let now = t(g.location.x)
                    switch drag {
                    case .scrub: model.setEditPoint(now)
                    case .create(let from):
                        ghost = TimeRange(start: min(from, now), end: max(from, now))
                        model.hover(at: now)
                    case .move(let i, let grab):
                        model.moveZoom(i, toStart: now - grab)
                        model.selectedZoom = i
                        model.hover(at: now)
                    case .resize(let i, let startEdge):
                        model.resizeZoom(i, startEdge: startEdge, to: now)
                        model.selectedZoom = i
                        model.hover(at: now)
                    }
                }
                .onEnded { g in
                    defer { drag = nil; moved = false; ghost = nil }
                    let time = t(g.location.x)
                    if model.isCutMode { model.cut(atOutput: time); return }
                    if moved {
                        if case .create(let from)? = drag { model.addZoom(from: from, to: time) }
                        return
                    }
                    // A click: pins the blue line there, and selects what was clicked.
                    model.setEditPoint(time)
                    let y = g.location.y
                    if y >= clipTop && y <= clipTop + trackH, let map {
                        model.selectedClip = map.pieceIndex(atOutput: time)
                    } else if onZoomTrack(y) {
                        if let (i, _) = zoomHit(g.location.x) { model.selectedZoom = i }
                        else if let p = map.flatMap({ model.project?.timeline.clickZoomRange(atOutput: time, map: $0) }) {
                            // Click on empty space: adds the zoom the placeholder showed.
                            model.addZoom(from: p.start, to: p.end)
                            placeholder = nil
                        } else { model.selectedZoom = nil; model.selectedClip = nil }
                    }
                }
        )
    }

    private enum Part { case start, end, body }

    private static let handleW: CGFloat = 4
    private static let handleH: CGFloat = 14
    /// How far the lines reach below the zoom track.
    private static let lineOverhang = CGFloat(Settings.timelineLineOverhang)

    /// The playhead: a 1 pt white line with a 4 pt round handle in the ruler (its centre 9 pt down, where the line starts).
    private var playheadLine: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Theme.playhead).frame(width: 1, height: totalH + Self.lineOverhang - 9)
                .offset(y: 9)
            Circle().fill(Theme.playhead).frame(width: Self.handleW, height: Self.handleW)
                .offset(y: 7)
        }
        .frame(width: Self.handleW, height: totalH + Self.lineOverhang, alignment: .top)
        .allowsHitTesting(false)
    }

    /// The blue line: 1 pt, no knob, with a small label of its time (tenths) at its top, kept inside the timeline.
    private func editLine(at px: CGFloat, time: Double, width w: CGFloat) -> some View {
        let text = TransportBar.tenths(time)
        let labelH: CGFloat = 21, labelTop: CGFloat = 2
        // Width of the label: digits are about 7.15 pt in 11 pt Inter (even-width digits), ":" and "." about 3 pt, plus 6 pt padding each side.
        let digits = text.filter(\.isNumber).count
        let labelW = CGFloat(digits) * 7.15 + CGFloat(text.count - digits) * 3.0 + 12
        let labelX = min(max(px - labelW / 2, 0), w - labelW)
        let lineTop = labelTop + labelH
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.editLine).frame(width: 1, height: totalH - lineTop + Self.lineOverhang)
                .offset(x: px - 0.5, y: lineTop)
            Text(text).font(Theme.fontSmall.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                .fixedSize()
                .frame(width: labelW, height: labelH)
                .background(RoundedRectangle(cornerRadius: Theme.radiusSmall).fill(Color(rgba: Settings.timelineEditTagColor)))
                .offset(x: labelX, y: labelTop)
        }
        .allowsHitTesting(false)
    }

    static func speedLabel(_ r: Double) -> String {
        r == r.rounded() ? "\(Int(r))×" : String(format: "%.1f×", r)
    }

    /// "36s", or "6.4s" under ten seconds.
    static func lengthLabel(_ seconds: Double) -> String {
        if seconds >= 10 || abs(seconds - seconds.rounded()) < 0.05 { return "\(Int(seconds.rounded()))s" }
        return String(format: "%.1fs", seconds)
    }
}

/// One clip: an orange bar labelled on the left with its length in the video and its speed.
private struct ClipBar: View {
    let clip: Clip
    let selected: Bool

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill((selected ? Theme.clipSelected : Theme.clip).opacity(Settings.timelineClipOpacity))
                .innerShadow(radius: Theme.radius, color: .black.opacity(0.25), y: 7, blur: 20)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.clipSelected, lineWidth: selected ? Settings.timelineSelectionRingWidth : 0))
                .overlay(alignment: .leading) {
                    if geo.size.width > 56 {
                        HStack(spacing: Theme.s2) {
                            Text(TimelineView.lengthLabel(clip.outputDuration))
                            Text(TimelineView.speedLabel(clip.rate)).opacity(0.8)
                        }
                        .font(Theme.fontBody)
                        .foregroundStyle(Theme.clipLabel)
                        .lineLimit(1)
                        .padding(.leading, Theme.barLabelInset + (selected ? 1 : 0))
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

/// One zoom: a purple block labelled on the left with how far it zooms ("150%").
private struct ZoomBar: View {
    let scale: Double
    let selected: Bool

    var body: some View {
        GeometryReader { geo in
            let percent = "\(Int((scale * 100).rounded()))%"
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.zoom.opacity(Settings.timelineBarOpacity))
                .innerShadow(radius: Theme.radius, color: .black.opacity(0.25), y: 7, blur: 20)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.zoomSelected, lineWidth: selected ? Settings.timelineSelectionRingWidth : 0))
                .overlay(alignment: .leading) {
                    let inset = Theme.barLabelInset + (selected ? 1 : 0)
                    if geo.size.width > inset + 34 {
                        Text(percent)
                            .font(Theme.fontBody)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.leading, inset)
                    }
                }
                .overlay(alignment: .leading) { if selected { grip } }
                .overlay(alignment: .trailing) { if selected { grip } }
        }
        .allowsHitTesting(false)
    }

    /// Small bars at each end of the selected zoom, hinting that the ends can be dragged.
    private var grip: some View {
        RoundedRectangle(cornerRadius: 1).fill(.white).frame(width: 2, height: 14).padding(.horizontal, 7)
    }
}

/// Where a click would add a zoom: a dashed purple outline with a "+" in the middle.
private struct ZoomPlaceholder: View {
    var body: some View {
        let color = Theme.zoom
        RoundedRectangle(cornerRadius: Theme.radius)
            .fill(color.opacity(0.22))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .overlay(Image(systemName: "plus").font(.system(size: 15, weight: .light)).foregroundStyle(.white.opacity(0.9)))
            .allowsHitTesting(false)
    }
}
