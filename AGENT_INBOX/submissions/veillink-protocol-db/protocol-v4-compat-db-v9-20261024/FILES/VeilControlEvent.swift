import Foundation

/// A typed extension transported only inside an authenticated Wire v4 session.
struct VeilControlEvent: Codable, Equatable {
    let schemaVersion: Int
    let eventID: String
    let topic: String
    let payload: Data
    let createdAt: TimeInterval

    init(eventID: String = UUID().uuidString, topic: String, payload: Data, createdAt: TimeInterval = Date().timeIntervalSince1970) {
        schemaVersion = 1
        self.eventID = eventID
        self.topic = topic
        self.payload = payload
        self.createdAt = createdAt
    }
}

enum VeilControlEventCodec {
    enum Error: Swift.Error { case invalidEvent }
    static let maxPayloadBytes = 24_576
    static let maxEncodedBytes = 49_152

    static func encode(_ event: VeilControlEvent) throws -> Data {
        try validate(event)
        let data = try JSONEncoder().encode(event)
        guard data.count <= maxEncodedBytes else { throw Error.invalidEvent }
        return data
    }

    static func decode(_ bytes: Data) throws -> VeilControlEvent {
        guard !bytes.isEmpty, bytes.count <= maxEncodedBytes else { throw Error.invalidEvent }
        let value = try JSONDecoder().decode(VeilControlEvent.self, from: bytes)
        try validate(value)
        return value
    }

    private static func validate(_ event: VeilControlEvent) throws {
        guard event.schemaVersion == 1, let uuid = UUID(uuidString: event.eventID),
              uuid.uuidString == event.eventID,
              event.createdAt.isFinite, event.createdAt > 0,
              event.payload.count <= maxPayloadBytes else { throw Error.invalidEvent }
        let name = Array(event.topic.utf8)
        guard !name.isEmpty, name.count <= 64,
              name.allSatisfy({ ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 46 || $0 == 45 || $0 == 95 }) else {
            throw Error.invalidEvent
        }
    }
}
