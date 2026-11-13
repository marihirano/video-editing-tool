import AppKit
import EditorCore
import SwiftUI

/// The bottom of the window: play / time / scissors / crop, then two tracks.
/// Top track: the clips (orange) that make up the video. Bottom track: the zooms (purple).
/// The gray line is the playhead; the blue line follows the mouse (the preview shows that
/// moment) and stays where you click. With the scissors tool out, a click cuts there.
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
    private let trackGap: CGFloat = Theme.s2
    private let knob: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            TransportBar()
            GeometryReader { geo in
                tracks(width: max(geo.size.width, 1))
            }
            .frame(height: knob + trackH * 2 + trackGap)
        }
        .padding(.horizontal, Theme.panelPadding)
        .padding(.top, Theme.s3)
        .padding(.bottom, Theme.s4)
        .onAppear {
            // For Claude's debug snapshot: VET_SNAPSHOT_PLACEHOLDER=1 shows the "+" placeholder at 70%.
            guard ProcessInfo.processInfo.environment["VET_SNAPSHOT_PLACEHOLDER"] != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {   // after the snapshot's own edits
                if let map = model.timeMap { placeholder = model.project?.timeline.clickZoomRange(atOutput: map.outputDuration * 0.7, map: map) }
            }
        }
    }

    // MARK: Tracks

    private func tracks(width w: CGFloat) -> some View {
        let map = model.timeMap
        let total = max(map?.outputDuration ?? 1, 0.001)
        let x = { (t: Double) in CGFloat(t / total) * w }
        let t = { (x: CGFloat) in min(max(Double(x / w) * total, 0), total) }
        let clips = model.clips
        let starts = map?.pieces.map(\.outputStart) ?? []
        let clipTop = knob
        let zoomTop = knob + trackH + trackGap
        let lineH = trackH * 2 + trackGap + 4
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
                        Text("Drag here to add a zoom").font(.callout).foregroundStyle(Theme.tertiaryText)
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
            // Gray line: the playhead.
            if let map {
                line(color: Color(rgba: Settings.timelinePlayheadColor), height: lineH)
                    .offset(x: x(map.outputTime(forSource: playback.playheadTime)) - knob / 2)
            }
            // Blue line: under the mouse, or where you last clicked.
            if let b = model.blueLineTime {
                line(color: Color(rgba: Settings.timelineEditLineColor), height: lineH)
                    .offset(x: x(min(b, total)) - knob / 2)
            }
        }
        .frame(width: w, height: knob + trackH * 2 + trackGap, alignment: .topLeading)
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

    /// A vertical line with a round knob on top, spanning both tracks.
    private func line(color: Color, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Circle().fill(color).frame(width: knob, height: knob)
            Rectangle().fill(color).frame(width: 2, height: height)
        }
        .frame(width: knob)
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

/// One clip: an orange bar labelled with its length in the video and its speed.
private struct ClipBar: View {
    let clip: Clip
    let selected: Bool

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.clip)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Color.white, lineWidth: selected ? 2 : 0))
                .overlay {
                    if geo.size.width > 56 {
                        Text("\(TimelineView.lengthLabel(clip.outputDuration)) \(TimelineView.speedLabel(clip.rate))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

/// One zoom: a purple block labelled with how far it zooms ("150% zoom").
private struct ZoomBar: View {
    let scale: Double
    let selected: Bool

    var body: some View {
        GeometryReader { geo in
            let percent = "\(Int((scale * 100).rounded()))%"
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.zoom)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Color.white, lineWidth: selected ? 2 : 0))
                .overlay {
                    if geo.size.width > 40 {
                        Text(geo.size.width > 96 ? "\(percent) zoom" : percent)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                .overlay(alignment: .leading) { if selected { grip } }
                .overlay(alignment: .trailing) { if selected { grip } }
        }
        .allowsHitTesting(false)
    }

    /// Small bars at each end of the selected zoom, hinting that the ends can be dragged.
    private var grip: some View {
        RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.85)).frame(width: 2, height: 14).padding(.horizontal, 4)
    }
}

/// Where a click would add a zoom: a dashed purple outline with a "+" in the middle.
private struct ZoomPlaceholder: View {
    var body: some View {
        let color = Theme.zoom
        RoundedRectangle(cornerRadius: Theme.radius)
            .fill(color.opacity(0.22))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .overlay(Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.9)))
            .allowsHitTesting(false)
    }
}
