// Linux test shim.
//
// VeilLegalConsentController (VeilLink/Legal/VeilLegalConsentController.swift) imports
// Combine/CryptoKit and cannot compile on Linux. The behaviour harness only needs its
// `requiredAcknowledgment` contract constant; the value below is mirrored verbatim from
// line 19 of that file. macOS XCTest (LegalConsentTests) exercises the real controller.
enum VeilLegalConsentController {
    static let requiredAcknowledgment = "我已阅读并同意"
}
