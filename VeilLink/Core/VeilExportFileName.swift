import Foundation

/// Collision-resistant names for user-initiated exports. The timestamp remains
/// human-readable while the nonce prevents two exports in the same clock tick
/// from replacing one another.
enum VeilExportFileName {
    static func make(
        prefix: String,
        suffix: String,
        date: Date = Date(),
        nonce: UUID = UUID()
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let shortNonce = nonce.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        return "\(prefix)\(formatter.string(from: date))-\(shortNonce)\(suffix)"
    }
}
