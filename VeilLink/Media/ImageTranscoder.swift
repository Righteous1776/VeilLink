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
        case .stillTooLarge: return "图片无法安全压缩到可传输范围（最大 3 MB）。"
        }
    }
}

enum ImageTranscoder {

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
        let textSensitive = isLikelyTextOrGraphic(type: sourceType, dimensions: sourceInfo)

        // The profile no longer changes output quality. A queued image may move
        // between BLE and LAN without being recompressed or mutated.
        _ = profile
        let requestedEdge = MediaTransferPolicy.compressedLongestEdge(
            originalWidth: sourceInfo?.width ?? MediaTransferPolicy.maximumImageDimension,
            originalHeight: sourceInfo?.height ?? MediaTransferPolicy.maximumImageDimension,
            isLikelyTextOrGraphic: textSensitive
        )
        guard let bitmap = decodeImage(
            url: url, source: source, maximumDimension: requestedEdge
        ) else { throw ImagePreparationError.unsupported }

        var smallest: PreparedImage?

        // The source can occasionally be smaller than a re-encode (e.g. an
        // optimized PNG of flat UI). Keep it only if it is a valid wire type.
        if let type = sourceType, let size = sourceInfo,
           max(size.width, size.height) <= MediaTransferPolicy.maximumImageDimension,
           MediaTransferPolicy.mayTransmit(byteCount: originalByteCount) {
            let originalEncoding: (mime: String, label: String)?
            if type.conforms(to: .jpeg) {
                originalEncoding = ("image/jpeg", "JPEG")
            } else if type == .heic {
                originalEncoding = ("image/heic", "HEIC")
            } else if type.conforms(to: .png) {
                originalEncoding = ("image/png", "PNG")
            } else {
                originalEncoding = nil
            }
            if let encoding = originalEncoding,
               let bytes = try? Data(contentsOf: url, options: [.mappedIfSafe]),
               bytes.count == originalByteCount {
                smallest = PreparedImage(
                    data: bytes, mimeType: encoding.mime,
                    sourceFormat: sourceFormat, outputFormat: encoding.label,
                    originalByteCount: originalByteCount,
                    pixelWidth: size.width, pixelHeight: size.height,
                    wasTranscoded: false
                )
            }
        }

        // Screenshots deliberately use an aggressive 500 px short edge and
        // 0.18 lossy quality. For long screenshots the short edge matters
        // more than reducing the longest dimension to a fixed 1280 px.
        // Compare ACTUAL encoded byte counts rather than stopping at a target.
        let native = preferredOutputEncoding()
        var encodings: [(type: CFString, mime: String, label: String)] = [
            (UTType.jpeg.identifier as CFString, "image/jpeg", "JPEG")
        ]
        if native.mimeType == "image/heic" {
            encodings.insert((native.type, native.mimeType, native.label), at: 0)
        }
        if textSensitive {
            // Screenshots with flat colors and tiny lettering may be smaller
            // AND clearer as a downsampled PNG; it must compete by byte count.
            encodings.append((UTType.png.identifier as CFString, "image/png", "PNG"))
        }

        for encoding in encodings {
            try Task.checkCancellation()
            let quality: CGFloat = encoding.mime == "image/png" ? 1 :
                CGFloat(MediaTransferPolicy.extremeQuality(isLikelyTextOrGraphic: textSensitive))
            guard let bytes = encode(bitmap, as: encoding.type, quality: quality),
                  MediaTransferPolicy.mayTransmit(byteCount: bytes.count),
                  bytes.count < (smallest?.data.count ?? Int.max),
                  isDecodable(bytes) else { continue }

            smallest = PreparedImage(
                data: bytes,
                mimeType: encoding.mime,
                sourceFormat: sourceFormat,
                outputFormat: encoding.label,
                originalByteCount: originalByteCount,
                pixelWidth: bitmap.width,
                pixelHeight: bitmap.height,
                wasTranscoded: true
            )
        }

        if let smallest { return smallest }
        throw ImagePreparationError.stillTooLarge
    }

    private static func isLikelyTextOrGraphic(
        type: UTType?, dimensions: (width: Int, height: Int)?
    ) -> Bool {
        if type?.conforms(to: .png) == true { return true }
        guard let dimensions else { return false }
        let short = min(dimensions.width, dimensions.height)
        guard short > 0 else { return false }
        // Very tall phone screenshots should retain more pixels for text.
        return Double(max(dimensions.width, dimensions.height)) / Double(short) > 1.9
    }

    private static func isDecodable(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ), CGImageSourceGetCount(source) > 0 else { return false }
        return CGImageSourceCreateImageAtIndex(
            source, 0, [kCGImageSourceShouldCache: false] as CFDictionary
        ) != nil
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
            [
                kCGImageDestinationLossyCompressionQuality: quality,
                kCGImageDestinationBackgroundColor: CGColor(gray: 1, alpha: 1)
            ] as CFDictionary
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
