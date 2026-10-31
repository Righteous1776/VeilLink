import Foundation
import XCTest
import ZIPFoundation
@testable import VeilLink

/// Real ZIPFoundation runtime integration tests; run only on the Governor's
/// macOS/Xcode iOS CI/device lane, not in the standalone Linux policy package.
final class VeilBackupArchiveInspectorTests: XCTestCase {
    private func fixture(_ corrupted: Bool = false, omit: String? = nil) throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VL-preflight-\(UUID())")
        let staging = root.appendingPathComponent("Payload")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let manifest = BackupManifest(format: "VeilLinkBackup", version: 2,
                                      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                                      identityID: UUID().uuidString,
                                      salt: Data(repeating: 0x33, count: 16), iterations: 210_000)
        let payload: [(String, Data)] = [
            ("manifest.json", try JSONEncoder().encode(manifest)),
            ("database.enc", Data("encrypted-database-fixture".utf8)),
            ("storage-key.enc", Data("encrypted-storage-key-fixture".utf8)),
            ("identity.enc", Data("encrypted-identity-fixture".utf8))
        ]
        for (name, bytes) in payload where name != omit {
            try bytes.write(to: staging.appendingPathComponent(name), options: .atomic)
        }
        try FileManager.default.createDirectory(at: staging.appendingPathComponent("attachments"),
                                               withIntermediateDirectories: true)
        let archiveURL = root.appendingPathComponent("test.zip")
        try FileManager.default.zipItem(at: staging, to: archiveURL, shouldKeepParent: false)
        if corrupted {
            var data = try Data(contentsOf: archiveURL)
            data.removeLast(min(40, data.count / 2))
            try data.write(to: archiveURL)
        }
        return (root, archiveURL)
    }

    func testGeneratedVeilLinkShapePassesMetadata() throws {
        let (root, file) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let report = VeilBackupArchiveInspector.inspect(file, verifyAllCRC: false)
        XCTAssertTrue(report.permittedToRestore, "\(report.problems)")
        XCTAssertEqual(report.version, 2)
        XCTAssertFalse(report.crcVerified)
        XCTAssertTrue(report.safetyLabel.contains("尚未"))
    }

    func testGeneratedVeilLinkShapePassesFullCRC() throws {
        let (root, file) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let report = VeilBackupArchiveInspector.inspect(file, verifyAllCRC: true)
        XCTAssertTrue(report.permittedToRestore, "\(report.problems)")
        XCTAssertTrue(report.crcVerified)
    }

    func testRequiredFileMissingRejectsWithoutRestore() throws {
        let (root, file) = try fixture(omit: "database.enc")
        defer { try? FileManager.default.removeItem(at: root) }
        let report = VeilBackupArchiveInspector.inspect(file, verifyAllCRC: false)
        XCTAssertFalse(report.permittedToRestore)
        XCTAssertTrue(report.problems.contains(.missingRequiredFile))
    }

    func testTruncatedArchiveFailsClosed() throws {
        let (root, file) = try fixture(corrupted: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = VeilBackupArchiveInspector.inspect(file, verifyAllCRC: true)
        XCTAssertFalse(report.permittedToRestore)
    }

    func testNonZipRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-zip-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a zip".utf8).write(to: url)
        XCTAssertFalse(VeilBackupArchiveInspector.inspect(url, verifyAllCRC: false).permittedToRestore)
    }
}
