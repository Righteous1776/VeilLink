import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PreparedImage: Sendable {
    let data: Data
    let mimeType: String
    let sourceFormat: String
    let outputFormat: String
    let originalByteCount: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let wasTranscoded: Bool

    var summary: String {
        let before = ByteCountFormatter.string(fromByteCount: Int64(originalByteCount), countStyle: .file)
        let after = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        if wasTranscoded {
            return "\(sourceFormat) → \(outputFormat) · \(before) → \(after) · \(pixelWidth)×\(pixelHeight)"
        }
        return "\(outputFormat) 原样 · \(after) · \(pixelWidth)×\(pixelHeight)"
    }
}

enum ImagePreparationError: LocalizedError {
    case unreadable
    case unsupported
    case stillTooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable: return "无法读取这张图片。"
        case .unsupported: return "当前系统无法解码这种图片或 RAW 格式。"
        case .stillTooLarge: return "在优先保证画质的压缩策略下，图片仍超过 3 MB。"
        }
    }
}

enum ImageTranscoder {
    private static let dimensionSteps = [4_096, 3_072, 2_560, 2_048, 1_600, 1_280, 1_024, 800, 640]

    static func prepare(
        at url: URL, profile: ImageTransportProfile = .bluetooth
    ) async throws -> PreparedImage {
        try await Task.detached(priority: .userInitiated) {
            try prepareSynchronously(at: url, profile: profile)
        }.value
    }

