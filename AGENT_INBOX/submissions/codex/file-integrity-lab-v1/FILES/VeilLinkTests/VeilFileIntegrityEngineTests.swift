import Foundation
import XCTest
@testable import VeilLink

final class VeilFileIntegrityEngineTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilFileIntegrityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testKnownSHA256AndExactByteCount() throws {
        let url = try file(named: "hello.txt", data: Data("hello".utf8))
        let result = try VeilFileIntegrityEngine.inspect(url: url)

        XCTAssertEqual(result.fileName, "hello.txt")
        XCTAssertEqual(result.byteCount, 5)
        XCTAssertEqual(
            result.sha256,
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    func testEmptyFileUsesStandardDigest() throws {
        let url = try file(named: "empty.bin", data: Data())
        let result = try VeilFileIntegrityEngine.inspect(url: url)

        XCTAssertEqual(result.byteCount, 0)
        XCTAssertEqual(
            result.sha256,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testComparisonChecksSizeAndDigest() throws {
        let payload = Data(repeating: 0xAB, count: VeilFileIntegrityEngine.readChunkBytes + 17)
        let first = try VeilFileIntegrityEngine.inspect(
            url: try file(named: "first.bin", data: payload)
        )
        let matching = try VeilFileIntegrityEngine.inspect(
            url: try file(named: "matching.bin", data: payload)
        )
        let different = try VeilFileIntegrityEngine.inspect(
            url: try file(named: "different.bin", data: payload + Data([0x00]))
        )

        XCTAssertEqual(first.byteCount, Int64(VeilFileIntegrityEngine.readChunkBytes + 17))
        XCTAssertEqual(VeilFileIntegrityEngine.compare(first, matching), .identical)
        XCTAssertEqual(VeilFileIntegrityEngine.compare(first, different), .different)
    }

    func testReportContainsNamesSizesAndHashesButNoPaths() throws {
        let first = try VeilFileIntegrityEngine.inspect(
            url: try file(named: "send.dat", data: Data("same".utf8))
        )
        let second = try VeilFileIntegrityEngine.inspect(
            url: try file(named: "receive.dat", data: Data("same".utf8))
        )
        let report = VeilFileIntegrityEngine.report(first: first, second: second)

        XCTAssertTrue(report.contains("send.dat"))
        XCTAssertTrue(report.contains("receive.dat"))
        XCTAssertTrue(report.contains("比较：完全一致"))
        XCTAssertTrue(report.contains(first.sha256))
        XCTAssertFalse(report.contains(temporaryDirectory.path))
    }

    func testDirectoryIsRejected() {
        XCTAssertThrowsError(try VeilFileIntegrityEngine.inspect(url: temporaryDirectory)) {
            XCTAssertEqual($0 as? VeilFileIntegrityError, .notRegularFile)
        }
    }

    private func file(named name: String, data: Data) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
