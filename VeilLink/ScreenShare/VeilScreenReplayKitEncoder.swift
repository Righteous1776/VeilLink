#if os(iOS)
import Foundation
import CoreImage
import CoreMedia
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

/// A standalone extension-safe codec: no references to the main-app session manager.
final class VeilScreenReplayKitEncoder {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func compress(_ sample: CMSampleBuffer, width targetWidth: Int,
                  byteBudget: Int) -> (Data, Int, Int)? {
        guard CMSampleBufferIsValid(sample), let pixel = CMSampleBufferGetImageBuffer(sample),
              (128...1024).contains(targetWidth), (512...32768).contains(byteBudget) else { return nil }
        let sw = CVPixelBufferGetWidth(pixel), sh = CVPixelBufferGetHeight(pixel)
        guard sw > 0, sh > 0 else { return nil }
        let original = CIImage(cvPixelBuffer: pixel).applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0, kCIInputContrastKey: 1.18
        ])
        // Quality vs readability: try full width first; only degrade size on byte budget failure.
        for w in [targetWidth, max(192, targetWidth * 3 / 4), max(128, targetWidth / 2)] {
            let width = min(w, sw)
            let factor = CGFloat(width) / CGFloat(sw)
            let height = Int(CGFloat(sh) * factor)
            guard (64...2048).contains(height) else { continue }
            let scaled = original.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
            guard let cgImage = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: width, height: height)) else { continue }
            for quality in [0.52, 0.34, 0.19, 0.10] {
                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
                CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { continue }
                let bytes = output as Data
                if bytes.count <= byteBudget { return (bytes, width, height) }
            }
        }
        return nil  // Drop instead of building large queues that block chat.
    }
}
#endif
