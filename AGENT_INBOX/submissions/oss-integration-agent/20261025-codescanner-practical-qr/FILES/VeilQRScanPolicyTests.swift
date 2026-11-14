import XCTest
@testable import VeilLink

final class VeilQRScanPolicyTests: XCTestCase {
    func testGeneralQRAllowsOfflineTextAndLineBreaks() throws {
        XCTAssertEqual(try VeilQRScanPolicy.validatedText("离线交换\nHello", purpose: .temporaryText), "离线交换\nHello")
    }

    func testGeneralQRRejectsEmptyAndOversizedData() {
        XCTAssertThrowsError(try VeilQRScanPolicy.validatedText("", purpose: .temporaryText)) {
            XCTAssertEqual($0 as? VeilQRScanValidationError, .empty)
        }
        XCTAssertThrowsError(try VeilQRScanPolicy.validatedText(String(repeating: "A", count: 1025), purpose: .temporaryText)) {
            XCTAssertEqual($0 as? VeilQRScanValidationError, .tooLarge)
        }
    }

    func testInvalidControlDataRejected() {
        XCTAssertThrowsError(try VeilQRScanPolicy.validatedText("Hello\u{0000}World", purpose: .temporaryText)) {
            XCTAssertEqual($0 as? VeilQRScanValidationError, .invalidControlCharacter)
        }
    }

    func testPairingRequiresSchemeAndIsBounded() throws {
        XCTAssertThrowsError(try VeilQRScanPolicy.validatedText("https://example.com/?q=1", purpose: .remotePairing)) {
            XCTAssertEqual($0 as? VeilQRScanValidationError, .nonVeilLinkPairingCode)
        }
        XCTAssertEqual(try VeilQRScanPolicy.validatedText("veillink://pair?payload", purpose: .remotePairing), "veillink://pair?payload")
        XCTAssertThrowsError(try VeilQRScanPolicy.validatedText("veillink://pair?" + String(repeating:"a", count:4096), purpose: .remotePairing)) {
            XCTAssertEqual($0 as? VeilQRScanValidationError, .tooLarge)
        }
    }

    func testGeneralQRNeverRunsCodeOrLoadsURL() throws {
        // Policy returns opaque text. There is no side effect and no URL handler.
        let text = "javascript:alert(1)"
        XCTAssertEqual(try VeilQRScanPolicy.validatedText(text, purpose: .temporaryText), text)
    }
}
