import XCTest
import SwiftUI
@testable import VeilLink

@MainActor
final class VeilInlineGlyphTextTests: XCTestCase {
    func testRocFlagLiteralIsTheTwoRegionalIndicatorScalars() {
        XCTAssertEqual(
            VeilInlineGlyphText.emoji.unicodeScalars.map(\.value),
            [0x1F1F9, 0x1F1FC]
        )
    }

    func testFlagUsesThreeToTwoAspectAndTwelveRays() {
        XCTAssertEqual(VeilInlineGlyphText.horizontalUnits, 3)
        XCTAssertEqual(VeilInlineGlyphText.verticalUnits, 2)
        XCTAssertEqual(VeilInlineGlyphText.rayCount, 12)
        let image = VeilInlineGlyphText.makeImage()
        XCTAssertEqual(image.size.width, 24, accuracy: 0.0001)
        XCTAssertEqual(image.size.height, 16, accuracy: 0.0001)
        XCTAssertNotNil(image.cgImage)
    }

    func testNonStandardInputStillRespectsAspectRatio() {
        let image = VeilInlineGlyphText.makeImage(size: CGSize(width: 72, height: 1))
        XCTAssertEqual(image.size.width / image.size.height, 1.5, accuracy: 0.0001)
    }

    func testAccessibilityReplacesOnlyTheFlagSequence() {
        let original = "晚安 \(VeilInlineGlyphText.emoji) ✨ \(VeilInlineGlyphText.emoji) 🇯🇵 🇺🇸"
        XCTAssertTrue(VeilInlineGlyphText.containsFlag(original))
        XCTAssertEqual(
            VeilInlineGlyphText.accessibilityDescription(for: original),
            "晚安 中华民国国旗 ✨ 中华民国国旗 🇯🇵 🇺🇸"
        )
        XCTAssertFalse(VeilInlineGlyphText.containsFlag("🇯🇵 🇺🇸"))
        XCTAssertEqual(
            VeilInlineGlyphText.accessibilityDescription(for: "🇯🇵 🇺🇸"),
            "🇯🇵 🇺🇸"
        )
    }

    func testRichTextAdapterBuildsInlineTextWithoutMutatingStorage() {
        let raw = "引用：\(VeilInlineGlyphText.emoji)\n详情：\(VeilInlineGlyphText.emoji)"
        let unchanged = raw
        _ = VeilInlineGlyphText.render(raw)
        XCTAssertEqual(raw, unchanged)
        // Persisted chat bodies must never be passed through accessibilityDescription.
        XCTAssertEqual(raw.unicodeScalars.filter { $0.value == 0x1F1F9 }.count, 2)
    }
}
