import CoreGraphics
import simd

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
}

/// Works out what to draw for one frame, as a chain of steps in a fixed order:
/// crop → zoom → cursor → frame and background.
///
/// Each step is its own small function. In M1 crop, zoom and cursor change nothing;
/// later milestones fill them in without touching the renderer.
public enum FrameLayout {

    public static func uniforms(project: Project, sourceSize: CGSize, sourceTime: Double) -> FrameUniforms {
        let full = CGRect(origin: .zero, size: sourceSize)
        let cropped = cropStep(project.crop, full: full)
        let visible = zoomStep(project.timeline.zooms, cropped: cropped, time: sourceTime)
        // Cursor step (phase 2) draws on top in its own pass; it doesn't change the layout.
        let canvas = CGSize(width: project.output.width, height: project.output.height)
        let style = project.style
        let content = frameStep(contentAspect: cropped.width / max(cropped.height, 1), canvas: canvas,
                                paddingPercent: style.padding)
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
            shape: SIMD4(Float(style.cornerRadius) * k, Float(style.shadowOpacity),
                         Float(style.shadowBlur) * k, Float(style.shadowOffset) * k),
            canvas: SIMD4(Float(canvas.width), Float(canvas.height), 0, 0)
        )
    }

    /// Crop (M4): the part of the source to keep, in source pixels.
    static func cropStep(_ crop: CropRect?, full: CGRect) -> CGRect {
        guard let crop else { return full }
        return CGRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height).intersection(full)
    }

    /// Zoom (M4): the part of the cropped frame visible at this moment.
    static func zoomStep(_ zooms: [ZoomSegment], cropped: CGRect, time: Double) -> CGRect {
        cropped
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
