import Foundation

enum MediaTransferPolicy {
    static let targetImageBytes = 1_800_000
    static let maximumImageBytes = 3_000_000
    static let maximumImageDimension = 4_096
    static let minimumImageDimension = 1_600

    static let supportedImageMIMETypes: Set<String> = [
        "image/jpeg",
        "image/heic",
        "image/png"
    ]

    static func supportsImageMIMEType(_ mimeType: String) -> Bool {
        supportedImageMIMETypes.contains(mimeType.lowercased())
    }
}
