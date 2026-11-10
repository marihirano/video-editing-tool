import CoreVideo
import Metal

/// The one renderer used by both the preview and the export, so what you see is what you get.
/// Give it a decoded video frame and a target texture; it draws the finished frame.
/// Each user (preview, export) makes its own instance; they share one MetalContext.
public final class FrameRenderer {
    public let context: MetalContext
    let queue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?

    public init(context: MetalContext) {
        self.context = context
        self.queue = context.device.makeCommandQueue()!
        CVMetalTextureCacheCreate(nil, nil, context.device, nil, &textureCache)
    }

    public func makeCommandBuffer() -> MTLCommandBuffer? { queue.makeCommandBuffer() }

    /// Wraps a BGRA pixel buffer as a Metal texture without copying it.
    /// Pass `asTarget: true` when the renderer will draw into it (export).
    public func texture(for pixelBuffer: CVPixelBuffer, asTarget: Bool = false) -> (MTLTexture, CVMetalTexture)? {
        guard let cache = textureCache else { return nil }
        var cvTex: CVMetalTexture?
        let w = CVPixelBufferGetWidth(pixelBuffer), h = CVPixelBufferGetHeight(pixelBuffer)
        let usage: MTLTextureUsage = asTarget ? [.shaderRead, .renderTarget] : [.shaderRead]
        let attrs = [kCVMetalTextureUsage as String: usage.rawValue] as CFDictionary
        CVMetalTextureCacheCreateTextureFromImage(nil, cache, pixelBuffer, attrs, MetalContext.pixelFormat, w, h, 0, &cvTex)
        guard let cvTex, let tex = CVMetalTextureGetTexture(cvTex) else { return nil }
        return (tex, cvTex)
    }

    /// Encodes drawing one finished frame into `target`. The caller commits the command buffer.
    public func encode(frame pixelBuffer: CVPixelBuffer, uniforms: FrameUniforms,
                       into target: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let (sourceTex, cvTex) = texture(for: pixelBuffer) else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = uniforms
        enc.setRenderPipelineState(context.framePipeline)
        enc.setFragmentBytes(&u, length: MemoryLayout<FrameUniforms>.stride, index: 0)
        enc.setFragmentTexture(sourceTex, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        // Keep the wrapped frame alive until the GPU is done with it.
        commandBuffer.addCompletedHandler { _ in _ = cvTex }
    }

    /// Fills `target` with one colour (used before any video frame is available).
    public func encodeClear(_ color: RGBAColor, into target: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: color.r, green: color.g, blue: color.b, alpha: color.a)
        pass.colorAttachments[0].storeAction = .store
        commandBuffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
    }
}
