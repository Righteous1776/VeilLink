import Foundation

/// Selecting a profile never blocks transmission; it is an encoding hint.
enum ImageTransportProfile: Sendable, Equatable {
    case bluetooth, fastLAN
}

enum MediaTransferPolicy {
    static let targetImageBytes = 1_800_000
    static let maximumImageBytes = 3_000_000
    static let maximumImageDimension = 4_096
    static let minimumImageDimension = 1_600

    // Screen content is the primary BLE use case. Preserve an aggressively
    // downsampled *short edge* rather than shrinking the longest edge of a
    // scrolling screenshot until all text is microscopic.
    static let screenshotShortEdge = 500
    static let screenshotMaximumLongEdge = maximumImageDimension
    static let screenshotLossyQuality = 0.18

    // Ordinary photos still use a stricter longest-edge byte-saving path.
    static let photoLongestEdge = 640
    static let photoLossyQuality = 0.28

    static func compressedLongestEdge(
        originalWidth: Int, originalHeight: Int, isLikelyTextOrGraphic: Bool
    ) -> Int {
        let longest = max(1, max(originalWidth, originalHeight))
        guard isLikelyTextOrGraphic else { return min(longest, photoLongestEdge) }
        let shortest = max(1, min(originalWidth, originalHeight))
        let ratio = Double(longest) / Double(shortest)
        let preferred = Int((Double(screenshotShortEdge) * ratio).rounded(.up))
        return max(1, min(longest, screenshotMaximumLongEdge, preferred))
    }

    static func extremeQuality(isLikelyTextOrGraphic: Bool) -> Double {
        isLikelyTextOrGraphic ? screenshotLossyQuality : photoLossyQuality
    }

    // BLE preferences, not admission restrictions.
    static let bleTargetBytes = 200_000
    static let blePreferredBytes = 384_000

    static func preferredBytes(for path: ImageTransportProfile) -> Int {
        path == .bluetooth ? blePreferredBytes : maximumImageBytes
    }

    static func preferredDimension(for path: ImageTransportProfile) -> Int {
        path == .bluetooth ? 1_600 : maximumImageDimension
    }

    static func qualityRange(for path: ImageTransportProfile) -> (start: Double, floor: Double) {
        path == .bluetooth ? (0.90, 0.78) : (0.96, 0.84)
    }

    static func mayTransmit(byteCount: Int) -> Bool {
        byteCount > 0 && byteCount <= maximumImageBytes
    }

    static func preferCandidate(bytes: Int, over currentBytes: Int?) -> Bool {
        guard mayTransmit(byteCount: bytes) else { return false }
        guard let currentBytes else { return true }
        // 22%+ reduction before sacrificing resolution/quality.
        return Double(bytes) < Double(currentBytes) * 0.78
    }

    static func nextQuality(
        after quality: Double, encodedBytes: Int, preferredBytes: Int, minimum: Double
    ) -> Double? {
        guard preferredBytes > 0, encodedBytes > preferredBytes,
              quality > minimum + 0.025 else { return nil }
        let ratio = max(0.05, min(1.0, Double(preferredBytes) / Double(encodedBytes)))
        let value = max(minimum, min(quality - 0.035, quality * pow(ratio, 0.20)))
        return value < quality - 0.025 ? value : nil
    }

    static let supportedImageMIMETypes: Set<String> = [
        "image/jpeg",
        "image/heic",
        "image/png"
    ]

    static func supportsImageMIMEType(_ mimeType: String) -> Bool {
        supportedImageMIMETypes.contains(mimeType.lowercased())
    }

    /// A future authenticated generic-file lane must enforce this before staging.
    /// This policy alone does not add an on-wire content kind or transmit files.
    static let maximumGenericFileBytes = 2_000_000
    static let genericFileCapabilityBit = 1 << 3

    static func safeGenericFilename(_ name: String) -> String? {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != ".", value != "..",
              value.lengthOfBytes(using: .utf8) <= 180,
              !value.contains("/"), !value.contains("\\"),
              !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            return nil
        }
        return value
    }

    static func genericFileMIMEType(for filename: String) -> String {
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "zip": return "application/zip"
        case "json": return "application/json"
        case "txt", "log": return "text/plain"
        case "md", "markdown": return "text/markdown"
        case "csv": return "text/csv"
        default: return "application/octet-stream"
        }
    }
}
