import Metal

/// The GPU and the compiled shaders, created once and shared by preview and export.
public final class MetalContext: @unchecked Sendable {
    public static let shared: MetalContext? = try? MetalContext()

    public let device: MTLDevice
    let framePipeline: MTLRenderPipelineState
    public static let pixelFormat: MTLPixelFormat = .bgra8Unorm

    public enum ContextError: Error { case noGPU }

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw ContextError.noGPU }
        self.device = device
        let library = try device.makeLibrary(source: Shaders.source, options: nil)
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "fullscreenVertex")
        desc.fragmentFunction = library.makeFunction(name: "frameFragment")
        desc.colorAttachments[0].pixelFormat = Self.pixelFormat
        framePipeline = try device.makeRenderPipelineState(descriptor: desc)
    }
}
