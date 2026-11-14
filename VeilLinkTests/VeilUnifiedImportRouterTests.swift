import Foundation
import XCTest
@testable import VeilLink

final class VeilUnifiedImportRouterTests: XCTestCase {
    private func temporaryFile(named name: String, data: Data) throws -> URL {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnifiedRouter-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        let url = path.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func record(_ filename: String, kind: VeilFileInboxKind) -> VeilFileInboxRecord {
        VeilFileInboxRecord(
            id: UUID(), displayName: filename, storedName: filename,
            byteCount: 0, sha256: String(repeating: "0", count: 64),
            importedAt: Date(), kind: kind
        )
    }

    private func trainingEnvelope(positions: [String: Any], games: [[String: Any]] = []) throws -> Data {
        let envelope: [String: Any] = [
            "format": "veillink.board-learning.export.v1",
            "checksumAlgorithm": "fnv1a64-canonical-json",
            "payload": [
                "schema": 1,
                "positions": positions,
                "recentGames": games
            ]
        ]
        return try JSONSerialization.data(withJSONObject: envelope)
    }

    func testRoutesGomokuTrainingFromValidatedEnvelopeShape() throws {
        let url = try temporaryFile(
            named: "learning.json",
            data: trainingEnvelope(positions: ["g:abc": [:]])
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let route = VeilUnifiedImportRouter.resolve(record("learning.json", kind: .text), at: url)
        XCTAssertEqual(route, .boardLearning(.gomoku))
    }

    func testRoutesXiangqiTrainingWithoutCrossingGameScope() throws {
        let url = try temporaryFile(
            named: "chess.vltrain.json",
            data: trainingEnvelope(positions: ["x:abc": [:]])
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let route = VeilUnifiedImportRouter.resolve(
            record("chess.vltrain.json", kind: .boardTrainingCandidate), at: url
        )
        XCTAssertEqual(route, .boardLearning(.xiangqi))
    }

    func testRejectsMixedAndUnknownGameFamilies() throws {
        for positions in [
            ["x:abc": [:], "g:def": [:]],
            ["other:abc": [:]]
        ] as [[String: [String: String]]] {
            let url = try temporaryFile(
                named: "unsafe.vltrain.json", data: trainingEnvelope(positions: positions)
            )
            XCTAssertNil(VeilUnifiedImportRouter.boardLearningGame(at: url))
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    func testOrdinaryZIPCannotBecomeBackupByFilename() throws {
        let url = try temporaryFile(named: "VeilLinkBackup.zip", data: Data("not zip".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let route = VeilUnifiedImportRouter.resolve(record("VeilLinkBackup.zip", kind: .archive), at: url)
        guard case .retained = route else {
            return XCTFail("A fake archive must never be offered for backup restoration")
        }
    }

    func testHTMLPDFAndNPZHaveSeparateNonExecutingRoutes() throws {
        let url = try temporaryFile(named: "anything", data: Data("hello".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(VeilUnifiedImportRouter.resolve(record("page.html", kind: .html), at: url), .html)
        XCTAssertEqual(VeilUnifiedImportRouter.resolve(record("image.jpg", kind: .image), at: url), .image)
        guard case .preview = VeilUnifiedImportRouter.resolve(record("manual.pdf", kind: .pdf), at: url) else {
            return XCTFail("PDF should go to native preview")
        }
        guard case .retained = VeilUnifiedImportRouter.resolve(record("brain.npz", kind: .numpy), at: url) else {
            return XCTFail("Unvalidated NPZ must remain a file, not an executed model")
        }
    }
}
