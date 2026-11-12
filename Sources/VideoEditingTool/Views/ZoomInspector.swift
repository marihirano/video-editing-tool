import EditorCore
import SwiftUI

/// The side panel while a zoom is selected: how far it zooms, where it points, how it moves,
/// and delete. "‹ Style" at the top goes back to the background and frame settings.
struct ZoomInspector: View {
    @EnvironmentObject private var model: EditorModel
    let index: Int

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
                    FocusPicker(zoom: zoom, aspect: cropAspect) { x, y in
                        model.updateZoom(index, group: "point") { $0.centerX = x; $0.centerY = y }
                    }
                    Text("Drag the box here or on the preview.").font(.caption).foregroundStyle(.secondary)
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

/// A small frame-shaped box with the zoom's area drawn on it; drag to move the area.
private struct FocusPicker: View {
    let zoom: ZoomSegment
    let aspect: CGFloat
    let set: (Double, Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let r = ZoomCamera.targetRect(zoom, cropped: CGRect(x: 0, y: 0, width: 1, height: 1))
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(rgba: Settings.timelineZoomColor).opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(rgba: Settings.timelineZoomColor), lineWidth: 2))
                    .frame(width: r.width * size.width, height: r.height * size.height)
                    .offset(x: r.minX * size.width, y: r.minY * size.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let (x, y) = ZoomPoint.clamped(x: g.location.x / size.width, y: g.location.y / size.height, scale: zoom.scale)
                set(x, y)
            })
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}

enum ZoomPoint {
    /// Keeps a zoom's point where its whole area still fits in the frame, so the stored point
    /// matches the box you see.
    static func clamped(x: Double, y: Double, scale: Double) -> (Double, Double) {
        let h = 0.5 / max(scale, 1)
        return (min(max(x, h), 1 - h), min(max(y, h), 1 - h))
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
