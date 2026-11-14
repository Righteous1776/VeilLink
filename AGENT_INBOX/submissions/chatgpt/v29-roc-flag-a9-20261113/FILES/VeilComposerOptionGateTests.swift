import XCTest
@testable import VeilLink

final class VeilComposerOptionGateTests: XCTestCase {
    func testDefaultInputsFailClosed() {
        XCTAssertFalse(VeilComposerOptionGate.accepts(""))
        XCTAssertFalse(VeilComposerOptionGate.accepts("00000000"))
        XCTAssertFalse(VeilComposerOptionGate.accepts("12345678"))
        XCTAssertFalse(VeilComposerOptionGate.accepts("１２３４５６７８"))
        XCTAssertFalse(VeilComposerOptionGate.accepts("abcdefgh"))
        XCTAssertFalse(VeilComposerOptionGate.accepts("0000 0000"))
    }

    func testAccessTokenValidationUsesOnlyASCIIEightDigits() {
        for s in ["1", "012345678", "000000000", "12\n345678", "🎲1234567"] {
            XCTAssertFalse(VeilComposerOptionGate.accepts(s))
        }
    }
}
