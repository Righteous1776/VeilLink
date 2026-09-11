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
    private static let qualitySteps: [CGFloat] = [0.94, 0.90, 0.86, 0.82, 0.78, 0.72, 0.66]
    private static let dimensionSteps = [4_096, 3_584, 3_072, 2_560, 2_048, 1_600]

    static func prepare(at url: URL) async throws -> PreparedImage {
        try await Task.detached(priority: .userInitiated) {
            try prepareSynchronously(at: url)
        }.value
    }

    static func prepareSynchronously(at url: URL) throws -> PreparedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            // Some RAW variants are only exposed through Core Image. Keep going if CI can open it.
            guard CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) != nil else {
                throw ImagePreparationError.unreadable
            }
            return try transcode(url: url, source: nil)
        }
        return try transcode(url: url, source: source)
    }

    private static func transcode(url: URL, source: CGImageSource?) throws -> PreparedImage {
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
            dimensions: sourceInfo
        ) {
            return preserved
        }

        let preferredEncoding = preferredOutputEncoding()
        var bestUnderHardLimit: PreparedImage?

        for dimension in effectiveDimensions(original: sourceInfo) {
            guard let cgImage = decodeImage(url: url, source: source, maximumDimension: dimension) else { continue }
            for quality in qualitySteps {
                guard let encoded = encode(cgImage, as: preferredEncoding.type, quality: quality) else { continue }
                let prepared = PreparedImage(
                    data: encoded,
                    mimeType: preferredEncoding.mimeType,
                    sourceFormat: sourceFormat,
                    outputFormat: preferredEncoding.label,
                    originalByteCount: originalByteCount,
                    pixelWidth: cgImage.width,
                    pixelHeight: cgImage.height,
                    wasTranscoded: true
                )
                if encoded.count <= MediaTransferPolicy.targetImageBytes { return prepared }
                if bestUnderHardLimit == nil, encoded.count <= MediaTransferPolicy.maximumImageBytes {
                    bestUnderHardLimit = prepared
                }
            }
        }

        // Quality wins over hitting the soft target. If HEIC produced a high-quality image
        // under the hard protocol limit, keep it instead of needlessly switching codecs.
        if let bestUnderHardLimit { return bestUnderHardLimit }

        // HEIC encoding can be unavailable on unusual devices/OS builds. JPEG is the fallback.
        if preferredEncoding.mimeType != "image/jpeg" {
            for dimension in effectiveDimensions(original: sourceInfo) {
                guard let cgImage = decodeImage(url: url, source: source, maximumDimension: dimension) else { continue }
                for quality in qualitySteps {
                    guard let encoded = encode(cgImage, as: UTType.jpeg.identifier as CFString, quality: quality) else { continue }
                    let prepared = PreparedImage(
                        data: encoded,
                        mimeType: "image/jpeg",
                        sourceFormat: sourceFormat,
                        outputFormat: "JPEG",
                        originalByteCount: originalByteCount,
                        pixelWidth: cgImage.width,
                        pixelHeight: cgImage.height,
                        wasTranscoded: true
                    )
                    if encoded.count <= MediaTransferPolicy.targetImageBytes { return prepared }
                    if bestUnderHardLimit == nil, encoded.count <= MediaTransferPolicy.maximumImageBytes {
                        bestUnderHardLimit = prepared
                    }
                }
            }
        }

        if let bestUnderHardLimit { return bestUnderHardLimit }
        throw sourceType?.conforms(to: .image) == true ? ImagePreparationError.stillTooLarge : ImagePreparationError.unsupported
    }

    private static func preserveIfAppropriate(
        url: URL,
        byteCount: Int,
        type: UTType?,
        sourceFormat: String,
        dimensions: (width: Int, height: Int)?
    ) throws -> PreparedImage? {
        guard let type, let dimensions,
              max(dimensions.width, dimensions.height) <= MediaTransferPolicy.maximumImageDimension else { return nil }

        let mapping: (mime: String, label: String, limit: Int)?
        if type.conforms(to: .jpeg) {
            mapping = ("image/jpeg", "JPEG", MediaTransferPolicy.targetImageBytes)
        } else if type == .heic {
            mapping = ("image/heic", "HEIC", MediaTransferPolicy.targetImageBytes)
        } else if type.conforms(to: .png) {
            // Keep smaller screenshots/graphics lossless instead of forcing a lossy photo codec.
            mapping = ("image/png", "PNG", MediaTransferPolicy.maximumImageBytes)
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

    private static func effectiveDimensions(original: (width: Int, height: Int)?) -> [Int] {
        let originalMaximum = original.map { max($0.width, $0.height) } ?? MediaTransferPolicy.maximumImageDimension
        if originalMaximum <= MediaTransferPolicy.minimumImageDimension { return [max(originalMaximum, 1)] }
        let ceiling = min(originalMaximum, MediaTransferPolicy.maximumImageDimension)
        var values = [ceiling]
        for candidate in dimensionSteps where candidate < ceiling && candidate >= MediaTransferPolicy.minimumImageDimension {
            if !values.contains(candidate) { values.append(candidate) }
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
