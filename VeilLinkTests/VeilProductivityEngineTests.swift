import XCTest
@testable import VeilLink

final class VeilProductivityEngineTests: XCTestCase {
    func testTemplateFindsUniqueVariablesAndRejectsMissingValues() throws {
        let source = "{{name}} / {{ file }} / {{name}}"
        XCTAssertEqual(try VeilProductivityEngine.analyzeTemplate(source).variables, ["name", "file"])
        XCTAssertThrowsError(try VeilProductivityEngine.renderTemplate(source, values: ["name": "A"])) {
            XCTAssertEqual($0 as? VeilProductivityError, .missingVariables(["file"]))
        }
        XCTAssertEqual(
            try VeilProductivityEngine.renderTemplate(source, values: ["name": "A", "file": "B"]),
            "A / B / A"
        )
    }

    func testTemplateRejectsMalformedPlaceholder() throws {
        XCTAssertTrue(try VeilProductivityEngine.analyzeTemplate("hello {{name").malformed)
        XCTAssertTrue(try VeilProductivityEngine.analyzeTemplate("hello }}").malformed)
        XCTAssertThrowsError(try VeilProductivityEngine.renderTemplate("{{ }}", values: [:])) {
            XCTAssertEqual($0 as? VeilProductivityError, .malformedPlaceholder)
        }
    }

    func testLineDiffProducesStableEditScript() throws {
        XCTAssertEqual(
            try VeilProductivityEngine.diff(old: "one\ntwo\nthree", new: "one\nTWO\nthree\nfour"),
            [
                VeilDiffLine(kind: .unchanged, text: "one"),
                VeilDiffLine(kind: .added, text: "TWO"),
                VeilDiffLine(kind: .removed, text: "two"),
                VeilDiffLine(kind: .unchanged, text: "three"),
                VeilDiffLine(kind: .added, text: "four")
            ]
        )
    }

    func testDiffHasHardLineAndByteLimits() {
        let tooManyLines = Array(repeating: "x", count: 401).joined(separator: "\n")
        XCTAssertThrowsError(try VeilProductivityEngine.diff(old: tooManyLines, new: "")) {
            XCTAssertEqual($0 as? VeilProductivityError, .diffTooLarge)
        }
        XCTAssertThrowsError(try VeilProductivityEngine.diff(old: String(repeating: "x", count: 65_537), new: "")) {
            XCTAssertEqual($0 as? VeilProductivityError, .diffTooLarge)
        }
    }

    func testThreeWayMergeOnlyAutoResolvesUnambiguousCases() throws {
        XCTAssertEqual(
            try VeilProductivityEngine.threeWayMerge(base: "a", local: "a", remote: "b"),
            VeilMergeResult(text: "b", hasConflict: false)
        )
        let conflict = try VeilProductivityEngine.threeWayMerge(base: "a", local: "b", remote: "c")
        XCTAssertTrue(conflict.hasConflict)
        XCTAssertTrue(conflict.text.contains("<<<<<<< 本机"))
        XCTAssertTrue(conflict.text.contains(">>>>>>> 对端"))
    }

    func testMeetingPlannerRanksMutuallyComfortableSlotFirst() throws {
        let participants = [
            VeilTimeZoneParticipant(label: "UTC", timeZoneIdentifier: "UTC", preferredStartHour: 9, preferredEndHour: 18),
            VeilTimeZoneParticipant(label: "Berlin", timeZoneIdentifier: "Europe/Berlin", preferredStartHour: 9, preferredEndHour: 18)
        ]
        let start = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00 UTC
        let slots = try VeilProductivityEngine.meetingSlots(from: start, participants: participants, days: 1, limit: 4)
        XCTAssertEqual(slots.count, 4)
        XCTAssertTrue(slots.allSatisfy { $0.comfortableParticipantCount == 2 })
        XCTAssertEqual(slots.first?.date, Date(timeIntervalSince1970: 1_704_099_600)) // 09:00 UTC, 10:00 Berlin
    }

    func testMeetingPlannerRejectsUnknownTimeZone() {
        let participant = VeilTimeZoneParticipant(label: "bad", timeZoneIdentifier: "Moon/Sea", preferredStartHour: 9, preferredEndHour: 18)
        XCTAssertThrowsError(try VeilProductivityEngine.meetingSlots(from: Date(), participants: [participant])) {
            XCTAssertEqual($0 as? VeilProductivityError, .invalidTimeZone("Moon/Sea"))
        }
    }

    func testImportPreflightBlocksTraversalDuplicatesAndTypeMismatch() throws {
        let result = try VeilProductivityEngine.importPreflight(
            items: [
                VeilImportItem(name: "../secret.txt", byteCount: 12),
                VeilImportItem(name: "Résumé.TXT", byteCount: 10),
                VeilImportItem(name: "resume.txt", byteCount: 0),
                VeilImportItem(name: "image.exe", byteCount: 4)
            ],
            allowedExtensions: ["txt"]
        )
        XCTAssertFalse(result.canImport)
        XCTAssertEqual(result.totalBytes, 26)
        XCTAssertTrue(result.issues.contains { $0.message == "文件名不安全" })
        XCTAssertTrue(result.issues.contains { $0.message == "规范化后文件名重复" })
        XCTAssertTrue(result.issues.contains { $0.message == "不允许的文件类型" })
        XCTAssertTrue(result.issues.contains { $0.severity == .warning && $0.message == "空文件" })
    }

    func testImportPreflightAcceptsSafeManifest() throws {
        let result = try VeilProductivityEngine.importPreflight(
            items: [VeilImportItem(name: "notes.txt", byteCount: 128)],
            allowedExtensions: ["txt"]
        )
        XCTAssertTrue(result.canImport)
        XCTAssertEqual(result.itemCount, 1)
        XCTAssertEqual(result.totalBytes, 128)
        XCTAssertTrue(result.issues.isEmpty)
    }
}
