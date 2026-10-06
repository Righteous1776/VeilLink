import XCTest
@testable import VeilLink

final class LegalConsentTests: XCTestCase {
    func testLegalDocumentIsNonEmptyAndContainsMandatoryBoundary() {
        XCTAssertFalse(VeilLegalDocuments.permissions.isEmpty)
        XCTAssertFalse(VeilLegalDocuments.terms.isEmpty)
        XCTAssertTrue(VeilLegalDocuments.terms.contains("故意或者重大过失"))
        XCTAssertTrue(VeilLegalDocuments.terms.contains("紧急"))
        XCTAssertTrue(VeilLegalDocuments.permissions.contains("Internet Relay"))
    }

    func testCanonicalDocumentChangesWhenEitherDocumentChanges() {
        XCTAssertTrue(VeilLegalDocuments.canonicalText.contains(VeilLegalDocuments.permissions))
        XCTAssertTrue(VeilLegalDocuments.canonicalText.contains(VeilLegalDocuments.terms))
    }

    func testSigningRequiresAllThreeConfirmationsAndExactAcknowledgment() {
        let phrase = VeilLegalConsentController.requiredAcknowledgment

        XCTAssertFalse(VeilLegalConsentRequirements.canSign(
            confirmsPermissions: false,
            confirmsRisk: true,
            confirmsVersionRule: true,
            acknowledgment: phrase
        ))
        XCTAssertFalse(VeilLegalConsentRequirements.canSign(
            confirmsPermissions: true,
            confirmsRisk: true,
            confirmsVersionRule: true,
            acknowledgment: "不同意"
        ))
        XCTAssertTrue(VeilLegalConsentRequirements.canSign(
            confirmsPermissions: true,
            confirmsRisk: true,
            confirmsVersionRule: true,
            acknowledgment: "  \(phrase)\n"
        ))
    }

    func testSigningControlsHaveDistinctAutomationIdentifiers() {
        let identifiers = [
            VeilLegalConsentAccessibility.permissionsDocument,
            VeilLegalConsentAccessibility.boundaryDocument,
            VeilLegalConsentAccessibility.permissionsConfirmation,
            VeilLegalConsentAccessibility.riskConfirmation,
            VeilLegalConsentAccessibility.versionConfirmation,
            VeilLegalAcknowledgmentInput.accessibilityIdentifier
        ]
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    @MainActor
    func testAcknowledgmentFieldHasStableTelemetryExclusionIdentifier() {
        XCTAssertEqual(
            VeilLegalAcknowledgmentInput.accessibilityIdentifier,
            "legal.consent.acknowledgment"
        )
        XCTAssertFalse(
            DeepTelemetry.shouldCaptureTextField(
                identifier: VeilLegalAcknowledgmentInput.accessibilityIdentifier
            )
        )
        XCTAssertTrue(DeepTelemetry.shouldCaptureTextField(identifier: "chat.composer"))
    }
}
