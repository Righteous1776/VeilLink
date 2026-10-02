import XCTest
@testable import VeilLink

final class VeilLocalToolEngineTests: XCTestCase {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    func testPasswordGeneratorIsReproducibleAndHonorsRecipe() {
        let recipe = VeilPasswordRecipe(length: 32, uppercase: true, digits: true, symbols: true, excludesAmbiguous: true)
        var firstGenerator = SeededGenerator(state: 1776)
        var secondGenerator = SeededGenerator(state: 1776)
        let first = VeilLocalToolEngine.password(recipe: recipe, using: &firstGenerator)
        let second = VeilLocalToolEngine.password(recipe: recipe, using: &secondGenerator)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 32)
        XCTAssertTrue(first.contains(where: { $0.isLowercase }))
        XCTAssertTrue(first.contains(where: { $0.isUppercase }))
        XCTAssertTrue(first.contains(where: { $0.isNumber }))
        XCTAssertTrue(first.contains(where: { "!@#$%^&*+-=_?".contains($0) }))
        XCTAssertFalse(first.contains(where: { "Il1O0o".contains($0) }))
        XCTAssertGreaterThan(VeilLocalToolEngine.passwordEntropyBits(recipe: recipe), 150)
    }

    func testSHA256AndTextMetricsUseUTF8() {
        XCTAssertEqual(
            VeilLocalToolEngine.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        let metrics = VeilLocalToolEngine.textMetrics("Veil\n链路")
        XCTAssertEqual(metrics.characters, 7)
        XCTAssertEqual(metrics.utf8Bytes, 11)
        XCTAssertEqual(metrics.lines, 2)
        XCTAssertEqual(VeilLocalToolEngine.textMetrics("").lines, 0)
    }
}
