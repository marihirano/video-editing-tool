import AVFoundation
import VideoToolbox

/// Writer settings for an H.264 MP4 at the project's output size.
enum EncoderSettings {
    static func video(for output: OutputSettings, requireHardware: Bool) -> [String: Any] {
        let megapixels = Double(output.width * output.height) / 1_000_000
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: Int(megapixels * Settings.exportBitsPerMegapixel),
            AVVideoMaxKeyFrameIntervalDurationKey: Settings.exportKeyframeIntervalSeconds,
            AVVideoExpectedSourceFrameRateKey: output.fps,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ]
        compression[AVVideoAllowFrameReorderingKey] = true
        var settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: output.width,
            AVVideoHeightKey: output.height,
            AVVideoCompressionPropertiesKey: compression,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        if requireHardware {
            settings[AVVideoEncoderSpecificationKey] = [
                kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder as String: true,
            ]
        }
        return settings
    }

    /// Pixel buffers the renderer draws into and the encoder reads from.
    static func pixelBuffers(for output: OutputSettings) -> [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: output.width,
            kCVPixelBufferHeightKey as String: output.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ]
    }
}
