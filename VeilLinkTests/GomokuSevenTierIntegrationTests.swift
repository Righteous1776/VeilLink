import XCTest
@testable import VeilLink

/// Regression of V9 seven-tier budget plan atop the R14 native search.
final class GomokuSevenTierIntegrationTests: XCTestCase {
    func testGomokuSevenTiersAndXiangqiFourTiers() {
        XCTAssertEqual(BoardBotDifficulty.allCases.count, 7)
        XCTAssertEqual(BoardBotDifficulty.xiangqiCases, [.relaxed, .balanced, .advanced, .master])
        XCTAssertEqual([BoardBotDifficulty.grandmaster, .legendary, .zenith].map(\.searchBudgetMultiplier), [2, 4, 6])
    }

    func testTierComputeBudgetsAndNativeSearchLimits() {
        for profile in ["HIGH", "LEGACY-COMPACT"] {
            let master = GomokuBotBudget.forDifficulty(.master, profileLabel: profile)
            for difficulty in [BoardBotDifficulty.grandmaster, .legendary, .zenith] {
                let factor = difficulty.searchBudgetMultiplier
                let tier = GomokuBotBudget.forDifficulty(difficulty, profileLabel: profile)
                XCTAssertEqual(tier.timeLimitMilliseconds, master.timeLimitMilliseconds * factor)
                XCTAssertGreaterThanOrEqual(tier.reinforced(by: 8).timeLimitMilliseconds, tier.timeLimitMilliseconds)
                let limits = EclipseDifficultyPolicy.limits(rawValue: difficulty.rawValue, maximumMilliseconds: tier.timeLimitMilliseconds)
                XCTAssertEqual(limits.maxMilliseconds, min(950 * factor, tier.timeLimitMilliseconds))
                XCTAssertEqual(limits.maxNodes, 5_000 * factor)
                XCTAssertGreaterThanOrEqual(limits.maxDepth, 5)
                XCTAssertFalse(limits.r12HorizonQuiescence)
                XCTAssertFalse(limits.r13IncrementalThreatIndexEnabled)
            }
        }
    }

    func testXiangqiNeverGetsAnExtendedBudget() {
        let master = XiangqiBotBudget.forDifficulty(.master, profileLabel: "HIGH")
        for difficulty in [BoardBotDifficulty.grandmaster, .legendary, .zenith] {
            XCTAssertEqual(XiangqiBotBudget.forDifficulty(difficulty, profileLabel: "HIGH"), master)
        }
    }
}
