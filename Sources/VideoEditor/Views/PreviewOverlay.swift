import EditorCore
import SwiftUI

/// Handles drawn on top of the preview: in crop mode, the crop box with corner and edge handles
/// over the whole recording. (Zooms always show for real in the preview; they're aimed in the side panel.)
struct PreviewOverlay: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        GeometryReader { geo in
            if let project = model.project {
                if model.isCropMode {
                    CropHandles(content: viewRect(FrameLayout.contentRect(project: project, mode: .wholeFrame), in: geo.size))
                }
            }
        }
    }

    /// Canvas fractions → points in the preview.
    private func viewRect(_ r: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: r.minX * size.width, y: r.minY * size.height, width: r.width * size.width, height: r.height * size.height)
    }
}

/// The crop box over the recording: drag a corner or edge to resize, drag inside to move.
private struct CropHandles: View {
    @EnvironmentObject private var model: EditorModel
    /// Where the whole recording sits in the preview, in points.
    let content: CGRect
    @State private var start: (rect: CGRect, part: Part)?

    private enum Part { case move, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight }
    private let grab: CGFloat = 12

    var body: some View {
        let f = model.cropFraction
        let box = CGRect(x: content.minX + f.minX * content.width, y: content.minY + f.minY * content.height,
                         width: f.width * content.width, height: f.height * content.height)
        ZStack(alignment: .topLeading) {
            // Dim what's cropped away.
            Path { p in p.addRect(content); p.addRect(box) }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            // Thirds grid and border.
            Path { p in
                for k in 1...2 {
                    let x = box.minX + box.width * CGFloat(k) / 3, y = box.minY + box.height * CGFloat(k) / 3
                    p.move(to: CGPoint(x: x, y: box.minY)); p.addLine(to: CGPoint(x: x, y: box.maxY))
                    p.move(to: CGPoint(x: box.minX, y: y)); p.addLine(to: CGPoint(x: box.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
            Rectangle().path(in: box).stroke(Color.white, lineWidth: 1.5)
            // Corner brackets and edge bars.
            Path { p in
                let l: CGFloat = 18
                for (c, dx, dy) in [(CGPoint(x: box.minX, y: box.minY), 1.0, 1.0), (CGPoint(x: box.maxX, y: box.minY), -1, 1),
                                    (CGPoint(x: box.minX, y: box.maxY), 1, -1), (CGPoint(x: box.maxX, y: box.maxY), -1, -1)] {
                    p.move(to: CGPoint(x: c.x + l * dx, y: c.y)); p.addLine(to: c); p.addLine(to: CGPoint(x: c.x, y: c.y + l * dy))
                }
                for (a, b) in [(CGPoint(x: box.midX - 10, y: box.minY), CGPoint(x: box.midX + 10, y: box.minY)),
                               (CGPoint(x: box.midX - 10, y: box.maxY), CGPoint(x: box.midX + 10, y: box.maxY)),
                               (CGPoint(x: box.minX, y: box.midY - 10), CGPoint(x: box.minX, y: box.midY + 10)),
                               (CGPoint(x: box.maxX, y: box.midY - 10), CGPoint(x: box.maxX, y: box.midY + 10))] {
                    p.move(to: a); p.addLine(to: b)
                }
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            guard case .active(let pt) = phase, start == nil else { return }
            switch part(at: pt, box: box) {
            case .left?, .right?: NSCursor.resizeLeftRight.set()
            case .top?, .bottom?: NSCursor.resizeUpDown.set()
            case .move?: NSCursor.openHand.set()
            case nil: NSCursor.arrow.set()
            default: NSCursor.crosshair.set()
            }
        }
        .gesture(DragGesture(minimumDistance: 1).onChanged { g in
            if start == nil {
                guard let p = part(at: g.startLocation, box: box) else { return }
                start = (f, p)
            }
            guard let (r0, p) = start else { return }
            model.setCrop(Self.adjust(r0, part: p, dx: g.translation.width / content.width, dy: g.translation.height / content.height))
        }.onEnded { _ in start = nil })
    }

    private func part(at pt: CGPoint, box: CGRect) -> Part? {
        let nearL = abs(pt.x - box.minX) < grab, nearR = abs(pt.x - box.maxX) < grab
        let nearT = abs(pt.y - box.minY) < grab, nearB = abs(pt.y - box.maxY) < grab
        let inX = pt.x > box.minX - grab && pt.x < box.maxX + grab, inY = pt.y > box.minY - grab && pt.y < box.maxY + grab
        guard inX && inY else { return nil }
        switch (nearL, nearR, nearT, nearB) {
        case (true, _, true, _): return .topLeft
        case (_, true, true, _): return .topRight
        case (true, _, _, true): return .bottomLeft
        case (_, true, _, true): return .bottomRight
        case (true, _, _, _): return .left
        case (_, true, _, _): return .right
        case (_, _, true, _): return .top
        case (_, _, _, true): return .bottom
        default: return box.contains(pt) ? .move : nil
        }
    }

    /// The crop after dragging `part` by (dx, dy), as fractions of the recording. Never smaller than
    /// the minimum and never outside the recording.
    private static func adjust(_ r: CGRect, part: Part, dx: CGFloat, dy: CGFloat) -> CGRect {
        let m = CGFloat(Settings.minimumCropFraction)
        if part == .move {
            return CGRect(x: min(max(r.minX + dx, 0), 1 - r.width), y: min(max(r.minY + dy, 0), 1 - r.height),
                          width: r.width, height: r.height)
        }
        var x0 = r.minX, x1 = r.maxX, y0 = r.minY, y1 = r.maxY
        if [.left, .topLeft, .bottomLeft].contains(part) { x0 = min(max(r.minX + dx, 0), x1 - m) }
        if [.right, .topRight, .bottomRight].contains(part) { x1 = max(min(r.maxX + dx, 1), x0 + m) }
        if [.top, .topLeft, .topRight].contains(part) { y0 = min(max(r.minY + dy, 0), y1 - m) }
        if [.bottom, .bottomLeft, .bottomRight].contains(part) { y1 = max(min(r.maxY + dy, 1), y0 + m) }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}
