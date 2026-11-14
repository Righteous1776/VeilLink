import Foundation
import XCTest
@testable import VeilLink

final class VeilFileInboxTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!
    private var source: URL!

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent(
            "VeilInboxTest-" + UUID().uuidString, isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        source = root.appendingPathComponent("origin.vltrain.json")
        try Data("hello".utf8).write(to: source)
    }

    override func tearDownWithError() throws {
        if let root { try? fm.removeItem(at: root) }
    }

    private var inboxRoot: URL {
        root.appendingPathComponent("inbox", isDirectory: true)
    }

    func testFilesPickerCopyBecomesDurableAndVerifiedWithoutChangingSource() throws {
        let staged = try VeilImportedFileAccess.materialize(source)
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }

        let record = try VeilFileInbox.importStaged(staged, root: inboxRoot)
        XCTAssertEqual(record.kind, .boardTrainingCandidate)
        XCTAssertEqual(record.displayName, source.lastPathComponent)
        XCTAssertEqual(record.byteCount, 5)
        XCTAssertEqual(record.sha256, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        XCTAssertTrue(try VeilFileInbox.verify(record, root: inboxRoot))
        XCTAssertEqual(try VeilFileInbox.list(root: inboxRoot), [record])
        XCTAssertEqual(try Data(contentsOf: source), Data("hello".utf8))

        VeilImportedFileAccess.removeStagedCopy(staged)
        XCTAssertTrue(fm.fileExists(atPath: try VeilFileInbox.fileURL(for: record, root: inboxRoot).path))
    }

    func testUnownedProviderPathCannotBypassStagingBoundary() {
        XCTAssertThrowsError(try VeilFileInbox.importStaged(source, root: inboxRoot)) {
            guard case VeilFileInboxError.notStaged = $0 else {
                return XCTFail("Expected unowned staging rejection: \($0)")
            }
        }
    }

    func testSameFilenameNeverOverwritesEarlierImport() throws {
        let staged = try VeilImportedFileAccess.materialize(source)
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        let first = try VeilFileInbox.importStaged(staged, root: inboxRoot)
        let second = try VeilFileInbox.importStaged(staged, root: inboxRoot)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(try VeilFileInbox.list(root: inboxRoot).count, 2)
        try VeilFileInbox.remove(first, root: inboxRoot)
        XCTAssertTrue(try VeilFileInbox.verify(second, root: inboxRoot))
        XCTAssertEqual(try Data(contentsOf: source), Data("hello".utf8))
    }

    func testOversizeRejectedBeforePublishing() throws {
        let staged = try VeilImportedFileAccess.materialize(source)
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        XCTAssertThrowsError(try VeilFileInbox.importStaged(staged, root: inboxRoot, maximumBytes: 4)) {
            guard case VeilFileInboxError.oversized = $0 else {
                return XCTFail("Expected file size guard: \($0)")
            }
        }
        XCTAssertTrue(try VeilFileInbox.list(root: inboxRoot).isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), Data("hello".utf8))
    }

    func testBitFlipDetectedAndTamperedFileNotShared() throws {
        let staged = try VeilImportedFileAccess.materialize(source)
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        let record = try VeilFileInbox.importStaged(staged, root: inboxRoot)
        let target = try VeilFileInbox.fileURL(for: record, root: inboxRoot)
        try Data("HELLO".utf8).write(to: target)
        XCTAssertFalse(try VeilFileInbox.verify(record, root: inboxRoot))
        // Integrity failure does not rewrite the original selected file.
        XCTAssertEqual(try Data(contentsOf: source), Data("hello".utf8))
    }

    func testArbitraryNPZAndZIPCanBeStoredWithoutPretendingToLoadModels() throws {
        XCTAssertEqual(VeilFileInboxKind.detect(filename: "brain.npz"), .numpy)
        XCTAssertEqual(VeilFileInboxKind.detect(filename: "weights.npz.zip"), .archive)
        XCTAssertEqual(VeilFileInboxKind.detect(filename: "training.vltrain.json"), .boardTrainingCandidate)
        XCTAssertEqual(VeilFileInboxKind.detect(filename: "backup.zip"), .archive)
    }
}