    static func prepareSynchronously(
        at url: URL, profile: ImageTransportProfile = .bluetooth
    ) throws -> PreparedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            // Some RAW variants are only exposed through Core Image. Keep going if CI can open it.
            guard CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) != nil else {
                throw ImagePreparationError.unreadable
            }
            return try transcode(url: url, source: nil, profile: profile)
        }
        return try transcode(url: url, source: source, profile: profile)
    }

    private static func transcode(
        url: URL, source: CGImageSource?, profile: ImageTransportProfile
    ) throws -> PreparedImage {
        let originalByteCount = fileSize(at: url)
        guard originalByteCount > 0 else { throw ImagePreparationError.unreadable }
        let sourceType = sourceUTType(for: url, source: source)
        let sourceFormat = displayName(for: sourceType, url: url)
        let sourceInfo = imageDimensions(source: source)

        if let preserved = try preserveIfAppropriate(
            url: url,
            byteCount: originalByteCount,
            type: sourceType,
            sourceFormat: sourceFormat,
            dimensions: sourceInfo, profile: profile
        ) {
            return preserved
        }

        let preferred = MediaTransferPolicy.preferredBytes(for: profile)
        let dimensions = effectiveDimensions(original: sourceInfo, profile: profile)
        var fallback: PreparedImage?

        // Retain the original if it is valid on Wire v4. A failed attempt to
        // meet the BLE soft target must not turn a valid image into an error.
        if let type = sourceType, let size = sourceInfo,
           max(size.width, size.height) <= MediaTransferPolicy.maximumImageDimension,
           MediaTransferPolicy.mayTransmit(byteCount: originalByteCount) {
            let originalFormat: (mime: String, label: String)?
            if type.conforms(to: .jpeg) {
                originalFormat = ("image/jpeg", "JPEG")
            } else if type == .heic {
                originalFormat = ("image/heic", "HEIC")
            } else if type.conforms(to: .png) {
                originalFormat = ("image/png", "PNG")
            } else { originalFormat = nil }
            if let originalFormat {
                let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
                if bytes.count == originalByteCount {
                    fallback = PreparedImage(
                        data: bytes, mimeType: originalFormat.mime,
                        sourceFormat: sourceFormat, outputFormat: originalFormat.label,
                        originalByteCount: originalByteCount,
                        pixelWidth: size.width, pixelHeight: size.height,
                        wasTranscoded: false
                    )
                }
            }
        }

        // Alpha-bearing screenshots stay PNG. Reducing dimensions is not
        // mathematically lossless, but does not destroy transparency.
        if sourceType?.conforms(to: .png) == true,
           let first = dimensions.first,
           let preview = decodeImage(url: url, source: source, maximumDimension: first),
           hasAlpha(preview) {
            for dimension in dimensions {
                try Task.checkCancellation()
                guard let bitmap = decodeImage(
                    url: url, source: source, maximumDimension: dimension
                ), let bytes = encode(
                    bitmap, as: UTType.png.identifier as CFString, quality: 1
                ) else { continue }
                let prepared = PreparedImage(
                    data: bytes, mimeType: "image/png",
                    sourceFormat: sourceFormat, outputFormat: "PNG",
                    originalByteCount: originalByteCount,
                    pixelWidth: bitmap.width, pixelHeight: bitmap.height,
                    wasTranscoded: true
                )
                if bytes.count <= preferred { return prepared }
                if MediaTransferPolicy.preferCandidate(
                    bytes: bytes, over: fallback?.data.count
                ) { fallback = prepared }
            }
            if let fallback { return fallback }
            throw ImagePreparationError.stillTooLarge
        }

        let native = preferredOutputEncoding()
        let encodings: [(type: CFString, mime: String, label: String)] =
            native.mimeType == "image/jpeg"
                ? [(native.type, "image/jpeg", "JPEG")]
                : [
                    (native.type, "image/heic", "HEIC"),
                    (UTType.jpeg.identifier as CFString, "image/jpeg", "JPEG")
                ]
        let qualityRange = MediaTransferPolicy.qualityRange(for: profile)
        for encoding in encodings {
            for dimension in dimensions {
                try Task.checkCancellation()
                guard let bitmap = decodeImage(
                    url: url, source: source, maximumDimension: dimension
                ) else { continue }
                var quality = qualityRange.start
                for _ in 0..<3 {
                    try Task.checkCancellation()
                    guard let bytes = encode(
                        bitmap, as: encoding.type, quality: CGFloat(quality)
                    ) else { break }
                    let candidate = PreparedImage(
                        data: bytes, mimeType: encoding.mime,
                        sourceFormat: sourceFormat, outputFormat: encoding.label,
                        originalByteCount: originalByteCount,
                        pixelWidth: bitmap.width, pixelHeight: bitmap.height,
                        wasTranscoded: true
                    )
                    // 384 KB is the preferred result, NOT a requirement.
                    if bytes.count <= preferred { return candidate }
                    if MediaTransferPolicy.preferCandidate(
                        bytes: bytes, over: fallback?.data.count
                    ) { fallback = candidate }
                    guard let q = MediaTransferPolicy.nextQuality(
                        after: quality, encodedBytes: bytes.count,
                        preferredBytes: preferred, minimum: qualityRange.floor
                    ) else { break }
                    quality = q
                }
            }
        }
        // Existing 48KiB chunks/ACK/checkpoints will send a larger image via
        // BLE if necessary. Never mutate an attachment after enqueue.
        if let fallback { return fallback }

        throw sourceType?.conforms(to: .image) == true ? ImagePreparationError.stillTooLarge : ImagePreparationError.unsupported
    }

    private static func preserveIfAppropriate(
        url: URL,
        byteCount: Int,
        type: UTType?,
        sourceFormat: String,
        dimensions: (width: Int, height: Int)?,
        profile: ImageTransportProfile
    ) throws -> PreparedImage? {
        guard let type, let dimensions,
              max(dimensions.width, dimensions.height) <= MediaTransferPolicy.maximumImageDimension else { return nil }

        let mapping: (mime: String, label: String, limit: Int)?
        if type.conforms(to: .jpeg) {
            mapping = ("image/jpeg", "JPEG", MediaTransferPolicy.preferredBytes(for: profile))
        } else if type == .heic {
            mapping = ("image/heic", "HEIC", MediaTransferPolicy.preferredBytes(for: profile))
        } else if type.conforms(to: .png) {
            // Keep smaller screenshots/graphics lossless instead of forcing a lossy photo codec.
            mapping = ("image/png", "PNG", MediaTransferPolicy.preferredBytes(for: profile))
        } else {
            mapping = nil
        }
        guard let mapping, byteCount <= mapping.limit else { return nil }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count == byteCount else { throw ImagePreparationError.unreadable }
        return PreparedImage(
            data: data,
            mimeType: mapping.mime,
            sourceFormat: sourceFormat,
            outputFormat: mapping.label,
            originalByteCount: byteCount,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height,
            wasTranscoded: false
        )
    }

    private static func effectiveDimensions(
        original: (width: Int, height: Int)?, profile: ImageTransportProfile
    ) -> [Int] {
        let longest = original.map { max($0.width, $0.height) }
            ?? MediaTransferPolicy.maximumImageDimension
        let ceiling = max(1, min(longest, MediaTransferPolicy.preferredDimension(for: profile)))
        var values = [ceiling]
        for candidate in dimensionSteps where candidate < ceiling &&
            candidate >= (profile == .bluetooth ? 640 : MediaTransferPolicy.minimumImageDimension) {
            values.append(candidate)
        }
        return values
    }

    private static func decodeImage(url: URL, source: CGImageSource?, maximumDimension: Int) -> CGImage? {
        if let source {
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
                kCGImageSourceShouldCacheImmediately: true
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
                return image
            }
        }

        // Fallback path for RAW formats supported by Core Image on the current device/OS.
        guard let ciImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { return nil }
        let extent = ciImage.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }
        let maxSide = max(extent.width, extent.height)
        let scale = min(1, CGFloat(maximumDimension) / maxSide)
        let output = scale < 1 ? ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : ciImage
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: output.extent)
    }

    private static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    private static func encode(_ image: CGImage, as type: CFString, quality: CGFloat) -> Data? {
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutable, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutable as Data
    }

    private static func preferredOutputEncoding() -> (type: CFString, mimeType: String, label: String) {
        let supported = CGImageDestinationCopyTypeIdentifiers() as NSArray
        if supported.contains(UTType.heic.identifier) {
            return (UTType.heic.identifier as CFString, "image/heic", "HEIC")
        }
        return (UTType.jpeg.identifier as CFString, "image/jpeg", "JPEG")
    }

    private static func sourceUTType(for url: URL, source: CGImageSource?) -> UTType? {
        if let source, let identifier = CGImageSourceGetType(source) {
            return UTType(identifier as String)
        }
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType { return type }
        return UTType(filenameExtension: url.pathExtension)
    }

    private static func imageDimensions(source: CGImageSource?) -> (width: Int, height: Int)? {
        guard let source,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { return nil }
        return (width.intValue, height.intValue)
    }

    private static func fileSize(at url: URL) -> Int {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize { return size }
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    private static func displayName(for type: UTType?, url: URL) -> String {
        if let type {
            if type.conforms(to: .rawImage) { return "RAW" }
            if type == .heic { return "HEIC" }
            if type.conforms(to: .jpeg) { return "JPEG" }
            if type.conforms(to: .png) { return "PNG" }
            if let extensionName = type.preferredFilenameExtension?.uppercased() { return extensionName }
        }
        return url.pathExtension.isEmpty ? "IMAGE" : url.pathExtension.uppercased()
    }
}
