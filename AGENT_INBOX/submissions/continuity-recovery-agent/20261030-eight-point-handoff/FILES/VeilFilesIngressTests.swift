import Foundation
import XCTest
@testable import VeilLink

final class VeilFilesIngressTests: XCTestCase {
    func testStageAndCleanup() throws {
        let original = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".html")
        try Data("你好 Files".utf8).write(to: original)
        defer { try? FileManager.default.removeItem(at: original) }
        let copy = try VeilFilesIngress.stage(from: original, maximumBytes: 1024)
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "你好 Files")
        VeilFilesIngress.discard(copy)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }
    func testRejectsOversize() throws {
        let original = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data(repeating: 0x41, count: 100).write(to: original)
        defer { try? FileManager.default.removeItem(at: original) }
        XCTAssertThrowsError(try VeilFilesIngress.stage(from: original, maximumBytes: 99))
    }
    func testRejectsRemoteURL() {
        XCTAssertThrowsError(try VeilFilesIngress.withRead(from: URL(string: "https://example.org")!, maximumBytes: 10) { _ in true })
    }
    func testRejectsFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertThrowsError(try VeilFilesIngress.withRead(from: folder, maximumBytes: 100) { _ in true })
    }
    func testDoesNotDeleteArbitraryFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("not-owned-\(UUID().uuidString)")
        try Data("keep".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        VeilFilesIngress.discard(file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
}
