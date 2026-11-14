import XCTest
@testable import VeilLink

final class GomokuSevenTierIntegrationTests: XCTestCase {
    func testGomokuSevenAndXiangqiFour() {
        XCTAssertEqual(BoardBotDifficulty.allCases.count, 7)
        XCTAssertEqual(BoardBotDifficulty.xiangqiCases.count, 4)
        XCTAssertEqual(BoardBotDifficulty.zenith.rawValue, "zenith")
    }

    func testTwoFourSixBudgetMultipliers() {
        for profile in ["HIGH", "LEGACY-COMPACT"] {
            let master = GomokuBotBudget.forDifficulty(.master, profileLabel: profile)
            for (difficulty, multiple) in [
                (BoardBotDifficulty.grandmaster, 2),
                (.legendary, 4),
                (.zenith, 6)
            ] {
                let budget = GomokuBotBudget.forDifficulty(difficulty, profileLabel: profile)
                XCTAssertEqual(budget.timeLimitMilliseconds, master.timeLimitMilliseconds * multiple)
                XCTAssertGreaterThanOrEqual(budget.reinforced(by: 8).timeLimitMilliseconds, budget.timeLimitMilliseconds)
            }
        }
    }

    func testNativeSearchBudgetsScaleAndRetainLimits() {
        let one = EclipseDifficultyPolicy.limits(rawValue: "master", maximumMilliseconds: 10_000)
        for (tier, multiple) in [("grandmaster", 2), ("legendary", 4), ("zenith", 6)] {
            let limits = EclipseDifficultyPolicy.limits(rawValue: tier, maximumMilliseconds: 10_000)
            XCTAssertEqual(limits.maxMilliseconds, one.maxMilliseconds * multiple)
            XCTAssertGreaterThan(limits.maxNodes, one.maxNodes)
            XCTAssertGreaterThan(limits.maxDepth, one.maxDepth)
        }
    }
}
