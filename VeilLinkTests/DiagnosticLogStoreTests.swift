import XCTest
@testable import VeilLink

@MainActor
final class DiagnosticLogStoreTests: XCTestCase {
    func testRedactsSensitiveMetadataButKeepsTechnicalIdentifiers() async throws {
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
        await waitForEntries(1, in: store)

        let entry = try XCTUnwrap(store.recentEntries.last)
        XCTAssertEqual(entry.metadata["device_id"], "DEVICE-1234")
        XCTAssertEqual(entry.metadata["transport_id"], "AABBCCDD-0000-1111-2222-333344445555")
        XCTAssertEqual(entry.metadata["password"], "<redacted>")
        XCTAssertEqual(entry.metadata["typed_text"], "<redacted>")
    }

    func testInputEventStoresLengthNotText() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        store.log(
            .debug,
            .input,
            event: "input.field.change",
            metadata: ["length": "12", "secure": "true"]
        )
        await waitForEntries(1, in: store)
        let entry = try XCTUnwrap(store.recentEntries.last)
        XCTAssertEqual(entry.metadata["length"], "12")
        XCTAssertEqual(entry.metadata["secure"], "true")
    }

    func testSequenceMonotonicallyIncreases() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        store.log(.debug, .app, event: "one")
        store.log(.debug, .app, event: "two")
        await waitForEntries(2, in: store)
        XCTAssertEqual(store.recentEntries.count, 2)
        XCTAssertLessThan(store.recentEntries[0].sequence, store.recentEntries[1].sequence)
    }

    func testConcurrentLoggingProducesCompleteUniqueSequence() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            store.log(.debug, .performance, event: "concurrent.\(index)")
        }

        await waitForEntries(100, in: store)
        let sequences = store.recentEntries.map(\.sequence)
        XCTAssertEqual(sequences.count, 100)
        XCTAssertEqual(Set(sequences).count, 100)
        XCTAssertEqual(sequences, sequences.sorted())
    }

    func testExpandedRetentionAndColdReloadOrdering() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        XCTAssertEqual(store.retentionBytes, 512 * 1_024 * 1_024)
        for index in 0..<12 { store.log(.debug, .ui, event: "order.\(index)") }
        let snapshot = try store.exportBundle(context: "test.cold-reload")
        defer { try? FileManager.default.removeItem(at: snapshot) }
        let reloaded = DiagnosticLogStore(rootDirectory: root)
        XCTAssertEqual(reloaded.recentEntries.count, 12)
        XCTAssertEqual(reloaded.rotationEvictions, 0)
        XCTAssertEqual(reloaded.retentionPressurePercent >= 0, true)
        XCTAssertEqual(reloaded.recentEntries.map(\.sequence), Array(1...12).map(UInt64.init))
        XCTAssertEqual(reloaded.recentEntries.last?.event, "order.11")
    }

    func testBubbleTraceMetadataContainsNoTextOrPersistentIdentifiers() {
        let fields = DiagnosticBubbleTracePolicy.metadata(
            conversationToken: 7, bubbleToken: 11, tokenEpoch: 0,
            ordinal: 2, outgoing: true, delivery: .delivered,
            sentAt: Date(timeIntervalSince1970: 1_700_000_000),
            hasAttachment: false
        )
        XCTAssertEqual(fields["ordinal"], "2")
        XCTAssertEqual(fields["direction"], "outbound")
        XCTAssertEqual(fields["delivery"], "delivered")
        XCTAssertEqual(fields["plaintext_recorded"], "false")
        XCTAssertEqual(Set(fields.keys), Set([
            "conversation_token", "bubble_token", "token_epoch", "ordinal",
            "direction", "delivery", "sent_at_ms", "has_attachment", "plaintext_recorded"
        ]))
        XCTAssertFalse(fields.values.joined(separator: "|").contains("private"))
    }

    private func waitForEntries(_ count: Int, in store: DiagnosticLogStore) async {
        // The existing export API synchronizes the serial log queue before
        // reading it. Use that real completion barrier instead of assuming
        // a utility queue will finish within 200 short scheduler sleeps.
        // All record-count, uniqueness and ordering assertions remain intact.
        do {
            let snapshot = try store.exportBundle(context: "xctest.log-queue-barrier")
            defer { try? FileManager.default.removeItem(at: snapshot) }
        } catch {
            XCTFail("Could not synchronize diagnostic records: \(error)")
        }
        XCTAssertGreaterThanOrEqual(store.recentEntries.count, count)
    }

    func testStallPolicyRejectsSuspensionAndResumeGrace() {
        XCTAssertFalse(DeepTelemetryStallPolicy.shouldReport(
            delta: 3_600,
            applicationActive: false,
            nowUptime: 10_000,
            resumeGraceUntilUptime: 0
        ))
        XCTAssertFalse(DeepTelemetryStallPolicy.shouldReport(
            delta: 3_600,
            applicationActive: true,
            nowUptime: 10_000,
            resumeGraceUntilUptime: 10_001
        ))
        XCTAssertTrue(DeepTelemetryStallPolicy.shouldReport(
            delta: 1.6,
            applicationActive: true,
            nowUptime: 10_000,
            resumeGraceUntilUptime: 9_000
        ))
    }

}
