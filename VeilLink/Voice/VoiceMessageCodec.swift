import Foundation

struct VeilVoiceMessageMetadata: Equatable, Sendable {
    let durationMilliseconds: Int

    var durationSeconds: Double { Double(durationMilliseconds) / 1000.0 }
    var compactDuration: String {
        let seconds = max(1, Int(durationSeconds.rounded()))
        return "\(seconds)″"
    }
}

enum VoiceMessageCodec {
    static let prefix = "VLVOICE1:"
    static let mimeTypes: Set<String> = ["audio/mp4", "audio/x-m4a", "audio/aac", "audio/m4a"]
    static let maximumDurationSeconds: Double = 60
    static let maximumBytes = 2 * 1_024 * 1_024

    static func encode(durationSeconds: Double) -> String {
        let clamped = min(max(durationSeconds, 0), maximumDurationSeconds)
        return prefix + String(Int((clamped * 1000).rounded()))
    }

    static func decode(_ body: String) -> VeilVoiceMessageMetadata? {
        guard body.hasPrefix(prefix),
              let ms = Int(body.dropFirst(prefix.count)),
              ms >= 250,
              ms <= Int(maximumDurationSeconds * 1000) else { return nil }
        return VeilVoiceMessageMetadata(durationMilliseconds: ms)
    }

    static func preview(durationSeconds: Double) -> String {
        let seconds = max(1, Int(durationSeconds.rounded()))
        return "[语音] \(seconds)″"
    }

    static func isVoiceMIMEType(_ value: String) -> Bool {
        mimeTypes.contains(value.lowercased())
    }
}
