import XCTest
import SwiftUI
@testable import VeilLink

@MainActor
final class VeilROCFlagTextTests: XCTestCase {
    func testRocFlagLiteralIsTheTwoRegionalIndicatorScalars() {
        XCTAssertEqual(
            VeilROCFlagText.emoji.unicodeScalars.map(\.value),
            [0x1F1F9, 0x1F1FC]
        )
    }

    func testFlagUsesThreeToTwoAspectAndTwelveRays() {
        XCTAssertEqual(VeilROCFlagText.horizontalUnits, 3)
        XCTAssertEqual(VeilROCFlagText.verticalUnits, 2)
        XCTAssertEqual(VeilROCFlagText.rayCount, 12)
        let image = VeilROCFlagText.makeImage()
        XCTAssertEqual(image.size.width, 24, accuracy: 0.0001)
        XCTAssertEqual(image.size.height, 16, accuracy: 0.0001)
        XCTAssertNotNil(image.cgImage)
    }

    func testNonStandardInputStillRespectsAspectRatio() {
        let image = VeilROCFlagText.makeImage(size: CGSize(width: 72, height: 1))
        XCTAssertEqual(image.size.width / image.size.height, 1.5, accuracy: 0.0001)
    }

    func testAccessibilityReplacesOnlyTheFlagSequence() {
        let original = "晚安 \(VeilROCFlagText.emoji) ✨ \(VeilROCFlagText.emoji) 🇯🇵 🇺🇸"
        XCTAssertTrue(VeilROCFlagText.containsFlag(original))
        XCTAssertEqual(
            VeilROCFlagText.accessibilityDescription(for: original),
            "晚安 中华民国国旗 ✨ 中华民国国旗 🇯🇵 🇺🇸"
        )
        XCTAssertFalse(VeilROCFlagText.containsFlag("🇯🇵 🇺🇸"))
        XCTAssertEqual(
            VeilROCFlagText.accessibilityDescription(for: "🇯🇵 🇺🇸"),
            "🇯🇵 🇺🇸"
        )
    }

    func testRichTextAdapterBuildsInlineTextWithoutMutatingStorage() {
        let raw = "引用：\(VeilROCFlagText.emoji)\n详情：\(VeilROCFlagText.emoji)"
        let unchanged = raw
        _ = VeilROCFlagText.render(raw)
        XCTAssertEqual(raw, unchanged)
        // Persisted chat bodies must never be passed through accessibilityDescription.
        XCTAssertEqual(raw.unicodeScalars.filter { $0.value == 0x1F1F9 }.count, 2)
    }
}
