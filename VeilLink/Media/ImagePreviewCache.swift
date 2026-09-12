import ImageIO
import UIKit

/// Device-budgeted preview cache. NSCache is thread-safe, so callers can decode off-main without
/// serializing every cache hit behind an extra lock. Source attachment bytes remain encrypted and
/// untouched; only display-sized thumbnails are cached in memory.
final class ImagePreviewCache: @unchecked Sendable {
    static let shared = ImagePreviewCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        reconfigureForCurrentProfile()
    }

    func reconfigureForCurrentProfile() {
        let profile = VeilDevicePerformance.current
        cache.countLimit = profile.imagePreviewCacheCount
        cache.totalCostLimit = profile.imagePreviewCacheBytes
    }

    func image(for attachmentID: String) -> UIImage? {
        cache.object(forKey: attachmentID as NSString)
    }

    func insert(_ image: UIImage, for attachmentID: String) {
        let pixels = max(1, Int(image.size.width * image.scale) * Int(image.size.height * image.scale))
        let cost = min(Int.max / 4, pixels * 4)
        cache.setObject(image, forKey: attachmentID as NSString, cost: cost)
    }

    func remove(_ attachmentID: String) {
        cache.removeObject(forKey: attachmentID as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    /// Device-specific thumbnail limits keep A9/A10 decode peaks small while allowing the
    /// iPhone 13 Pro to retain a visibly sharper preview. ImageIO never expands the full source.
    static func downsample(data: Data, maxPixelSize: Int? = nil) -> UIImage? {
        let targetPixels = maxPixelSize ?? VeilDevicePerformance.current.imagePreviewMaxPixelSize
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(256, targetPixels),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
