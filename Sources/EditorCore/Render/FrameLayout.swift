import CoreGraphics
import simd

/// Numbers the shader needs for one frame. Layout must match `FrameUniforms` in Shaders.swift.
public struct FrameUniforms: Equatable {
    public var background: SIMD4<Float>
    public var contentRect: SIMD4<Float>   // x, y, width, height on the canvas (0–1)
    public var sourceRect: SIMD4<Float>    // x, y, width, height in the source (0–1)
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
        let content = frameStep(contentAspect: cropped.width / max(cropped.height, 1), canvas: canvas)

        let bg = project.style.background
        return FrameUniforms(
            background: SIMD4(Float(bg.r), Float(bg.g), Float(bg.b), Float(bg.a)),
            contentRect: SIMD4(Float(content.minX), Float(content.minY), Float(content.width), Float(content.height)),
            sourceRect: SIMD4(Float(visible.minX / full.width), Float(visible.minY / full.height),
                              Float(visible.width / full.width), Float(visible.height / full.height))
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

    /// Frame (M2 adds padding, corners and shadow): where the video sits on the canvas,
    /// as fractions of the canvas. For now it's fitted inside, centred.
    static func frameStep(contentAspect: CGFloat, canvas: CGSize) -> CGRect {
        let canvasAspect = canvas.width / canvas.height
        if contentAspect > canvasAspect {
            let h = canvasAspect / contentAspect
            return CGRect(x: 0, y: (1 - h) / 2, width: 1, height: h)
        } else {
            let w = contentAspect / canvasAspect
            return CGRect(x: (1 - w) / 2, y: 0, width: w, height: 1)
        }
    }
}
