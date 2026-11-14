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

    func testScreenshotCompressionIsUltraAggressiveWithoutCrushingLongScreenshots() {
        XCTAssertEqual(MediaTransferPolicy.screenshotShortEdge, 500)
        XCTAssertEqual(MediaTransferPolicy.screenshotLossyQuality, 0.18)
        XCTAssertEqual(MediaTransferPolicy.photoLongestEdge, 640)
        XCTAssertEqual(MediaTransferPolicy.photoLossyQuality, 0.28)

        let normalScreenshot = MediaTransferPolicy.compressedLongestEdge(
            originalWidth: 1_170, originalHeight: 2_532,
            isLikelyTextOrGraphic: true
        )
        XCTAssertEqual(normalScreenshot, 1_083)

        let longScreenshot = MediaTransferPolicy.compressedLongestEdge(
            originalWidth: 1_170, originalHeight: 6_000,
            isLikelyTextOrGraphic: true
        )
        XCTAssertEqual(longScreenshot, 2_565)
        XCTAssertLessThanOrEqual(longScreenshot, MediaTransferPolicy.maximumImageDimension)

        let oversized = MediaTransferPolicy.compressedLongestEdge(
            originalWidth: 1_170, originalHeight: 14_000,
            isLikelyTextOrGraphic: true
        )
        XCTAssertEqual(oversized, 4_096)

        let smallScreenshot = MediaTransferPolicy.compressedLongestEdge(
            originalWidth: 360, originalHeight: 780,
            isLikelyTextOrGraphic: true
        )
        XCTAssertEqual(smallScreenshot, 780) // never upscale

        let photo = MediaTransferPolicy.compressedLongestEdge(
            originalWidth: 4_032, originalHeight: 3_024,
            isLikelyTextOrGraphic: false
        )
        XCTAssertEqual(photo, 640)
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
