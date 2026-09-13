import XCTest
@testable import VeilLink

final class BLEConnectionIntentStoreTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "VeilLinkTests.BLEIntent.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    func testIntentStoreRoundTripsUniquePeripheralIdentifiers() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BLEConnectionIntentStore(defaults: defaults, key: "intent")
        let first = UUID()
        let second = UUID()

        store.save([first, second, first])

        XCTAssertEqual(store.load(), Set([first, second]))
        XCTAssertEqual(defaults.stringArray(forKey: "intent")?.count, 2)
    }

    func testIntentStoreIgnoresMalformedValuesAndCanClear() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BLEConnectionIntentStore(defaults: defaults, key: "intent")
        let valid = UUID()
        defaults.set([valid.uuidString, "not-a-uuid"], forKey: "intent")

        XCTAssertEqual(store.load(), Set([valid]))
        store.clear()
        XCTAssertTrue(store.load().isEmpty)
    }
}
