import XCTest
import CryptoKit
import ZIPFoundation
@testable import VeilLink

@MainActor
final class BlackBoxExportIntegrityTests: XCTestCase {
    private func unpack(_ archiveURL: URL, to output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: archiveURL, to: output)
    }

    private func readJSON(_ name: String, in root: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appendingPathComponent(name))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testManifestCountsExactlyTheRetainedZIPEventsNotTheMemoryWindow() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        for i in 0..<120 {
            store.log(.info, .ui, event: "test.record.\(i)")
        }
        // First export is the same completion barrier used by existing tests.
        let first = try store.exportBundle(context: "xctest.flush")
        try? FileManager.default.removeItem(at: first)
        XCTAssertEqual(store.recentEntries.count, 120)

        // Simulate disk retention/recovery loss: the in-memory cache remains
        // 120 while the only physically included runtime file is empty.
        let logURL = root.appendingPathComponent("runtime.jsonl")
        try Data().write(to: logURL, options: .atomic)

        let zipped = try store.exportBundle(context: "xctest.memory-disk-mismatch")
        defer { try? FileManager.default.removeItem(at: zipped) }
        let output = root.appendingPathComponent("unzipped")
        try unpack(zipped, to: output)
        let manifest = try readJSON("manifest.json", in: output)
        let index = try readJSON("event-index.json", in: output)

        XCTAssertEqual(manifest["eventCount"] as? Int, 0)
        XCTAssertEqual(index["eventCount"] as? Int, 0)
        XCTAssertEqual(manifest["inMemoryEventCount"] as? Int, 120)
        XCTAssertEqual(manifest["invalidLineCount"] as? Int, 0)
        XCTAssertEqual(manifest["logFileCount"] as? Int, 1)
        let files = try XCTUnwrap(index["files"] as? [[String: Any]])
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0]["eventCount"] as? Int, 0)
        XCTAssertEqual(files[0]["name"] as? String, "runtime.jsonl")
    }

    func testIncludedFileSHA256MatchesTheActualStagedPayload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiagnosticLogStore(rootDirectory: root)
        for i in 0..<8 { store.log(.debug, .app, event: "sha.record.\(i)") }
        let zipURL = try store.exportBundle(context: "xctest.sha256")
        defer { try? FileManager.default.removeItem(at: zipURL) }
        let output = root.appendingPathComponent("contents")
        try unpack(zipURL, to: output)
        let manifest = try readJSON("manifest.json", in: output)
        XCTAssertEqual(manifest["eventCount"] as? Int, 8)
        let files = try XCTUnwrap(manifest["files"] as? [[String: Any]])
        let row = try XCTUnwrap(files.first)
        let name = try XCTUnwrap(row["name"] as? String)
        let bytes = try Data(contentsOf: output.appendingPathComponent(name))
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", Int($0)) }.joined()
        XCTAssertEqual(row["sha256"] as? String, digest)
        XCTAssertEqual(row["byteCount"] as? Int, bytes.count)
        XCTAssertEqual(row["eventCount"] as? Int, 8)
    }

    func testNonEvaluatedA9HealthNeverClaimsGreen100() {
        let monitor = VeilA9HealthMonitor()
        let before = monitor.report()
        XCTAssertTrue(before.contains("未评估"))
        XCTAssertFalse(before.contains("Health: 100/100"))
        XCTAssertFalse(before.contains("Light: 绿色"))
        monitor.evaluate(VeilA9Input(), now: Date(), uptime: 1234)
        XCTAssertFalse(monitor.report().contains("Generated: not-evaluated"))
    }

    func testRotationObserverSeparatesNoiseFromActualChange() {
        XCTAssertEqual(DeepTelemetryOrientationPolicy.event(previous: nil, current: "portrait"),
                       "ui.orientation_observed")
        XCTAssertEqual(DeepTelemetryOrientationPolicy.event(previous: "portrait", current: "portrait"),
                       "ui.orientation_observed")
        XCTAssertEqual(DeepTelemetryOrientationPolicy.event(previous: "portrait", current: "landscapeLeft"),
                       "ui.orientation_change")
        XCTAssertEqual(DeepTelemetryOrientationPolicy.event(previous: "portrait", current: "unknown"),
                       "ui.orientation_observed")
    }
}
