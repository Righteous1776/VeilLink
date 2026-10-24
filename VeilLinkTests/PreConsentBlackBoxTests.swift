import Foundation
import XCTest
@testable import VeilLink

@MainActor
final class PreConsentBlackBoxTests: XCTestCase {
    func testPreConsentExportContainsOnlyFixedEventSchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("preconsent-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let box = VeilPreConsentBlackBox(rootDirectory: directory)
        box.record(.appLaunched, stage: .launch)
        box.record(.legalShown, stage: .consent)
        box.record(.signTapped, stage: .consent)
        let data = try box.exportData()
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("VeilLinkPreConsentBlackBox"))
        XCTAssertTrue(text.contains("signTapped"))
        XCTAssertTrue(text.contains("legalShown"))
        XCTAssertFalse(text.contains("private_key"))
        XCTAssertFalse(text.contains("我已阅读并同意"))
        let destination = try box.exportFile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        try? FileManager.default.removeItem(at: destination)
    }

    func testPersistsLastEventsAcrossColdRelaunchAndBoundsRecords() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("preconsent-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = VeilPreConsentBlackBox(rootDirectory: directory)
        for _ in 0..<160 { first.record(.confirmationChanged, stage: .consent) }
        XCTAssertEqual(first.entries.count, 128)
        let subsequent = VeilPreConsentBlackBox(rootDirectory: directory)
        XCTAssertEqual(subsequent.entries.count, 128)
        XCTAssertEqual(subsequent.entries.last?.sequence, 160)
        subsequent.record(.appLaunched, stage: .launch)
        XCTAssertEqual(subsequent.entries.last?.sequence, 161)
        XCTAssertEqual(subsequent.entries.count, 128)
    }

    func testNoLegalOrRuntimeInitializationNeededForExport() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("preconsent-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let box = VeilPreConsentBlackBox(rootDirectory: directory)
        XCTAssertNoThrow(try box.exportData())
        XCTAssertTrue(box.entries.isEmpty)
    }
}
