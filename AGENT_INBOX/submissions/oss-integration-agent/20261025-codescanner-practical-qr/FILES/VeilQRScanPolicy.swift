import Foundation

/// The scanner transports QR TEXT only. Every downstream operation still
/// requires the original VeilLink authorization, trust and expiry checks.
enum VeilQRScanPurpose: Equatable, Sendable {
    case temporaryText
    case remotePairing
}

enum VeilQRScanValidationError: Error, LocalizedError, Equatable {
    case empty
    case tooLarge
    case nonVeilLinkPairingCode
    case invalidControlCharacter

    var errorDescription: String? {
        switch self {
        case .empty: return "二维码没有可读取的文本。"
        case .tooLarge: return "二维码内容超出允许长度。"
        case .nonVeilLinkPairingCode: return "这不是 VeilLink 的远程配对二维码。"
        case .invalidControlCharacter: return "二维码包含不支持的控制字符。"
        }
    }
}

enum VeilQRScanPolicy {
    static func validatedText(_ content: String, purpose: VeilQRScanPurpose) throws -> String {
        guard !content.isEmpty else { throw VeilQRScanValidationError.empty }
        let limit = purpose == .temporaryText ? 1_024 : 4_096
        guard content.utf8.count <= limit else { throw VeilQRScanValidationError.tooLarge }
        for scalar in content.unicodeScalars {
            if scalar.value < 0x20 && scalar.value != 0x09 &&
                scalar.value != 0x0A && scalar.value != 0x0D {
                throw VeilQRScanValidationError.invalidControlCharacter
            }
            if scalar.value == 0x7F {
                throw VeilQRScanValidationError.invalidControlCharacter
            }
        }
        if purpose == .remotePairing && !content.hasPrefix("veillink://pair?") {
            throw VeilQRScanValidationError.nonVeilLinkPairingCode
        }
        // This is ONLY preflight. Pairing goes through the existing
        // VeilRemotePairQRCodeCodec.decode and expiry/SAS verification.
        return content
    }
}
