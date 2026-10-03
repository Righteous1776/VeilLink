import CryptoKit
import Foundation

struct VeilPasswordRecipe: Equatable, Sendable {
    var length: Int = 20
    var uppercase = true
    var digits = true
    var symbols = true
    var excludesAmbiguous = true
}

enum VeilLocalToolError: Error, Equatable, LocalizedError, Sendable {
    case invalidJSON
    case invalidBase64
    case invalidUTF8
    case invalidPercentEncoding
    case invalidISO8601
    case timestampOutOfRange
    case invalidHexColor
    case rgbOutOfRange
    case emptyRandomChoices
    case invalidDice

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "JSON 格式无效"
        case .invalidBase64:
            return "Base64 格式无效"
        case .invalidUTF8:
            return "内容不是有效的 UTF-8 文本"
        case .invalidPercentEncoding:
            return "URL 百分号编码无效"
        case .invalidISO8601:
            return "ISO 8601 时间格式无效"
        case .timestampOutOfRange:
            return "时间戳超出支持范围"
        case .invalidHexColor:
            return "HEX 颜色格式无效"
        case .rgbOutOfRange:
            return "RGB 分量必须位于 0...255"
        case .emptyRandomChoices:
            return "至少需要一个候选项"
        case .invalidDice:
            return "骰子需要 2...1000000 面，数量需要 1...100 个"
        }
    }
}

struct VeilJSONValidation: Equatable, Sendable {
    let isValid: Bool
    let errorSummary: String?
}

struct VeilTextCleaningOptions: Equatable, Sendable {
    var trimsLines = true
    var collapsesBlankLines = true
    var removesDuplicateLines = false
    var sortsLines = false
}

struct VeilRGBColor: Equatable, Sendable {
    let red: Int
    let green: Int
    let blue: Int
}

struct VeilDetailedTextMetrics: Equatable, Sendable {
    let characters: Int
    let utf8Bytes: Int
    let lines: Int
    let words: Int
    let nonWhitespaceScalars: Int
    let unicodeScalars: Int
    let asciiScalars: Int
    let asciiRatioPermille: Int
}

struct VeilJSONStructureMetrics: Equatable, Sendable {
    let objectCount: Int
    let arrayCount: Int
    let scalarCount: Int
    let keyCount: Int
    let maxDepth: Int

    var totalNodes: Int {
        objectCount + arrayCount + scalarCount
    }
}

struct VeilEncodingMetrics: Equatable, Sendable {
    let inputBytes: Int
    let outputBytes: Int
    let deltaBytes: Int
    let expansionPercent: Int
}

enum VeilPreferredForeground: String, Equatable, Sendable {
    case black
    case white
}

struct VeilColorContrastAnalysis: Equatable, Sendable {
    let relativeLuminance: Double
    let contrastWithBlack: Double
    let contrastWithWhite: Double
    let preferredForeground: VeilPreferredForeground
    let preferredContrast: Double
    let meetsAANormalText: Bool
    let meetsAALargeText: Bool
}

enum VeilLocalToolEngine {
    private static let lowercase = Array("abcdefghijkmnpqrstuvwxyz")
    private static let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let digits = Array("23456789")
    private static let symbols = Array("!@#$%^&*+-=_?")
    private static let ambiguous = Set("Il1O0o".map { $0 })
    private static let urlComponentAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    private static let morseAlphabet: [Character: String] = [
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".",
        "F": "..-.", "G": "--.", "H": "....", "I": "..", "J": ".---",
        "K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---",
        "P": ".--.", "Q": "--.-", "R": ".-.", "S": "...", "T": "-",
        "U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--",
        "Z": "--..", "0": "-----", "1": ".----", "2": "..---", "3": "...--",
        "4": "....-", "5": ".....", "6": "-....", "7": "--...", "8": "---..",
        "9": "----."
    ]
    private static let morseSymbols: [String: Character] = Dictionary(
        uniqueKeysWithValues: morseAlphabet.map { ($0.value, $0.key) }
    )

