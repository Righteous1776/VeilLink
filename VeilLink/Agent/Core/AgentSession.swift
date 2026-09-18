import Foundation

struct AgentSession: Identifiable, Equatable, Sendable {
    let id: String
    let createdAt: Date
    private(set) var messages: [AgentMessage]

    init(id: String = UUID().uuidString, createdAt: Date = Date(), messages: [AgentMessage] = []) {
        self.id = id
        self.createdAt = createdAt
        self.messages = messages
    }

    mutating func append(_ message: AgentMessage, limit: Int) {
        messages.append(message)
        trim(to: limit)
    }

    mutating func updateMessage(id: String, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
    }

    mutating func removeMessage(id: String) {
        messages.removeAll { $0.id == id }
    }

    mutating func trim(to limit: Int) {
        guard limit > 0, messages.count > limit else { return }
        messages.removeFirst(messages.count - limit)
    }

    func recentMessages(limit: Int) -> [AgentMessage] {
        guard limit > 0 else { return [] }
        return Array(messages.suffix(limit))
    }
}
