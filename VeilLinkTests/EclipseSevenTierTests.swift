import XCTest
@testable import VeilLink

final class EclipseSevenTierTests: XCTestCase {
    func testGomokuSevenXiangqiFour() {
        XCTAssertEqual(BoardBotDifficulty.allCases.count, 7)
        XCTAssertEqual(BoardBotDifficulty.xiangqiCases.count, 4)
        XCTAssertEqual(BoardBotDifficulty(rawValue: "master"), .master)
        XCTAssertEqual(BoardBotDifficulty(rawValue: "grandmaster"), .grandmaster)
        XCTAssertEqual(BoardBotDifficulty(rawValue: "legendary"), .legendary)
        XCTAssertEqual(BoardBotDifficulty(rawValue: "zenith"), .zenith)
    }

    func testSearchBudgetsAndLearningPreserveSelectedTier() {
        for profile in ["HIGH", "LEGACY-COMPACT"] {
            let master = GomokuBotBudget.forDifficulty(.master, profileLabel: profile)
            for (tier, multiplier) in [
                (BoardBotDifficulty.grandmaster, 2),
                (.legendary, 4),
                (.zenith, 6)
            ] {
                let budget = GomokuBotBudget.forDifficulty(tier, profileLabel: profile)
                XCTAssertEqual(budget.timeLimitMilliseconds, master.timeLimitMilliseconds * multiplier)
                XCTAssertEqual(budget.reinforced(by: 8, preserveSearchBudget: true).timeLimitMilliseconds,
                               budget.timeLimitMilliseconds)
                let limits = EclipseDifficultyPolicy.limits(
                    rawValue: tier.rawValue, maximumMilliseconds: budget.timeLimitMilliseconds)
                XCTAssertGreaterThan(limits.maxNodes, 5_000)
                XCTAssertLessThanOrEqual(limits.maxMilliseconds, budget.timeLimitMilliseconds)
            }
        }
    }

    func testXiangqiSafetyFallback() {
        XCTAssertEqual(
            XiangqiBotBudget.forDifficulty(.zenith, profileLabel: "HIGH").maxDepth,
            XiangqiBotBudget.forDifficulty(.master, profileLabel: "HIGH").maxDepth)
    }
}
