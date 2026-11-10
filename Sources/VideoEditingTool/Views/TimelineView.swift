import EditorCore
import SwiftUI

/// The timeline under the preview: thumbnails of the whole recording, with trimmed-off ends
/// dimmed, cut parts striped, sped-up parts marked, a drag-to-select range and the playhead.
/// Click to move the playhead; drag across to select; drag the yellow handles to trim.
struct TimelineView: View {
    @EnvironmentObject private var model: EditorModel
    @EnvironmentObject private var playback: PlaybackController
    /// Where a drag on the track began (source seconds), while selecting.
    @State private var dragStart: Double?

    private let height = Settings.timelineTrackHeight
    private let handleWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: 8) {
            TimelineToolbar()
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let d = max(model.sourceDuration, 0.001)
                let x = { (t: Double) in CGFloat(t / d) * w }
                let t = { (x: CGFloat) in min(max(Double(x / w) * d, 0), d) }
                let timeline = model.project?.timeline ?? Timeline()
                let kept = timeline.keptRange(sourceDuration: d)

                ZStack(alignment: .topLeading) {
                    thumbnails
                    // Trimmed-off ends.
                    dim(from: 0, to: x(kept.start))
                    dim(from: x(kept.end), to: w)
                    // Cut parts.
                    ForEach(Array(timeline.cuts.enumerated()), id: \.offset) { _, c in
                        CutMark().frame(width: max(x(c.end) - x(c.start), 2), height: height).offset(x: x(c.start))
                    }
                    // Sped-up parts.
                    ForEach(Array(timeline.speedSegments.enumerated()), id: \.offset) { _, s in
                        SpeedMark(rate: s.rate).frame(width: max(x(s.range.end) - x(s.range.start), 2), height: height)
                            .offset(x: x(s.range.start))
                    }
                    if let sel = model.selection {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.18))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white, lineWidth: 1.5))
                            .frame(width: max(x(sel.end) - x(sel.start), 2), height: height)
                            .offset(x: x(sel.start))
                            .allowsHitTesting(false)
                    }
                    // Playhead.
                    Rectangle().fill(Color.white).frame(width: 2, height: height + 10)
                        .offset(x: x(playback.currentTime) - 1, y: -5)
                        .shadow(radius: 2)
                        .allowsHitTesting(false)
                    // Trim handles.
                    handle(edge: .leading).offset(x: x(kept.start) - handleWidth)
                        .gesture(trimGesture(isStart: true, kept: kept, toTime: t))
                    handle(edge: .trailing).offset(x: x(kept.end))
                        .gesture(trimGesture(isStart: false, kept: kept, toTime: t))
                }
                .frame(width: w, height: height, alignment: .topLeading)
                .contentShape(Rectangle())
                .coordinateSpace(name: "track")
                .gesture(trackGesture(toTime: t))
            }
            .frame(height: height)
            .padding(.horizontal, handleWidth)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.bar)
    }

    // MARK: Pieces

    private var thumbnails: some View {
        let aspect = model.project.map { Double($0.source.width) / Double(max($0.source.height, 1)) } ?? 16.0 / 9.0
        let images = model.thumbnails
        return Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.2)))
            guard !images.isEmpty else { return }
            let tileW = max(size.height * aspect, 8)
            var x: CGFloat = 0
            while x < size.width {
                let i = min(images.count - 1, Int((x + tileW / 2) / size.width * CGFloat(images.count)))
                if let img = images[i] {
                    ctx.draw(Image(decorative: img, scale: 1), in: CGRect(x: x, y: 0, width: tileW, height: size.height))
                }
                x += tileW
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .allowsHitTesting(false)
    }

    private func dim(from a: CGFloat, to b: CGFloat) -> some View {
        Rectangle().fill(Color.black.opacity(0.72))
            .frame(width: max(b - a, 0), height: height).offset(x: a)
            .allowsHitTesting(false)
    }

    private func handle(edge: HorizontalEdge) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: edge == .leading ? 4 : 0, bottomLeadingRadius: edge == .leading ? 4 : 0,
                               bottomTrailingRadius: edge == .trailing ? 4 : 0, topTrailingRadius: edge == .trailing ? 4 : 0)
            .fill(Color.yellow)
            .overlay(Capsule().fill(Color.black.opacity(0.5)).frame(width: 2, height: 18))
            .frame(width: handleWidth, height: height)
            .contentShape(Rectangle())
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .help(edge == .leading ? "Drag to trim the start" : "Drag to trim the end")
    }

    // MARK: Gestures

    /// Click: move the playhead. Drag: select a part.
    private func trackGesture(toTime t: @escaping (CGFloat) -> Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let moved = abs(g.translation.width) > 3
                if !moved { return }
                let a = dragStart ?? t(g.startLocation.x)
                dragStart = a
                let b = t(g.location.x)
                model.selection = TimeRange(start: min(a, b), end: max(a, b))
            }
            .onEnded { g in
                if dragStart == nil {
                    model.selection = nil
                    playback.seek(to: t(g.location.x))
                }
                dragStart = nil
            }
    }

    /// Drags a trim handle; the playhead follows so you can see the new first or last frame.
    private func trimGesture(isStart: Bool, kept: TimeRange, toTime t: @escaping (CGFloat) -> Double) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("track"))
            .onChanged { g in
                let time = t(g.location.x)
                if isStart {
                    let s = min(time, kept.end - Settings.minimumKeptSeconds)
                    model.setTrim(start: s, end: kept.end)
                    playback.seek(to: s)
                } else {
                    let e = max(time, kept.start + Settings.minimumKeptSeconds)
                    model.setTrim(start: kept.start, end: e)
                    playback.seek(to: e)
                }
            }
    }
}

/// A removed part: dark with red stripes.
private struct CutMark: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color.black.opacity(0.75))
            Canvas { ctx, size in
                var p = Path()
                var x: CGFloat = -size.height
                while x < size.width { p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 8 }
                ctx.stroke(p, with: .color(Color.red.opacity(0.55)), lineWidth: 1.5)
            }
            Image(systemName: "scissors").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

/// A sped-up part: an orange band along the top with its speed.
private struct SpeedMark: View {
    let rate: Double
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(Color.orange)
                Text(TimelineToolbar.speedLabel(rate)).font(.system(size: 10, weight: .bold)).foregroundStyle(.black)
            }
            .frame(height: 14)
            Rectangle().fill(Color.orange.opacity(0.18))
        }
        .clipped()
        .allowsHitTesting(false)
    }
}
