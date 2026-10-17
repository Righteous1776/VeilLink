import Foundation

/// Signing-gate decision policy for the legal consent gate.
///
/// Deliberately UIKit-free so the entire signing-gate evaluation (acknowledgement
/// publishing rules + canSign) can be compiled and tested without an iOS runtime.
enum VeilLegalConsentRequirements {
    static func canSign(
        confirmsPermissions: Bool,
        confirmsRisk: Bool,
        confirmsVersionRule: Bool,
        acknowledgment: String
    ) -> Bool {
        confirmsPermissions &&
        confirmsRisk &&
        confirmsVersionRule &&
        acknowledgment.trimmingCharacters(in: .whitespacesAndNewlines) == VeilLegalConsentController.requiredAcknowledgment
    }
}

enum VeilLegalAcknowledgmentInput {
    static let accessibilityIdentifier = "legal.consent.acknowledgment"

    /// Returns the text that may be published into signing state for a field snapshot, or nil
    /// when an IME composition is still in flight and must not pollute the acknowledgement.
    static func publishableText(fieldText: String?, hasMarkedText: Bool) -> String? {
        guard !hasMarkedText else { return nil }
        return fieldText ?? ""
    }
}
