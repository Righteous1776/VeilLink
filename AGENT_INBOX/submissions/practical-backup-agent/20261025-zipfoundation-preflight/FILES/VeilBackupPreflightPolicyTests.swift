import Foundation
import XCTest
@testable import VeilBackupPreflight

final class VeilBackupPreflightPolicyTests: XCTestCase {
    private typealias P = VeilBackupPreflightPolicy
    private func f(_ name: String, compressed: UInt64 = 1024, expanded: UInt64 = 2048) -> P.EntryInfo {
        .init(path: name, kind: .file, compressedBytes: compressed, expandedBytes: expanded)
    }
    private var healthy: [P.EntryInfo] {
        [f("manifest.json"), f("database.enc"), f("storage-key.enc"), f("identity.enc"),
         .init(path: "attachments/", kind: .directory, compressedBytes: 0, expandedBytes: 0)]
    }
    private func evaluate(_ entries: [P.EntryInfo]) -> P.Report { P.evaluate(entries, zipBytes: 64_000) }

    func testOrdinaryBackupPassesButDoesNotPretendDecryption() {
        let report = evaluate(healthy)
        XCTAssertTrue(report.permittedToRestore)
        XCTAssertFalse(report.crcVerified)
        XCTAssertEqual(report.entries, 5)
        XCTAssertEqual(report.attachments, 0)
        XCTAssertNil(report.version)
    }

    func testAttachmentUUIDAllowedAndCounted() {
        let additional = f("attachments/DEADBEEF-DEAD-4F00-8000-111111111111.bin")
        let report = evaluate(healthy + [additional])
        XCTAssertTrue(report.permittedToRestore)
        XCTAssertEqual(report.attachments, 1)
    }

    func testMissingManifestFails() {
        let report = evaluate(healthy.filter { $0.path != "manifest.json" })
        XCTAssertTrue(report.problems.contains(.missingRequiredFile))
    }

    func testDuplicateRequiredFileFails() {
        let report = evaluate(healthy + [f("manifest.json")])
        XCTAssertTrue(report.problems.contains(.duplicatePath))
    }

    func testCaseFoldAttachmentCollisionFails() {
        let id = "DEADBEEF-DEAD-4F00-8000-111111111111"
        let report = evaluate(healthy + [f("attachments/\(id).bin"), f("attachments/\(id.lowercased()).bin")])
        XCTAssertTrue(report.problems.contains(.duplicatePath))
    }

    func testAbsoluteParentTraversalAndBackslashesRejected() {
        for bad in ["../manifest.json", "/manifest.json", "attachments/../../identity.enc", "attachments\\123.bin", "C:/manifest.json"] {
            var list = healthy
            list.append(f(bad))
            XCTAssertFalse(evaluate(list).permittedToRestore, bad)
        }
    }

    func testSymlinkAndUnknownTypeRejected() {
        for kind in [P.Kind.symlink, .other] {
            let injected = P.EntryInfo(path: "manifest.json", kind: kind, compressedBytes: 1, expandedBytes: 1)
            let report = evaluate(healthy + [injected])
            XCTAssertTrue(report.problems.contains(.symlink))
        }
    }

    func testCompressedSizeZeroWithPayloadRejected() {
        let report = evaluate(healthy + [f("attachments/DEADBEEF-DEAD-4F00-8000-111111111111.bin", compressed: 0, expanded: 2)])
        XCTAssertTrue(report.problems.contains(.implausibleCompression))
    }

    func testExcessiveExpansionRatioRejected() {
        let report = evaluate(healthy + [f("database.enc", compressed: 300, expanded: 4 * 1024 * 1024)])
        XCTAssertTrue(report.problems.contains(.implausibleCompression))
    }

    func testOversizedArchiveRejectedBeforeUnzip() {
        let report = P.evaluate(healthy, zipBytes: P.maxArchiveBytes + 1)
        XCTAssertTrue(report.problems.contains(.archiveTooLarge))
    }

    func testAggregateExpansionBound() {
        let report = P.evaluate(healthy + [f("database.enc", compressed: 64 * 1024 * 1024,
                                                  expanded: P.maxExpandedBytes + 1)], zipBytes: P.maxArchiveBytes)
        XCTAssertTrue(report.problems.contains(.tooLargeExpanded))
    }

    func testDeclaredCompressedContentLargerThanArchiveRejected() {
        let report = P.evaluate(healthy + [f("database.enc", compressed: 100_000, expanded: 100_000)], zipBytes: 24_000)
        XCTAssertTrue(report.problems.contains(.invalidEntrySize))
    }

    func testUnsafeNamesAndExtraRootRejected() {
        for bad in ["metadata.json", "attachments/abc.txt", "attachments//x.bin", "./manifest.json", "manifest.json/", "attachments"] {
            XCTAssertFalse(evaluate(healthy + [f(bad)]).permittedToRestore, bad)
        }
    }

    func testTooManyEntries() {
        let attachment = f("attachments/DEADBEEF-DEAD-4F00-8000-111111111111.bin", compressed: 1, expanded: 1)
        let report = P.evaluate(healthy + Array(repeating: attachment, count: P.maxEntryCount), zipBytes: 80_000)
        XCTAssertTrue(report.problems.contains(.tooManyEntries))
    }

    func testReportProblemsAreDistinctAndPreserved() {
        let first = evaluate(healthy)
        let next = first.appending([.invalidManifest, .invalidManifest], version: 2, createdAt: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(next.problems, [.invalidManifest])
        XCTAssertFalse(next.permittedToRestore)
        XCTAssertEqual(next.version, 2)
    }

    func testNoCopyOfPrivatePathInDiagnosticLabels() {
        for p in P.Problem.allCases {
            XCTAssertFalse(p.explanation.contains("/private/"))
            XCTAssertFalse(p.explanation.isEmpty)
        }
    }
}
