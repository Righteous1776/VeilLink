import XCTest
@testable import VeilLink

final class VeilEmotionGardenEngineTests: XCTestCase {
    func testInitialRitualSetHasOneHundredUniqueLocalRituals() {
        XCTAssertEqual(VeilEmotionGardenEngine.rituals.count, 100)
        XCTAssertEqual(Set(VeilEmotionGardenEngine.rituals.map(\.id)).count, 100)
        XCTAssertTrue(VeilEmotionGardenEngine.rituals.allSatisfy { $0.seconds > 0 && !$0.prompt.isEmpty })
    }

    func testEachToneHasTenDistinctRitualForms() {
        for tone in VeilEmotionTone.allCases {
            let rituals = VeilEmotionGardenEngine.rituals(for: tone)
            XCTAssertEqual(rituals.count, 10)
            XCTAssertEqual(Set(rituals.map(\.kind)).count, 10)
            XCTAssertTrue(rituals.allSatisfy { $0.tone == tone })
        }
    }

    func testDailyPathIsDeterministicAndBounded() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_704_067_200)
        let first = VeilEmotionGardenEngine.dailyPath(for: .uncertain, date: day, calendar: utc)
        let second = VeilEmotionGardenEngine.dailyPath(for: .uncertain, date: day, calendar: utc)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 3)
        XCTAssertTrue(first.allSatisfy { $0.tone == .uncertain })
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
        let ritual = VeilEmotionGardenEngine.rituals.first { $0.tone == .tense && $0.kind == .breath }
        XCTAssertEqual(ritual?.seconds, 60)
        XCTAssertTrue(ritual?.prompt.contains("吸气") == true)
        XCTAssertTrue(ritual?.prompt.contains("呼气") == true)
    }
}
