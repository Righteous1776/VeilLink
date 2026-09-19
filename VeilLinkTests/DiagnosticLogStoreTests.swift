import XCTest
@testable import VeilLink

@MainActor
final class DiagnosticLogStoreTests: XCTestCase {
    func testRedactsSensitiveMetadataButKeepsTechnicalIdentifiers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        store.log(
            .info,
            .ui,
            event: "ui.action",
            screen: "settings",
            metadata: [
                "device_id": "DEVICE-1234",
                "transport_id": "AABBCCDD-0000-1111-2222-333344445555",
                "password": "never-store-this",
                "typed_text": "private message"
            ]
        )

        let entry = try XCTUnwrap(store.recentEntries.last)
        XCTAssertEqual(entry.metadata["device_id"], "DEVICE-1234")
        XCTAssertEqual(entry.metadata["transport_id"], "AABBCCDD-0000-1111-2222-333344445555")
        XCTAssertEqual(entry.metadata["password"], "<redacted>")
        XCTAssertEqual(entry.metadata["typed_text"], "<redacted>")
    }

    func testInputEventStoresLengthNotText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        store.log(
            .debug,
            .input,
            event: "input.field.change",
            metadata: ["length": "12", "secure": "true"]
        )
        let entry = try XCTUnwrap(store.recentEntries.last)
        XCTAssertEqual(entry.metadata["length"], "12")
        XCTAssertEqual(entry.metadata["secure"], "true")
    }

    func testSequenceMonotonicallyIncreases() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        store.log(.debug, .app, event: "one")
        store.log(.debug, .app, event: "two")
        XCTAssertEqual(store.recentEntries.count, 2)
        XCTAssertLessThan(store.recentEntries[0].sequence, store.recentEntries[1].sequence)
    }
}
