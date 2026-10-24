import XCTest
@testable import VeilLink

final class VeilStorageMaintenanceTests: XCTestCase {
    private func roots() throws -> (URL, VeilStorageRoots) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VeilStorageTests-\(UUID().uuidString)", isDirectory: true)
        let support = root.appendingPathComponent("Support/VeilLink", isDirectory: true)
        let roots = VeilStorageRoots(
            appSupport: support,
            downloads: support.appendingPathComponent("Downloads", isDirectory: true),
            diagnostics: support.appendingPathComponent("Diagnostics", isDirectory: true),
            documents: root.appendingPathComponent("Documents", isDirectory: true),
            temporary: root.appendingPathComponent("tmp", isDirectory: true)
        )
        for url in [support, roots.downloads, roots.diagnostics, roots.documents, roots.temporary] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return (root, roots)
    }

    func testScanSeparatesProtectedDataFromRecoverableData() async throws {
        let (root, roots) = try roots(); defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 1, count: 11).write(to: roots.appSupport.appendingPathComponent("veillink.sqlite"))
        try Data(repeating: 2, count: 23).write(to: roots.downloads.appendingPathComponent("map.pack"))
        let engine = VeilStorageMaintenance(roots: roots)

        let snapshot = await engine.scan()
        XCTAssertEqual(snapshot.categories.first(where: { $0.category == .protectedData })?.byteCount, 11)
        XCTAssertEqual(snapshot.categories.first(where: { $0.category == .downloads })?.byteCount, 23)
    }

    func testCleanupNeverDeletesDatabaseOrAttachments() async throws {
        let (root, roots) = try roots(); defer { try? FileManager.default.removeItem(at: root) }
        let database = roots.appSupport.appendingPathComponent("veillink.sqlite")
        let attachments = roots.appSupport.appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
        try Data([1]).write(to: database)
        try Data([2]).write(to: attachments.appendingPathComponent("ciphertext"))
        try Data([3]).write(to: roots.downloads.appendingPathComponent("offline.pack"))

        let result = await VeilStorageMaintenance(roots: roots).clean([.downloads, .protectedData])
        XCTAssertEqual(result.removedItems, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: database.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachments.appendingPathComponent("ciphertext").path))
    }

    func testOnlyVeilLinkZipExportsAreCandidates() async throws {
        let (root, roots) = try roots(); defer { try? FileManager.default.removeItem(at: root) }
        let allowed = roots.documents.appendingPathComponent("VeilLink-20261023.zip")
        let unrelated = roots.documents.appendingPathComponent("holiday.zip")
        let lookalike = roots.documents.appendingPathComponent("VeilLink-not-a-zip.txt")
        try Data(repeating: 1, count: 7).write(to: allowed)
        try Data(repeating: 2, count: 8).write(to: unrelated)
        try Data(repeating: 3, count: 9).write(to: lookalike)

        _ = await VeilStorageMaintenance(roots: roots).clean([.backupExports])
        XCTAssertFalse(FileManager.default.fileExists(atPath: allowed.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lookalike.path))
    }

    func testRecentTemporaryExportIsNotDeleted() async throws {
        let (root, roots) = try roots(); defer { try? FileManager.default.removeItem(at: root) }
        let recent = roots.temporary.appendingPathComponent("VeilVoice-recent.m4a")
        let old = roots.temporary.appendingPathComponent("VeilLink-DeepTelemetry-old.zip")
        try Data([1]).write(to: recent)
        try Data([2]).write(to: old)
        let clock = Date(timeIntervalSince1970: 2_000_000)
        try FileManager.default.setAttributes([.modificationDate: clock.addingTimeInterval(-VeilStorageMaintenance.staleTemporaryAge - 1)], ofItemAtPath: old.path)

        _ = await VeilStorageMaintenance(roots: roots, now: { clock }).clean([.staleTemporaryExports])
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
    }

    func testSymlinkTargetOutsideDownloadRootIsNotTraversedOrDeleted() async throws {
        let (root, roots) = try roots(); defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside.txt")
        let link = roots.downloads.appendingPathComponent("outside-link")
        try Data([9]).write(to: outside)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        let snapshot = await VeilStorageMaintenance(roots: roots).scan()
        XCTAssertEqual(snapshot.categories.first(where: { $0.category == .downloads })?.byteCount, 0)
        _ = await VeilStorageMaintenance(roots: roots).clean([.downloads])
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }
}
