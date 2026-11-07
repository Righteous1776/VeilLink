import Foundation
import XCTest
@testable import VeilLink

final class VeilImportedFileAccessTests: XCTestCase {
    func testChatTextImportUsesOwnedSnapshotAndRequiresUserSend() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-source-\(UUID().uuidString).txt")
        let expected = "消息来自 Files，等待用户确认"
        try Data(expected.utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let staged = try VeilImportedFileAccess.materialize(source, acceptedExtensions: ["txt"])
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        XCTAssertEqual(try VeilImportedFileAccess.chatDraftText(from: staged), expected)
        XCTAssertEqual(try Data(contentsOf: source), Data(expected.utf8))
    }

    func testChatTextRejectsBinaryAndUnsafeExtensions() throws {
        for ext in ["pdf", "zip", "sh", "exe"] {
            let source = FileManager.default.temporaryDirectory
                .appendingPathComponent("chat-binary-\(UUID().uuidString).\(ext)")
            try Data("not an attachment".utf8).write(to: source)
            defer { try? FileManager.default.removeItem(at: source) }
            let staged = try VeilImportedFileAccess.materialize(source)
            defer { VeilImportedFileAccess.removeStagedCopy(staged) }
            XCTAssertThrowsError(try VeilImportedFileAccess.chatDraftText(from: staged))
        }
    }

    func testChatTextRejectsOversizeAndInvalidUTF8() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-large-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: source) }
        try Data(repeating: 65, count: VeilImportedFileAccess.maximumChatDraftBytes + 1).write(to: source)
        var staged = try VeilImportedFileAccess.materialize(source)
        XCTAssertThrowsError(try VeilImportedFileAccess.chatDraftText(from: staged))
        VeilImportedFileAccess.removeStagedCopy(staged)

        try Data([0xFF, 0x00, 0xEF]).write(to: source)
        staged = try VeilImportedFileAccess.materialize(source)
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        XCTAssertThrowsError(try VeilImportedFileAccess.chatDraftText(from: staged))
    }

    func testMaterializeCopiesProviderFileBeforeGrantEnds() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-source-\(UUID().uuidString).vltrain.json")
        let expected = Data("{\"ok\":true}".utf8)
        try expected.write(to: source, options: .atomic)
        defer { try? FileManager.default.removeItem(at: source) }

        let staged = try VeilImportedFileAccess.materialize(
            source,
            acceptedExtensions: ["json"]
        )
        XCTAssertEqual(try Data(contentsOf: staged), expected)
        XCTAssertNotEqual(staged.deletingLastPathComponent(), source.deletingLastPathComponent())

        VeilImportedFileAccess.removeStagedCopy(staged)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
    }

    func testMaterializeRejectsWrongExtensionEvenWhenPickerShowsItem() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-source-\(UUID().uuidString).txt")
        try Data("not a backup".utf8).write(to: source, options: .atomic)
        defer { try? FileManager.default.removeItem(at: source) }

        XCTAssertThrowsError(
            try VeilImportedFileAccess.materialize(
                source,
                acceptedExtensions: ["zip"]
            )
        )
    }

    func testBoundedMaterializationRejectsLargeInputWithoutLeavingStagingLease() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("bounded-import-\(UUID().uuidString).zip")
        try Data(repeating: 0x42, count: 2_100_000).write(to: source, options: .atomic)
        defer { try? FileManager.default.removeItem(at: source) }
        XCTAssertThrowsError(
            try VeilImportedFileAccess.materialize(
                source, maximumBytes: MediaTransferPolicy.maximumGenericFileBytes
            )
        ) { error in
            guard case VeilImportedFileAccessError.tooLarge = error else {
                XCTFail("Expected bounded provider copy failure: \(error)")
                return
            }
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testBackgroundMaterializationCopiesLargeFile() async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-source-\(UUID().uuidString).zip")
        let expected = Data(repeating: 0x5A, count: 3 * 1_024 * 1_024)
        try expected.write(to: source, options: .atomic)
        defer { try? FileManager.default.removeItem(at: source) }

        let staged = try await VeilImportedFileAccess.materializeInBackground(
            source,
            acceptedExtensions: ["zip"]
        )
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        XCTAssertEqual(try Data(contentsOf: staged), expected)
    }
}
