import XCTest
@testable import VeilLink

final class VeilEmotionGardenEngineTests: XCTestCase {
    func testRuntimeContainsOneThousandUniqueLocalRituals() {
        XCTAssertEqual(VeilEmotionGardenEngine.rituals.count, 1_000)
        XCTAssertEqual(Set(VeilEmotionGardenEngine.rituals.map(\.id)).count, 1_000)
        XCTAssertEqual(Set(VeilEmotionGardenEngine.rituals.map(\.prompt)).count, 1_000)
        XCTAssertEqual(Set(VeilEmotionGardenEngine.rituals.map { $0.steps.joined(separator: "|") }).count, 1_000)
        XCTAssertEqual(Set(VeilEmotionGardenEngine.rituals.map(\.completionNote)).count, 1_000)
        XCTAssertTrue(VeilEmotionGardenEngine.rituals.allSatisfy { $0.seconds > 0 && !$0.prompt.isEmpty && $0.steps.count == 3 })
        XCTAssertEqual(VeilEmotionGardenEngine.rituals.first?.id, "EV-0001")
        XCTAssertEqual(VeilEmotionGardenEngine.rituals.last?.id, "EV-1000")
        XCTAssertEqual(VeilEmotionGardenEngine.ritual(id: "EV-1000")?.tone, .playful)
    }

    func testEachToneHasOneHundredRitualsAndEveryContextIsReachable() {
        for tone in VeilEmotionTone.allCases {
            let rituals = VeilEmotionGardenEngine.rituals(for: tone)
            XCTAssertEqual(rituals.count, 100)
            XCTAssertEqual(Set(rituals.map(\.kind)).count, 10)
            XCTAssertEqual(Set(rituals.map(\.context)).count, 10)
            XCTAssertTrue(rituals.allSatisfy { $0.tone == tone })
            for context in VeilEmotionContext.allCases {
                let reachable = VeilEmotionGardenEngine.rituals(for: tone, context: context)
                XCTAssertEqual(reachable.count, 10)
                XCTAssertEqual(Set(reachable.map(\.kind)).count, 10)
            }
        }
    }

    func testDailyPathIsDeterministicAndBounded() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_704_067_200)
        let first = VeilEmotionGardenEngine.dailyPath(for: .uncertain, context: .night, date: day, calendar: utc)
        let second = VeilEmotionGardenEngine.dailyPath(for: .uncertain, context: .night, date: day, calendar: utc)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 3)
        XCTAssertTrue(first.allSatisfy { $0.tone == .uncertain })
        XCTAssertTrue(first.allSatisfy { $0.context == .night })
        XCTAssertEqual(Set(first.map(\.id)).count, 3)
    }

    func testSupportiveNotesArePresentAndDoNotClaimTreatment() {
        for tone in VeilEmotionTone.allCases {
            let note = VeilEmotionGardenEngine.supportiveNote(for: tone)
            XCTAssertFalse(note.isEmpty)
            XCTAssertFalse(note.localizedCaseInsensitiveContains("治疗"))
            XCTAssertFalse(note.localizedCaseInsensitiveContains("诊断"))
        }
    }

    func testBreathingPromptHasClearPacingAndShortDuration() {
        let ritual = VeilEmotionGardenEngine.rituals.first { $0.tone == .tense && $0.kind == .breath && $0.context == .morning }
        XCTAssertEqual(ritual?.seconds, 60)
        XCTAssertTrue(ritual?.prompt.contains("吸气") == true)
        XCTAssertTrue(ritual?.prompt.contains("呼气") == true)
    }
}
