import Foundation
import XCTest
@testable import VeilLink

final class VeilImportStagingLeasePolicyTests: XCTestCase {
    private var temp: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        temp = fm.temporaryDirectory.appendingPathComponent("VLLeaseTest-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: temp)
    }

    private func createLease(name: String = UUID().uuidString, root: URL? = nil) throws -> URL {
        let anchor = root ?? VeilImportStagingLeasePolicy.stagingRoot(temporaryDirectory: temp)
        let folder = anchor.appendingPathComponent(name, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("snapshot.zip")
        XCTAssertTrue(fm.createFile(atPath: file.path, contents: Data([1,2,3])))
        return file
    }

    func testDeletesOnlyOwnedUUIDLease() throws {
        let root = VeilImportStagingLeasePolicy.stagingRoot(temporaryDirectory: temp)
        let file = try createLease(root: root)
        XCTAssertTrue(VeilImportStagingLeasePolicy.owns(file, root: root))
        XCTAssertTrue(try VeilImportStagingLeasePolicy.removeOwnedCopy(file, root: root))
        XCTAssertFalse(fm.fileExists(atPath: file.path))
    }

    func testRejectsLookalikeAndNonUUIDDirectory() throws {
        let actualRoot = VeilImportStagingLeasePolicy.stagingRoot(temporaryDirectory: temp)
        let lookalike = temp.appendingPathComponent("outside/VeilLink-Import-Staging")
        let foreign = try createLease(root: lookalike)
        XCTAssertFalse(VeilImportStagingLeasePolicy.owns(foreign, root: actualRoot))
        XCTAssertFalse(try VeilImportStagingLeasePolicy.removeOwnedCopy(foreign, root: actualRoot))
        XCTAssertTrue(fm.fileExists(atPath: foreign.path))
        let bogus = try createLease(name: "not-a-uuid", root: actualRoot)
        XCTAssertFalse(try VeilImportStagingLeasePolicy.removeOwnedCopy(bogus, root: actualRoot))
        XCTAssertTrue(fm.fileExists(atPath: bogus.path))
    }

    func testSweepKeepsFreshLease() throws {
        let root = VeilImportStagingLeasePolicy.stagingRoot(temporaryDirectory: temp)
        let current = try createLease(root: root)
        let result = try VeilImportStagingLeasePolicy.sweepExpired(root: root, now: Date(), lifetime: 3600)
        XCTAssertEqual(result.removed, 0)
        XCTAssertTrue(fm.fileExists(atPath: current.path))
    }

    func testSweepRemovesOnlyExpiredLease() throws {
        let root = VeilImportStagingLeasePolicy.stagingRoot(temporaryDirectory: temp)
        let old = try createLease(root: root)
        let fresh = try createLease(root: root)
        let futureNow = Date().addingTimeInterval(100000)
        try fm.setAttributes([.modificationDate: futureNow], ofItemAtPath: fresh.deletingLastPathComponent().path)
        let result = try VeilImportStagingLeasePolicy.sweepExpired(root: root, now: futureNow, lifetime: 3600)
        XCTAssertEqual(result.removed, 1)
        XCTAssertFalse(fm.fileExists(atPath: old.path))
        XCTAssertTrue(fm.fileExists(atPath: fresh.path))
    }

    func testSweepHonorsRemovalBudget() throws {
        let root = VeilImportStagingLeasePolicy.stagingRoot(temporaryDirectory: temp)
        let old = try (0..<3).map { _ in try createLease(root: root) }
        let futureNow = Date().addingTimeInterval(100000)
        let result = try VeilImportStagingLeasePolicy.sweepExpired(root: root, now: futureNow, lifetime: 3600, maxRemovals: 1)
        XCTAssertEqual(result.removed, 1)
        XCTAssertEqual(old.filter { fm.fileExists(atPath: $0.path) }.count, 2)
    }

    func testRejectsSymlinkLease() throws {
        let root = VeilImportStagingLeasePolicy.stagingRoot(temporaryDirectory: temp)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let outside = temp.appendingPathComponent("outside", isDirectory: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        let file = outside.appendingPathComponent("snapshot.zip")
        XCTAssertTrue(fm.createFile(atPath: file.path, contents: Data([1])))
        let linked = root.appendingPathComponent(UUID().uuidString)
        try fm.createSymbolicLink(at: linked, withDestinationURL: outside)
        let spoof = linked.appendingPathComponent("snapshot.zip")
        XCTAssertFalse(VeilImportStagingLeasePolicy.owns(spoof, root: root))
        let result = try VeilImportStagingLeasePolicy.sweepExpired(root: root, now: Date().addingTimeInterval(1_000_000), lifetime: 1)
        XCTAssertEqual(result.removed, 0)
        XCTAssertTrue(fm.fileExists(atPath: file.path))
    }
}