    private static func iso8601Formatter(fractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    static func password(recipe: VeilPasswordRecipe = VeilPasswordRecipe()) -> String {
        var generator = SystemRandomNumberGenerator()
        return password(recipe: recipe, using: &generator)
    }

    static func password<R: RandomNumberGenerator>(recipe: VeilPasswordRecipe, using generator: inout R) -> String {
        let lowerGroup = recipe.excludesAmbiguous ? lowercase : Array("abcdefghijklmnopqrstuvwxyz")
        let upperGroup = recipe.excludesAmbiguous ? uppercase : Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let digitGroup = recipe.excludesAmbiguous ? digits : Array("0123456789")
        var groups = [lowerGroup]
        if recipe.uppercase { groups.append(upperGroup) }
        if recipe.digits { groups.append(digitGroup) }
        if recipe.symbols { groups.append(symbols) }
        let pool = Array(Set(groups.flatMap { $0 })).sorted()
        let target = max(groups.count, min(128, recipe.length))
        var output = groups.map { $0.randomElement(using: &generator)! }
        while output.count < target {
            output.append(pool.randomElement(using: &generator)!)
        }
        if output.count > 1 {
            for index in stride(from: output.count - 1, through: 1, by: -1) {
                let swap = Int.random(in: 0...index, using: &generator)
                output.swapAt(index, swap)
            }
        }
        return String(output)
    }

    static func passwordEntropyBits(recipe: VeilPasswordRecipe) -> Int {
        var pool = lowercase
        if recipe.uppercase { pool += uppercase }
        if recipe.digits { pool += digits }
        if recipe.symbols { pool += symbols }
        if !recipe.excludesAmbiguous { pool += Array(ambiguous) }
        return Int((Double(max(1, recipe.length)) * log2(Double(Set(pool).count))).rounded())
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func textMetrics(_ text: String) -> (characters: Int, utf8Bytes: Int, lines: Int) {
        (text.count, text.utf8.count, text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    static func detailedTextMetrics(_ text: String) -> VeilDetailedTextMetrics {
        let basic = textMetrics(text)
        let whitespace = CharacterSet.whitespacesAndNewlines
        let scalarCount = text.unicodeScalars.count
        let nonWhitespace = text.unicodeScalars.reduce(into: 0) { count, scalar in
            if !whitespace.contains(scalar) {
                count += 1
            }
        }
        let ascii = text.unicodeScalars.reduce(into: 0) { count, scalar in
            if scalar.value < 128 {
                count += 1
            }
        }
        let words = text.split { character in
            character.unicodeScalars.allSatisfy { whitespace.contains($0) }
        }.count
        let ratio = scalarCount == 0
            ? 0
            : Int((Double(ascii) / Double(scalarCount) * 1_000).rounded())

        return VeilDetailedTextMetrics(
            characters: basic.characters,
            utf8Bytes: basic.utf8Bytes,
            lines: basic.lines,
            words: words,
            nonWhitespaceScalars: nonWhitespace,
            unicodeScalars: scalarCount,
            asciiScalars: ascii,
            asciiRatioPermille: ratio
        )
    }

    static func jsonStructureMetrics(_ text: String) throws -> VeilJSONStructureMetrics {
        let root = try jsonObject(text)
        var objectCount = 0
        var arrayCount = 0
        var scalarCount = 0
        var keyCount = 0
        var maxDepth = 0
        var stack: [(value: Any, depth: Int)] = [(root, 1)]

        while let item = stack.popLast() {
            maxDepth = max(maxDepth, item.depth)
            if let object = item.value as? [String: Any] {
                objectCount += 1
                keyCount += object.count
                stack.append(contentsOf: object.values.map { ($0, item.depth + 1) })
            } else if let array = item.value as? [Any] {
                arrayCount += 1
                stack.append(contentsOf: array.map { ($0, item.depth + 1) })
            } else {
                scalarCount += 1
            }
        }

        return VeilJSONStructureMetrics(
            objectCount: objectCount,
            arrayCount: arrayCount,
            scalarCount: scalarCount,
            keyCount: keyCount,
            maxDepth: maxDepth
        )
    }

    static func jsonValidation(_ text: String) -> VeilJSONValidation {
        do {
            _ = try jsonObject(text)
            return VeilJSONValidation(isValid: true, errorSummary: nil)
        } catch {
            return VeilJSONValidation(
                isValid: false,
                errorSummary: VeilLocalToolError.invalidJSON.errorDescription
            )
        }
    }

    static func prettyJSON(_ text: String) throws -> String {
        try serializeJSONObject(jsonObject(text), options: [.prettyPrinted, .sortedKeys])
    }

    static func minifiedJSON(_ text: String) throws -> String {
        try serializeJSONObject(jsonObject(text), options: [.sortedKeys])
    }

    static func base64EncodingMetrics(_ text: String) -> VeilEncodingMetrics {
        encodingMetrics(input: text, output: base64EncodeUTF8(text))
    }

    static func urlPercentEncodingMetrics(_ text: String) -> VeilEncodingMetrics {
        encodingMetrics(input: text, output: urlPercentEncode(text))
    }

    static func base64EncodeUTF8(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    static func base64DecodeUTF8(_ encoded: String) throws -> String {
        let compact = encoded.filter { !$0.isWhitespace }
        if compact.isEmpty { return "" }
        guard let data = Data(base64Encoded: compact) else {
            throw VeilLocalToolError.invalidBase64
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw VeilLocalToolError.invalidUTF8
        }
        return text
    }

    static func urlPercentEncode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: urlComponentAllowed) ?? ""
    }

    static func urlPercentDecode(_ encoded: String) throws -> String {
        guard let text = encoded.removingPercentEncoding else {
            throw VeilLocalToolError.invalidPercentEncoding
        }
        return text
    }

    static func iso8601(unixSeconds: Int64) throws -> String {
        try iso8601(timeInterval: TimeInterval(unixSeconds))
    }

    static func iso8601(unixMilliseconds: Int64) throws -> String {
        try iso8601(timeInterval: TimeInterval(unixMilliseconds) / 1_000)
    }

    static func unixSeconds(iso8601 text: String) throws -> Int64 {
        let interval = try date(iso8601: text).timeIntervalSince1970
        guard interval.isFinite,
              interval >= Double(Int64.min),
              interval <= Double(Int64.max) else {
            throw VeilLocalToolError.timestampOutOfRange
        }
        return Int64(floor(interval))
    }

    static func unixMilliseconds(iso8601 text: String) throws -> Int64 {
        let interval = try date(iso8601: text).timeIntervalSince1970 * 1_000
        guard interval.isFinite,
              interval >= Double(Int64.min),
              interval <= Double(Int64.max) else {
            throw VeilLocalToolError.timestampOutOfRange
        }
        return Int64(interval.rounded())
    }

    static func cleanText(
        _ text: String,
        options: VeilTextCleaningOptions = VeilTextCleaningOptions()
    ) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")

        if options.trimsLines {
            lines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if options.collapsesBlankLines {
            lines = lines.reduce(into: []) { result, line in
                guard !line.isEmpty || result.last?.isEmpty != true else { return }
                result.append(line)
            }
        }
        if options.removesDuplicateLines {
            var seen = Set<String>()
            lines = lines.filter { seen.insert($0).inserted }
        }
        if options.sortsLines {
            lines.sort()
        }
        return lines.joined(separator: "\n")
    }

    static func rgb(hex: String) throws -> VeilRGBColor {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6,
              value.allSatisfy({ $0.isHexDigit }),
              let red = Int(value.prefix(2), radix: 16),
              let green = Int(value.dropFirst(2).prefix(2), radix: 16),
              let blue = Int(value.suffix(2), radix: 16) else {
            throw VeilLocalToolError.invalidHexColor
        }
        return VeilRGBColor(red: red, green: green, blue: blue)
    }

    static func hex(rgb: VeilRGBColor) throws -> String {
        try hex(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    static func hex(red: Int, green: Int, blue: Int) throws -> String {
        guard (0...255).contains(red),
              (0...255).contains(green),
              (0...255).contains(blue) else {
            throw VeilLocalToolError.rgbOutOfRange
        }
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    static func colorContrast(rgb: VeilRGBColor) throws -> VeilColorContrastAnalysis {
        guard (0...255).contains(rgb.red),
              (0...255).contains(rgb.green),
              (0...255).contains(rgb.blue) else {
            throw VeilLocalToolError.rgbOutOfRange
        }

        let luminance = relativeLuminance(rgb)
        let contrastWithBlack = (luminance + 0.05) / 0.05
        let contrastWithWhite = 1.05 / (luminance + 0.05)
        let preferred: VeilPreferredForeground = contrastWithBlack >= contrastWithWhite ? .black : .white
        let preferredContrast = max(contrastWithBlack, contrastWithWhite)

        return VeilColorContrastAnalysis(
            relativeLuminance: luminance,
            contrastWithBlack: contrastWithBlack,
            contrastWithWhite: contrastWithWhite,
            preferredForeground: preferred,
            preferredContrast: preferredContrast,
            meetsAANormalText: preferredContrast >= 4.5,
            meetsAALargeText: preferredContrast >= 3.0
        )
    }

    static func randomChoice<Element>(from choices: [Element]) throws -> Element {
        var generator = SystemRandomNumberGenerator()
        return try randomChoice(from: choices, using: &generator)
    }

    static func randomChoice<Element, R: RandomNumberGenerator>(
        from choices: [Element],
        using generator: inout R
    ) throws -> Element {
        guard let choice = choices.randomElement(using: &generator) else {
            throw VeilLocalToolError.emptyRandomChoices
        }
        return choice
    }

    static func rollDice(sides: Int = 6, count: Int = 1) throws -> [Int] {
        var generator = SystemRandomNumberGenerator()
        return try rollDice(sides: sides, count: count, using: &generator)
    }

    static func rollDice<R: RandomNumberGenerator>(
        sides: Int = 6,
        count: Int = 1,
        using generator: inout R
    ) throws -> [Int] {
        guard (2...1_000_000).contains(sides), (1...100).contains(count) else {
            throw VeilLocalToolError.invalidDice
        }
        return (0..<count).map { _ in Int.random(in: 1...sides, using: &generator) }
    }

    /// Encodes A-Z and 0-9. Whitespace runs become `/`; unsupported characters become `?`.
    static func morseEncode(_ text: String) -> String {
        text.uppercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map { word in
                word.map { morseAlphabet[$0] ?? "?" }.joined(separator: " ")
            }
            .joined(separator: " / ")
    }

    /// Decodes space-delimited Morse with `/` between words; unknown symbols become `?`.
    static func morseDecode(_ morse: String) -> String {
        var output = ""
        let normalized = morse.replacingOccurrences(of: "/", with: " / ")
        for token in normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            if token == "/" {
                if !output.isEmpty, output.last != " " { output.append(" ") }
            } else {
                output.append(morseSymbols[token] ?? "?")
            }
        }
        return output
    }

    private static func encodingMetrics(input: String, output: String) -> VeilEncodingMetrics {
        let inputBytes = input.utf8.count
        let outputBytes = output.utf8.count
        let delta = outputBytes - inputBytes
        let expansionPercent = inputBytes == 0
            ? 0
            : Int((Double(delta) / Double(inputBytes) * 100).rounded())
        return VeilEncodingMetrics(
            inputBytes: inputBytes,
            outputBytes: outputBytes,
            deltaBytes: delta,
            expansionPercent: expansionPercent
        )
    }

    private static func relativeLuminance(_ rgb: VeilRGBColor) -> Double {
        let red = linearizedSRGB(Double(rgb.red) / 255.0)
        let green = linearizedSRGB(Double(rgb.green) / 255.0)
        let blue = linearizedSRGB(Double(rgb.blue) / 255.0)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private static func linearizedSRGB(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func jsonObject(_ text: String) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        } catch {
            throw VeilLocalToolError.invalidJSON
        }
    }

    private static func serializeJSONObject(_ object: Any, options: JSONSerialization.WritingOptions) throws -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: options.union(.fragmentsAllowed))
            guard let output = String(data: data, encoding: .utf8) else {
                throw VeilLocalToolError.invalidUTF8
            }
            return output
        } catch let error as VeilLocalToolError {
            throw error
        } catch {
            throw VeilLocalToolError.invalidJSON
        }
    }

    private static func iso8601(timeInterval: TimeInterval) throws -> String {
        guard timeInterval.isFinite else {
            throw VeilLocalToolError.timestampOutOfRange
        }
        let output = iso8601Formatter(fractionalSeconds: true)
            .string(from: Date(timeIntervalSince1970: timeInterval))
        guard !output.isEmpty else {
            throw VeilLocalToolError.timestampOutOfRange
        }
        return output
    }

    private static func date(iso8601 text: String) throws -> Date {
        if let date = iso8601Formatter(fractionalSeconds: true).date(from: text)
            ?? iso8601Formatter(fractionalSeconds: false).date(from: text) {
            return date
        }
        throw VeilLocalToolError.invalidISO8601
    }
}
