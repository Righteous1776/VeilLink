import XCTest
@testable import VeilLink

final class MediaTransferPolicyTests: XCTestCase {
    func testSoftBLESizeIsNotAProhibition() {
        XCTAssertEqual(MediaTransferPolicy.bleTargetBytes, 200_000)
        XCTAssertEqual(MediaTransferPolicy.blePreferredBytes, 384_000)
        XCTAssertEqual(MediaTransferPolicy.preferredBytes(for: .bluetooth), 384_000)
        XCTAssertTrue(MediaTransferPolicy.mayTransmit(byteCount: 500_000))
        XCTAssertTrue(MediaTransferPolicy.mayTransmit(byteCount: 2_900_000))
        XCTAssertFalse(MediaTransferPolicy.mayTransmit(byteCount: 3_000_001))
        XCTAssertFalse(MediaTransferPolicy.mayTransmit(byteCount: 0))
    }

    func testFallbackFavorsMeaningfulSavingsOnly() {
        XCTAssertTrue(MediaTransferPolicy.preferCandidate(bytes: 600_000, over: nil))
        XCTAssertTrue(MediaTransferPolicy.preferCandidate(bytes: 700_000, over: 1_000_000))
        XCTAssertFalse(MediaTransferPolicy.preferCandidate(bytes: 900_000, over: 1_000_000))
        XCTAssertFalse(MediaTransferPolicy.preferCandidate(bytes: 3_100_000, over: nil))
    }

    func testCompressionQualityHasPreservationFloor() {
        let range = MediaTransferPolicy.qualityRange(for: .bluetooth)
        XCTAssertEqual(range.floor, 0.78)
        XCTAssertNil(MediaTransferPolicy.nextQuality(
            after: 0.90, encodedBytes: 320_000, preferredBytes: 384_000,
            minimum: range.floor
        ))
        let q = MediaTransferPolicy.nextQuality(
            after: 0.90, encodedBytes: 900_000, preferredBytes: 384_000,
            minimum: range.floor
        )
        XCTAssertNotNil(q)
        XCTAssertGreaterThanOrEqual(q ?? 0, range.floor)
        XCTAssertLessThan(q ?? 1, 0.90)
    }

    func testExtremeCompressionReadabilityBounds() {
        XCTAssertEqual(MediaTransferPolicy.extremeMinimumLongestEdge(
            isLikelyTextOrGraphic: false
        ), 640)
        XCTAssertEqual(MediaTransferPolicy.extremeMinimumLongestEdge(
            isLikelyTextOrGraphic: true
        ), 1_280)
        XCTAssertEqual(MediaTransferPolicy.extremeQuality(
            isLikelyTextOrGraphic: false
        ), 0.28)
        XCTAssertEqual(MediaTransferPolicy.extremeQuality(
            isLikelyTextOrGraphic: true
        ), 0.50)
        XCTAssertLessThan(
            MediaTransferPolicy.extremeQuality(isLikelyTextOrGraphic: false),
            MediaTransferPolicy.qualityRange(for: .bluetooth).floor
        )
    }

    func testGenericFilePolicyIsBoundedAndRejectsPathTraversal() {
        XCTAssertEqual(MediaTransferPolicy.maximumGenericFileBytes, 2_000_000)
        XCTAssertEqual(MediaTransferPolicy.genericFileCapabilityBit, 8)
        XCTAssertEqual(MediaTransferPolicy.genericFileMIMEType(for: "note.txt"), "text/plain")
        XCTAssertEqual(MediaTransferPolicy.genericFileMIMEType(for: "scan.pdf"), "application/pdf")
        XCTAssertEqual(MediaTransferPolicy.genericFileMIMEType(for: "backup.zip"), "application/zip")
        XCTAssertEqual(MediaTransferPolicy.genericFileMIMEType(for: "data.random"), "application/octet-stream")
        XCTAssertEqual(MediaTransferPolicy.safeGenericFilename("note.txt"), "note.txt")
        XCTAssertNil(MediaTransferPolicy.safeGenericFilename("../secrets.json"))
        XCTAssertNil(MediaTransferPolicy.safeGenericFilename("nested/note.txt"))
        XCTAssertNil(MediaTransferPolicy.safeGenericFilename("nested\\note.txt"))
        XCTAssertNil(MediaTransferPolicy.safeGenericFilename("bad\u{0000}file"))
    }

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
