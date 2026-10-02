import CryptoKit
import Foundation

struct VeilPasswordRecipe: Equatable, Sendable {
    var length: Int = 20
    var uppercase = true
    var digits = true
    var symbols = true
    var excludesAmbiguous = true
}

enum VeilLocalToolEngine {
    private static let lowercase = Array("abcdefghijkmnpqrstuvwxyz")
    private static let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let digits = Array("23456789")
    private static let symbols = Array("!@#$%^&*+-=_?")
    private static let ambiguous = Set("Il1O0o".map { $0 })

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
}
