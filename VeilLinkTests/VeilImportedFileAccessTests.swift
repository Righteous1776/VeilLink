import Foundation
import XCTest
@testable import VeilLink

final class VeilImportedFileAccessTests: XCTestCase {
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
