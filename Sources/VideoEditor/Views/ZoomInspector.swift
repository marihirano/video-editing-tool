import EditorCore
import SwiftUI

/// The side panel while a zoom is selected: how far it zooms, where it points, how it moves,
/// and delete. "‹ Style" at the top goes back to the background and frame settings.
struct ZoomInspector: View {
    @EnvironmentObject private var model: EditorModel
    let index: Int
    @State private var still: CGImage?

    private var zoom: ZoomSegment {
        model.zooms.indices.contains(index) ? model.zooms[index] : ZoomSegment(range: TimeRange(start: 0, end: 0))
    }

    var body: some View {
        let ranges = model.zoomRanges
        let length = ranges.indices.contains(index) ? ranges[index].end - ranges[index].start : 0
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { model.selectedZoom = nil } label: {
                    Label("Style", systemImage: "chevron.left").font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Back to background and frame settings")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zoom \(index + 1) of \(model.zooms.count)").font(.title3.weight(.semibold))
                    Text("\(TimelineView.lengthLabel(length)) in the video").font(.callout).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Amount").font(.headline)
                        Spacer()
                        Text("\(Int((zoom.scale * 100).rounded()))%").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Slider(value: binding(\.scale, group: "scale"), in: Settings.zoomScaleRange)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Where it points").font(.headline)
                        Spacer()
                        Button("Centre") { model.updateZoom(index, group: "point") { $0.centerX = 0.5; $0.centerY = 0.5 } }
                            .controlSize(.small)
                    }
                    FocusPicker(zoom: zoom, aspect: cropAspect, image: still) {
                        model.showZoomInPreview(index)
                    } set: { x, y in
                        model.updateZoom(index, group: "point") { $0.centerX = x; $0.centerY = y }
                    }
                    Text("Drag the circle to the spot to zoom in on.").font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Animation").font(.headline)
                    HStack(spacing: 6) {
                        ForEach(Array(Settings.zoomEasingPresets.enumerated()), id: \.offset) { _, p in
                            presetButton(p)
                        }
                    }
                    EasingCurve(bounce: zoom.bounce)
                        .frame(height: 54)
                    slider("Transition", value: binding(\.transition, group: "transition"), range: Settings.zoomTransitionRange,
                           label: String(format: "%.1fs", zoom.transition))
                    slider("Bounce", value: binding(\.bounce, group: "bounce"), range: 0...1,
                           label: "\(Int((zoom.bounce * 100).rounded()))%")
                    Text("Transition is how long zooming in (and back out) takes.").font(.caption).foregroundStyle(.secondary)
                }

                Button(role: .destructive) { model.deleteZoom(index) } label: {
                    Label("Delete zoom", systemImage: "trash")
                }
                .help("Remove this zoom (Delete)")
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
        }
        .frame(width: 300)
        .background(.bar)
        // A still of the recording at the middle of the zoom, cropped like the video.
        .task(id: stillKey) {
            guard let url = model.sourceURL, let t = model.zoomStillTime(index) else { still = nil; return }
            still = await FrameStill.image(url: url, time: t, crop: model.cropFraction)
        }
    }

    /// Changes when the picture needs to be grabbed again (another moment or another crop).
    private var stillKey: String {
        let t = model.zoomStillTime(index) ?? -1
        return "\(index)-\((t * 10).rounded())-\(model.cropFraction.debugDescription)"
    }

    /// Width ÷ height of the (cropped) recording, so the picker has the same shape.
    private var cropAspect: CGFloat {
        guard let p = model.project, p.source.height > 0 else { return 16 / 9 }
        let f = model.cropFraction
        return f.width * CGFloat(p.source.width) / max(f.height * CGFloat(p.source.height), 1)
    }

    private func binding(_ key: WritableKeyPath<ZoomSegment, Double>, group: String) -> Binding<Double> {
        Binding(get: { zoom[keyPath: key] }, set: { v in model.updateZoom(index, group: group) { $0[keyPath: key] = v } })
    }

    private func presetButton(_ p: EasingPreset) -> some View {
        let selected = abs(zoom.transition - p.transition) < 0.01 && abs(zoom.bounce - p.bounce) < 0.01
        return Button {
            model.updateZoom(index, group: "preset") { $0.transition = p.transition; $0.bounce = p.bounce }
        } label: {
            Text(p.name)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 28)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func slider(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.callout)
                Spacer()
                Text(label).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

/// A still of the (cropped) recording with a circle on the spot the zoom points at; drag the circle to move it.
private struct FocusPicker: View {
    let zoom: ZoomSegment
    let aspect: CGFloat
    let image: CGImage?
    /// Called when a drag starts (shows the zoom in the preview).
    let began: () -> Void
    let set: (Double, Double) -> Void
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let d: CGFloat = 22
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(decorative: image, scale: 1).resizable().frame(width: size.width, height: size.height)
                } else {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
                Circle()
                    .fill(Color(rgba: Settings.timelineZoomColor).opacity(0.35))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                    .overlay(Circle().fill(Color.white).frame(width: 4, height: 4))
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .frame(width: d, height: d)
                    .offset(x: zoom.centerX * size.width - d / 2, y: zoom.centerY * size.height - d / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case .active = phase { NSCursor.crosshair.set() } else { NSCursor.arrow.set() }
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                if !dragging { dragging = true; began() }
                set(min(max(g.location.x / size.width, 0), 1), min(max(g.location.y / size.height, 0), 1))
            }.onEnded { _ in dragging = false })
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}

/// A picture of the easing: how the zoom builds up over the transition.
private struct EasingCurve: View {
    let bounce: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let top = h * 0.2, bottom = h - 4   // room above 100% for bounce
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: top)); p.addLine(to: CGPoint(x: w, y: top))
                }
                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Path { p in
                    for i in 0...80 {
                        let x = Double(i) / 80
                        let pt = CGPoint(x: x * w, y: bottom - Spring.value(x, bounce: bounce) * (bottom - top))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(Color(rgba: Settings.timelineZoomColor), lineWidth: 2)
            }
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.04)))
    }
}
