import Foundation
import XCTest
@testable import VeilLink

final class VeilFilesImportStageTests: XCTestCase {
    func testStagesReadableFilesAndDiscardsScopedCopy() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: source) }
        try Data("<h1>本地资料</h1>".utf8).write(to: source)
        let copied = try VeilFilesImportStage.stage(source, maximumBytes: 4_096)
        XCTAssertEqual(copied.pathExtension, "html")
        XCTAssertEqual(try Data(contentsOf: copied), Data("<h1>本地资料</h1>".utf8))
        XCTAssertNotEqual(copied, source)
        VeilFilesImportStage.discard(copied)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copied.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testOversizeIsRejectedWithoutDeletingSource() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("zip")
        defer { try? FileManager.default.removeItem(at: source) }
        try Data(repeating: 0xAA, count: 500).write(to: source)
        XCTAssertThrowsError(try VeilFilesImportStage.stage(source, maximumBytes: 128))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testCoordinatedReadIsRepeatableWithoutCopies() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: source) }
        try Data("{\"v\":1}".utf8).write(to: source)
        for _ in 0..<4 {
            let data = try VeilFilesImportStage.withCoordinatedRead(source) { coordinated in
                try Data(contentsOf: coordinated)
            }
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "{\"v\":1}")
        }
    }

    func testDiscardsOnlyItsOwnStagedFolder() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: source) }
        try Data("untouched".utf8).write(to: source)
        VeilFilesImportStage.discard(source)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "untouched")
        XCTAssertThrowsError(try VeilFilesImportStage.stage(URL(string: "https://example.invalid/")!, maximumBytes: 100))
    }
}
