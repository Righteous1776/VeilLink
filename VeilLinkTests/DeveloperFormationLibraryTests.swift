import XCTest
@testable import VeilLink

@MainActor
final class DeveloperFormationLibraryTests: XCTestCase {
    private func makeLibrary() -> (DeveloperFormationLibrary, URL, KeychainStore) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilLinkFormationTests-\(UUID().uuidString)", isDirectory: true)
        let file = root.appendingPathComponent("gomoku-v1.json")
        let keychain = KeychainStore(service: "studio.zeo.veillink.tests.formations.\(UUID().uuidString)")
        return (DeveloperFormationLibrary(game: .gomoku, keychain: keychain, fileURL: file), file, keychain)
    }

    func testRecordedFormationInfluencesMatchingPrefixAndSurvivesReload() throws {
        let (library, file, keychain) = makeLibrary()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let line = [
            AdaptiveBoardPly(position: "g:initial", action: "112", actor: .host),
            AdaptiveBoardPly(position: "g:after-112", action: "113", actor: .guest),
            AdaptiveBoardPly(position: "g:after-113", action: "97", actor: .host)
        ]
        try library.capture(
            name: "中心反制",
            purpose: "以相邻点回应中心落子，限制对方扩张。",
            objective: "诱导对方回到已验证的防守线路。",
            plies: line
        )

        let influence = library.influence(for: [line[0]])
        XCTAssertEqual(influence.rootAdjustments["113"], 1_400)
        XCTAssertEqual(influence.predictedHumanReplies["113"], .init(action: "97", evidence: 99))
        XCTAssertEqual(influence.matchedLessonNames, ["中心反制"])

        let reloaded = DeveloperFormationLibrary(game: .gomoku, keychain: keychain, fileURL: file)
        XCTAssertEqual(reloaded.lessons.count, 1)
        XCTAssertEqual(reloaded.influence(for: [line[0]]).rootAdjustments["113"], 1_400)
    }

    func testLessonRequiresBothSidesAndMeaningfulExplanation() {
        let (library, file, _) = makeLibrary()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        XCTAssertThrowsError(try library.capture(
            name: "x",
            purpose: "短",
            objective: "短",
            plies: [AdaptiveBoardPly(position: "g:initial", action: "112", actor: .host)]
        )) { error in
            guard let formationError = error as? DeveloperFormationError,
                  case .invalidLesson = formationError else {
                return XCTFail("expected invalid lesson, got \(error)")
            }
        }
    }
}
