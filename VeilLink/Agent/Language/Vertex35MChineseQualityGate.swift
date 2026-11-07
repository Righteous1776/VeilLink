import Foundation

/// Only checks output language quality; it is not a translator or action controller.
enum Vertex35MChineseQualityGate {
    static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3400...0x9FFF).contains(Int($0.value)) }
    }

    static func needsLanguageWarning(userText: String, modelOutput: String) -> Bool {
        containsHan(userText) && !containsHan(modelOutput)
    }
}
