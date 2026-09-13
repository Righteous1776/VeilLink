import Foundation

struct BLEConnectionIntentStore {
    static let defaultKey = "transport.wantedConnections.v1"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = Self.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> Set<UUID> {
        let stored = defaults.stringArray(forKey: key) ?? []
        return Set(stored.compactMap(UUID.init(uuidString:)))
    }

    func save(_ identifiers: Set<UUID>) {
        defaults.set(identifiers.map(\.uuidString).sorted(), forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
