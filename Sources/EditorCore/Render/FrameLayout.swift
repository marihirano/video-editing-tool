import CoreGraphics
import simd

extension Project {
    /// The recording's size in pixels, as saved in the project.
    public var sourceSize: CGSize { CGSize(width: source.width, height: source.height) }
}

/// Numbers the shader needs for one frame. Layout must match `FrameUniforms` in Shaders.swift.
public struct FrameUniforms: Equatable {
    public var background: SIMD4<Float>    // plain colour
    public var gradientA: SIMD4<Float>
    public var gradientB: SIMD4<Float>
    public var bgParams: SIMD4<Float>      // kind (0 wallpaper, 1 gradient, 2 solid, 3 image), gradient angle in radians
    public var wallpaper0: SIMD4<Float>
    public var wallpaper1: SIMD4<Float>
    public var wallpaper2: SIMD4<Float>
    public var wallpaper3: SIMD4<Float>
    public var contentRect: SIMD4<Float>   // x, y, width, height on the canvas (0–1)
    public var sourceRect: SIMD4<Float>    // x, y, width, height in the source (0–1)
    public var shape: SIMD4<Float>         // corner radius, shadow opacity, shadow blur, shadow offset (canvas pixels)
    public var canvas: SIMD4<Float>        // canvas width and height in pixels
    public var camera: SIMD4<Float>        // part of the canvas in view (x, y, width, height, 0–1); zoom moves this
}

/// What the preview leaves out while something is being edited on it.
public enum LayoutMode: Sendable {
    /// The finished look (what export draws).
    case normal
    /// Crop applied, zoom left out: while aiming a zoom, the whole frame shows with a box on it.
    case withoutZoom
    /// The whole recording, no crop or zoom: while dragging the crop handles.
    case wholeFrame
}

/// Works out what to draw for one frame, as a chain of steps in a fixed order:
/// crop → zoom → cursor → frame and background.
public enum FrameLayout {

    /// - Parameters:
    ///   - outputTime: the moment in the finished video (seconds); zoom animations run on this clock.
    ///   - timeMap: how clips map the recording onto the video; built from the project if nil.
    public static func uniforms(project: Project, sourceSize: CGSize, outputTime: Double,
                                timeMap: TimeMap? = nil, mode: LayoutMode = .normal) -> FrameUniforms {
        let full = CGRect(origin: .zero, size: sourceSize)
        let cropped = mode == .wholeFrame ? full : cropStep(project.crop, full: full, sourceSize: project.sourceSize)
        let visible = cropped
        // Cursor step (phase 2) draws on top in its own pass; it doesn't change the layout.
        let canvas = CGSize(width: project.output.width, height: project.output.height)
        let style = project.style
        let framed = frameStep(contentAspect: cropped.width / max(cropped.height, 1), canvas: canvas,
                               paddingPercent: style.padding)
        // Zoom: a camera over the whole finished picture (video, frame, shadow and background together),
        // so a zoom grows the framed video past the edges instead of zooming inside its rectangle.
        var camera = CGRect(x: 0, y: 0, width: 1, height: 1)
        if mode == .normal, !project.timeline.zooms.isEmpty {
            let map = timeMap ?? TimeMap(project: project, sourceDuration: project.source.duration)
            camera = ZoomCamera(zooms: project.timeline.zooms, map: map)
                .visibleRect(atOutput: outputTime, cropped: camera) { ZoomCamera.canvasTarget($0, content: framed) }
        }
        let zoomed = Float(1 / camera.width)
        let content = CGRect(x: (framed.minX - camera.minX) / camera.width, y: (framed.minY - camera.minY) / camera.height,
                             width: framed.width / camera.width, height: framed.height / camera.height)
        let k = Float(canvas.height / 1080)   // style sizes are written for a 1080-tall canvas

        func v(_ c: RGBAColor) -> SIMD4<Float> { SIMD4(Float(c.r), Float(c.g), Float(c.b), Float(c.a)) }
        let wp = Settings.wallpapers[min(max(style.wallpaper, 0), Settings.wallpapers.count - 1)].colors
        let kind: Float
        switch style.kind {
        case .wallpaper: kind = 0
        case .gradient: kind = 1
        case .solid: kind = 2
        case .image: kind = 3
        }
        return FrameUniforms(
            background: v(style.background),
            gradientA: v(style.gradientStart), gradientB: v(style.gradientEnd),
            bgParams: SIMD4(kind, Float(style.gradientAngle * .pi / 180), 0, 0),
            wallpaper0: v(wp[0]), wallpaper1: v(wp[1]), wallpaper2: v(wp[2]), wallpaper3: v(wp[3]),
            contentRect: SIMD4(Float(content.minX), Float(content.minY), Float(content.width), Float(content.height)),
            sourceRect: SIMD4(Float(visible.minX / full.width), Float(visible.minY / full.height),
                              Float(visible.width / full.width), Float(visible.height / full.height)),
            shape: SIMD4(Float(style.cornerRadius) * k * zoomed, Float(style.shadowOpacity),
                         Float(style.shadowBlur) * k * zoomed, Float(style.shadowOffset) * k * zoomed),
            canvas: SIMD4(Float(canvas.width), Float(canvas.height), 0, 0),
            camera: SIMD4(Float(camera.minX), Float(camera.minY), Float(camera.width), Float(camera.height))
        )
    }

    /// Where the video sits on the canvas (fractions of the canvas), for drawing handles on the preview.
    public static func contentRect(project: Project, mode: LayoutMode) -> CGRect {
        let full = CGRect(origin: .zero, size: project.sourceSize)
        let cropped = mode == .wholeFrame ? full : cropStep(project.crop, full: full, sourceSize: project.sourceSize)
        return frameStep(contentAspect: cropped.width / max(cropped.height, 1),
                         canvas: CGSize(width: project.output.width, height: project.output.height),
                         paddingPercent: project.style.padding)
    }

    /// Crop: the part of the source to keep, in pixels of the decoded frame. The crop is stored in
    /// the recording's pixels (`stored`), so it's rescaled if the decoded frame is a different size.
    static func cropStep(_ crop: CropRect?, full: CGRect, sourceSize stored: CGSize) -> CGRect {
        guard let crop, stored.width > 0, stored.height > 0 else { return full }
        let sx = full.width / stored.width, sy = full.height / stored.height
        let r = CGRect(x: crop.x * sx, y: crop.y * sy, width: crop.width * sx, height: crop.height * sy).intersection(full)
        return r.width >= 1 && r.height >= 1 ? r : full
    }

    /// Frame: where the video sits on the canvas, as fractions of the canvas. The padding
    /// (a percentage of the canvas height) is kept free on every side; the video is fitted
    /// inside what's left and centred.
    static func frameStep(contentAspect: CGFloat, canvas: CGSize, paddingPercent: Double) -> CGRect {
        let pad = min(canvas.height * CGFloat(paddingPercent) / 100, min(canvas.width, canvas.height) * 0.45)
        let availW = canvas.width - 2 * pad, availH = canvas.height - 2 * pad
        var w = availW, h = availW / contentAspect
        if h > availH { h = availH; w = availH * contentAspect }
        return CGRect(x: (canvas.width - w) / 2 / canvas.width, y: (canvas.height - h) / 2 / canvas.height,
                      width: w / canvas.width, height: h / canvas.height)
    }
}
