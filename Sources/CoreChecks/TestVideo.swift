import AVFoundation

/// Makes a small moving-colour test video, so checks don't need a real recording.
enum TestVideo {
    static func make(at url: URL, width: Int, height: Int, seconds: Int, fps: Int) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for n in 0..<(seconds * fps) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            guard let pb else { continue }
            CVPixelBufferLockBaseAddress(pb, [])
            let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pb)
            for y in 0..<height {
                let row = base + y * stride
                for x in 0..<width {
                    row[x * 4] = UInt8((x + n * 8) & 255); row[x * 4 + 1] = UInt8(y & 255)
                    row[x * 4 + 2] = UInt8((n * 4) & 255); row[x * 4 + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()
    }
}
