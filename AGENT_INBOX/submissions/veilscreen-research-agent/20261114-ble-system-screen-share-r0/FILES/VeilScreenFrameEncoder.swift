#if os(iOS)
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Video-only compressor; caller controls consent, SCK capture, frame pace and E2EE.
final class VeilScreenFrameEncoder {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    struct Result {
        let jpeg: Data
        let width: Int
        let height: Int
    }

    func encodeVideoSample(_ sample: CMSampleBuffer,
                           targetWidth: Int,
                           byteBudget: Int) -> Result? {
        guard CMSampleBufferIsValid(sample),
              let pixel = CMSampleBufferGetImageBuffer(sample),
              (64...2048).contains(targetWidth),
              (1...VeilScreenShareChunk.maximumFrameBytes).contains(byteBudget) else { return nil }
        let originalWidth = CVPixelBufferGetWidth(pixel)
        let originalHeight = CVPixelBufferGetHeight(pixel)
        guard originalWidth > 0 && originalHeight > 0 else { return nil }
        let image = CIImage(cvPixelBuffer: pixel)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.12
            ])

        for candidate in [targetWidth, max(192, targetWidth * 3 / 4), max(128, targetWidth / 2)] {
            let width = min(candidate, originalWidth)
            let scale = CGFloat(width) / CGFloat(originalWidth)
            let height = max(64, Int((CGFloat(originalHeight) * scale).rounded()))
            guard height <= 2048 else { continue }
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            guard let cgImage = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: width, height: height)) else { continue }
            for quality in [0.36, 0.23, 0.13, 0.07] {
                let payload = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(payload, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
                CGImageDestinationAddImage(destination, cgImage, [
                    kCGImageDestinationLossyCompressionQuality: quality
                ] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { continue }
                let data = payload as Data
                if data.count <= byteBudget {
                    return Result(jpeg: data, width: width, height: height)
                }
            }
        }
        return nil
    }
}
#endif
