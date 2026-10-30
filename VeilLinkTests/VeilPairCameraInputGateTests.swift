import XCTest
@testable import VeilLink

final class VeilPairCameraInputGateTests: XCTestCase {
    private let prefix = "veillink://pair?v=1&d="

    func testSyntheticBase64URLPassesInputShapeOnly() {
        XCTAssertTrue(VeilPairCameraInputGate.accepts(prefix + "Abc12345-_"))
        // Valid input shape MUST NOT be mistaken for an authenticated QR.
    }

    func testRejectsOtherSchemesAndWrongVersion() {
        XCTAssertFalse(VeilPairCameraInputGate.accepts("https://example.org"))
        XCTAssertFalse(VeilPairCameraInputGate.accepts("veillink://pair?v=2&d=Abc12345"))
        XCTAssertFalse(VeilPairCameraInputGate.accepts("veillink://pair?v=1&d="))
    }

    func testRejectsWhitespaceAndUntrustedAlphabet() {
        XCTAssertFalse(VeilPairCameraInputGate.accepts(prefix + "Abc12345\n"))
        XCTAssertFalse(VeilPairCameraInputGate.accepts(prefix + "Abc12345%"))
        XCTAssertFalse(VeilPairCameraInputGate.accepts(prefix + "Abc12345/"))
        XCTAssertFalse(VeilPairCameraInputGate.accepts(prefix + "中文123456"))
    }

    func testPreventsOversizedScannerPayload() {
        XCTAssertFalse(VeilPairCameraInputGate.accepts(prefix + String(repeating: "A", count: 4_096)))
        let exact = String(repeating: "A", count: VeilPairCameraInputGate.maximumUTF8Bytes - prefix.utf8.count)
        XCTAssertTrue(VeilPairCameraInputGate.accepts(prefix + exact))
    }
}
