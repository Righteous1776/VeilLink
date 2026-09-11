import XCTest
@testable import VeilLink

final class MediaTransferPolicyTests: XCTestCase {
    func testTransferLayerAcceptsSafeOutputFormats() {
        XCTAssertTrue(MediaTransferPolicy.supportsImageMIMEType("image/jpeg"))
        XCTAssertTrue(MediaTransferPolicy.supportsImageMIMEType("image/heic"))
        XCTAssertTrue(MediaTransferPolicy.supportsImageMIMEType("image/png"))
        XCTAssertFalse(MediaTransferPolicy.supportsImageMIMEType("image/webp"))
        XCTAssertFalse(MediaTransferPolicy.supportsImageMIMEType("image/x-adobe-dng"))
    }

    func testImageBudgetKeepsQualityTargetBelowHardProtocolLimit() {
        XCTAssertGreaterThan(MediaTransferPolicy.targetImageBytes, 1_000_000)
        XCTAssertLessThan(MediaTransferPolicy.targetImageBytes, MediaTransferPolicy.maximumImageBytes)
        XCTAssertEqual(MediaTransferPolicy.maximumImageBytes, 3_000_000)
        XCTAssertEqual(MediaTransferPolicy.maximumImageDimension, 4_096)
    }
}
