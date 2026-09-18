import Foundation

enum AgentTokenStream {
    static func chunks(text: String, targetCharacters: Int = 4) -> [String] {
        guard !text.isEmpty else { return [] }
        let width = max(1, targetCharacters)
        var chunks: [String] = []
        chunks.reserveCapacity(max(1, text.count / width))
        var current = ""
        current.reserveCapacity(width)
        for character in text {
            current.append(character)
            if current.count >= width || character == "。" || character == "，" || character == "\n" {
                chunks.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
