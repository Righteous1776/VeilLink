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

    func testJSONValidationPrettyAndMinifyAreDeterministic() throws {
        let source = #"{"z":[true,null],"a":{"name":"链路"}}"#
        let pretty = try VeilLocalToolEngine.prettyJSON(source)
        let minified = try VeilLocalToolEngine.minifiedJSON(pretty)

        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertEqual(minified, #"{"a":{"name":"链路"},"z":[true,null]}"#)
        XCTAssertEqual(
            VeilLocalToolEngine.jsonValidation(source),
            VeilJSONValidation(isValid: true, errorSummary: nil)
        )
        XCTAssertEqual(
            VeilLocalToolEngine.jsonValidation("{oops"),
            VeilJSONValidation(isValid: false, errorSummary: "JSON 格式无效")
        )
        XCTAssertThrowsError(try VeilLocalToolEngine.prettyJSON("{oops")) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidJSON)
        }
    }

    func testJSONSupportsTopLevelFragments() throws {
        XCTAssertEqual(try VeilLocalToolEngine.minifiedJSON(#""VeilLink""#), #""VeilLink""#)
        XCTAssertEqual(try VeilLocalToolEngine.minifiedJSON("1776"), "1776")
    }

    func testBase64UTF8RoundTripAndStableErrors() throws {
        let source = "VeilLink 链路\n🚀"
        let encoded = VeilLocalToolEngine.base64EncodeUTF8(source)
        XCTAssertEqual(try VeilLocalToolEngine.base64DecodeUTF8(encoded), source)
        XCTAssertEqual(try VeilLocalToolEngine.base64DecodeUTF8("  \(encoded)\n"), source)
        XCTAssertEqual(try VeilLocalToolEngine.base64DecodeUTF8(""), "")
        XCTAssertEqual(try VeilLocalToolEngine.base64DecodeUTF8(" \n\t "), "")

        XCTAssertThrowsError(try VeilLocalToolEngine.base64DecodeUTF8("%%%")) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidBase64)
        }
        XCTAssertThrowsError(try VeilLocalToolEngine.base64DecodeUTF8("/w==")) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidUTF8)
        }
    }

    func testURLPercentEncodingUsesRFC3986UnreservedSet() throws {
        let source = "https://veil.link/链路?q=a+b&safe=~-._"
        let encoded = VeilLocalToolEngine.urlPercentEncode(source)

        XCTAssertEqual(encoded, "https%3A%2F%2Fveil.link%2F%E9%93%BE%E8%B7%AF%3Fq%3Da%2Bb%26safe%3D~-._")
        XCTAssertEqual(try VeilLocalToolEngine.urlPercentDecode(encoded), source)
        XCTAssertThrowsError(try VeilLocalToolEngine.urlPercentDecode("broken%2")) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidPercentEncoding)
        }
    }

    func testUnixSecondsAndMillisecondsISO8601Conversions() throws {
        XCTAssertEqual(try VeilLocalToolEngine.iso8601(unixSeconds: 0), "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(try VeilLocalToolEngine.iso8601(unixMilliseconds: 1_700_000_000_123), "2023-11-14T22:13:20.123Z")
        XCTAssertEqual(try VeilLocalToolEngine.unixSeconds(iso8601: "2023-11-14T22:13:20Z"), 1_700_000_000)
        XCTAssertEqual(try VeilLocalToolEngine.unixMilliseconds(iso8601: "2023-11-14T22:13:20.123Z"), 1_700_000_000_123)
        XCTAssertEqual(try VeilLocalToolEngine.unixSeconds(iso8601: "1969-12-31T23:59:59.500Z"), -1)
        XCTAssertThrowsError(try VeilLocalToolEngine.unixSeconds(iso8601: "not-a-date")) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidISO8601)
        }
    }

    func testTextCleaningNormalizesAndAppliesOptionsDeterministically() {
        let source = "  beta  \r\n\r\n\talpha\t\r\n\r\n\r\nbeta  "
        XCTAssertEqual(VeilLocalToolEngine.cleanText(source), "beta\n\nalpha\n\nbeta")

        let options = VeilTextCleaningOptions(
            trimsLines: true,
            collapsesBlankLines: true,
            removesDuplicateLines: true,
            sortsLines: true
        )
        XCTAssertEqual(VeilLocalToolEngine.cleanText(source, options: options), "\nalpha\nbeta")
        XCTAssertEqual(
            VeilLocalToolEngine.cleanText(" b \n a ", options: VeilTextCleaningOptions(trimsLines: false)),
            " b \n a "
        )
    }

    func testHEXAndRGBConversion() throws {
        XCTAssertEqual(try VeilLocalToolEngine.rgb(hex: "#1a2B3c"), VeilRGBColor(red: 26, green: 43, blue: 60))
        XCTAssertEqual(try VeilLocalToolEngine.rgb(hex: " F0A "), VeilRGBColor(red: 255, green: 0, blue: 170))
        XCTAssertEqual(try VeilLocalToolEngine.hex(red: 0, green: 127, blue: 255), "#007FFF")
        XCTAssertEqual(try VeilLocalToolEngine.hex(rgb: VeilRGBColor(red: 17, green: 34, blue: 51)), "#112233")

        XCTAssertThrowsError(try VeilLocalToolEngine.rgb(hex: "#12GG00")) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidHexColor)
        }
        XCTAssertThrowsError(try VeilLocalToolEngine.hex(red: -1, green: 0, blue: 0)) {
            XCTAssertEqual($0 as? VeilLocalToolError, .rgbOutOfRange)
        }
    }

    func testRandomChoiceAndDiceHaveDeterministicInjectedRNG() throws {
        var choiceGeneratorA = SeededGenerator(state: 1776)
        var choiceGeneratorB = SeededGenerator(state: 1776)
        let choices = ["LAN", "BLE", "QR"]
        XCTAssertEqual(
            try VeilLocalToolEngine.randomChoice(from: choices, using: &choiceGeneratorA),
            try VeilLocalToolEngine.randomChoice(from: choices, using: &choiceGeneratorB)
        )

        var diceGeneratorA = SeededGenerator(state: 2026)
        var diceGeneratorB = SeededGenerator(state: 2026)
        let first = try VeilLocalToolEngine.rollDice(sides: 20, count: 8, using: &diceGeneratorA)
        let second = try VeilLocalToolEngine.rollDice(sides: 20, count: 8, using: &diceGeneratorB)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 8)
        XCTAssertTrue(first.allSatisfy((1...20).contains))

        XCTAssertThrowsError(try VeilLocalToolEngine.randomChoice(from: [String]())) {
            XCTAssertEqual($0 as? VeilLocalToolError, .emptyRandomChoices)
        }
        XCTAssertThrowsError(try VeilLocalToolEngine.rollDice(sides: 1, count: 1)) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidDice)
        }
    }

    func testMorseLatinDigitsAndUnsupportedStrategy() {
        let encoded = VeilLocalToolEngine.morseEncode("SOS 2! 链")
        XCTAssertEqual(encoded, "... --- ... / ..--- ? / ?")
        XCTAssertEqual(VeilLocalToolEngine.morseDecode(encoded), "SOS 2? ?")
        XCTAssertEqual(VeilLocalToolEngine.morseEncode("  A\t\nB  "), ".- / -...")
        XCTAssertEqual(VeilLocalToolEngine.morseDecode(".- / --..-- / -..."), "A ? B")
        XCTAssertEqual(VeilLocalToolEngine.morseDecode(".../---/..."), "S O S")
    }

    func testDetailedTextMetricsExposeWordsAndASCIIRatio() {
        let metrics = VeilLocalToolEngine.detailedTextMetrics("Veil Link\n链路 42")
        XCTAssertEqual(metrics.characters, 15)
        XCTAssertEqual(metrics.utf8Bytes, 19)
        XCTAssertEqual(metrics.lines, 2)
        XCTAssertEqual(metrics.words, 4)
        XCTAssertEqual(metrics.nonWhitespaceScalars, 12)
        XCTAssertEqual(metrics.unicodeScalars, 15)
        XCTAssertEqual(metrics.asciiScalars, 13)
        XCTAssertEqual(metrics.asciiRatioPermille, 867)
    }

    func testJSONStructureMetricsCountNestedContainersAndDepth() throws {
        let metrics = try VeilLocalToolEngine.jsonStructureMetrics(
            #"{"a":[1,{"b":true}],"c":null}"#
        )
        XCTAssertEqual(metrics.objectCount, 2)
        XCTAssertEqual(metrics.arrayCount, 1)
        XCTAssertEqual(metrics.scalarCount, 3)
        XCTAssertEqual(metrics.keyCount, 3)
        XCTAssertEqual(metrics.maxDepth, 4)
        XCTAssertEqual(metrics.totalNodes, 6)
        XCTAssertThrowsError(try VeilLocalToolEngine.jsonStructureMetrics("{broken")) {
            XCTAssertEqual($0 as? VeilLocalToolError, .invalidJSON)
        }
    }

    func testEncodingMetricsReportDeterministicExpansion() {
        XCTAssertEqual(
            VeilLocalToolEngine.base64EncodingMetrics("abc"),
            VeilEncodingMetrics(inputBytes: 3, outputBytes: 4, deltaBytes: 1, expansionPercent: 33)
        )
        XCTAssertEqual(
            VeilLocalToolEngine.urlPercentEncodingMetrics("a b"),
            VeilEncodingMetrics(inputBytes: 3, outputBytes: 5, deltaBytes: 2, expansionPercent: 67)
        )
        XCTAssertEqual(
            VeilLocalToolEngine.base64EncodingMetrics(""),
            VeilEncodingMetrics(inputBytes: 0, outputBytes: 0, deltaBytes: 0, expansionPercent: 0)
        )
    }

    func testColorContrastChoosesReadableForeground() throws {
        let black = try VeilLocalToolEngine.colorContrast(
            rgb: VeilRGBColor(red: 0, green: 0, blue: 0)
        )
        XCTAssertEqual(black.relativeLuminance, 0, accuracy: 0.000_001)
        XCTAssertEqual(black.contrastWithWhite, 21, accuracy: 0.001)
        XCTAssertEqual(black.preferredForeground, .white)
        XCTAssertTrue(black.meetsAANormalText)
        XCTAssertTrue(black.meetsAALargeText)

        let white = try VeilLocalToolEngine.colorContrast(
            rgb: VeilRGBColor(red: 255, green: 255, blue: 255)
        )
        XCTAssertEqual(white.relativeLuminance, 1, accuracy: 0.000_001)
        XCTAssertEqual(white.contrastWithBlack, 21, accuracy: 0.001)
        XCTAssertEqual(white.preferredForeground, .black)

        XCTAssertThrowsError(
            try VeilLocalToolEngine.colorContrast(
                rgb: VeilRGBColor(red: 256, green: 0, blue: 0)
            )
        ) {
            XCTAssertEqual($0 as? VeilLocalToolError, .rgbOutOfRange)
        }
    }
}
