import AppKit
import EditorCore
import SwiftUI

/// The bottom of the window: play / time / scissors, then two tracks.
/// Top track: the clips (orange) that make up the video. Bottom track: zooms (empty until M4).
/// The gray line is the playhead; the blue line follows the mouse (the preview shows that
/// moment) and stays where you click. With the scissors tool out, a click cuts there.
/// Clicking a clip selects it and shows its speed in the side panel.
struct TimelineView: View {
    @EnvironmentObject private var model: EditorModel
    @EnvironmentObject private var playback: PlaybackController
    @State private var dragging = false

    private let trackH = Settings.timelineTrackHeight
    private let trackGap: CGFloat = 8
    private let knob: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TransportBar()
            GeometryReader { geo in
                tracks(width: max(geo.size.width, 1))
            }
            .frame(height: knob + trackH * 2 + trackGap)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
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
            // Zoom track (filled in by M4).
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(rgba: Settings.timelineZoomTrackColor))
                .overlay(Text("Zooms").font(.callout).foregroundStyle(.white.opacity(0.25)))
                .frame(width: w, height: trackH)
                .offset(y: zoomTop)
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
            case .active(let p): model.hover(at: t(p.x))
            case .ended: model.hover(at: nil)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if model.isCutMode { return }
                    if abs(g.translation.width) > 3 { dragging = true }
                    if dragging { model.setEditPoint(t(g.location.x)) }
                }
                .onEnded { g in
                    defer { dragging = false }
                    guard !dragging else { return }
                    let time = t(g.location.x)
                    if model.isCutMode { model.cut(atOutput: time); return }
                    model.setEditPoint(time)
                    // Clicking a clip selects it; its speed settings show in the side panel.
                    let onClips = g.location.y >= clipTop && g.location.y <= clipTop + trackH
                    if onClips, let map { model.selectedClip = map.pieceIndex(atOutput: time) }
                }
        )
    }

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
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(rgba: Settings.timelineClipColor))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white, lineWidth: selected ? 2 : 0))
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
