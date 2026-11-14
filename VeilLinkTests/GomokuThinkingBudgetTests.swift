import XCTest
@testable import VeilLink

final class GomokuThinkingBudgetTests: XCTestCase {
    func testNoTimeCutoffPreservesFiniteGuards() {
        for tier in BoardBotDifficulty.allCases {
            var budget = GomokuBotBudget.forDifficulty(tier, profileLabel: "HIGH")
            budget.searchStrength = 10
            budget.unlimitedThinking = true
            let limits = VeilGomokuUnifiedBridge.searchLimits(for: budget, difficultyRawValue: tier.rawValue)
            XCTAssertEqual(limits.maxMilliseconds, 0)
            XCTAssertGreaterThan(limits.maxNodes, 0)
            XCTAssertLessThanOrEqual(limits.maxNodes, 240_000)
            XCTAssertLessThanOrEqual(limits.maxDepth, 10)
        }
    }
    func testSliderChangesNativeNodesAndDepth() {
        var budget = GomokuBotBudget.forDifficulty(.zenith, profileLabel: "HIGH")
        budget.searchStrength = 1
        let low = VeilGomokuUnifiedBridge.searchLimits(for: budget, difficultyRawValue: "zenith")
        budget.searchStrength = 10
        let high = VeilGomokuUnifiedBridge.searchLimits(for: budget, difficultyRawValue: "zenith")
        XCTAssertGreaterThan(high.maxNodes, low.maxNodes)
        XCTAssertGreaterThan(high.maxDepth, low.maxDepth)
    }
    func testReinforcementKeepsUserSettings() {
        var budget = GomokuBotBudget.forDifficulty(.master, profileLabel: "HIGH")
        budget.searchStrength = 9
        budget.unlimitedThinking = true
        let reinforced = budget.reinforced(by: 8)
        XCTAssertEqual(reinforced.searchStrength, 9)
        XCTAssertTrue(reinforced.unlimitedThinking)
    }
    func testTimedModeStillUsesFiniteDeadline() {
        var budget = GomokuBotBudget.forDifficulty(.balanced, profileLabel: "HIGH")
        budget.unlimitedThinking = false
        XCTAssertGreaterThan(VeilGomokuUnifiedBridge.searchLimits(
            for: budget, difficultyRawValue: "balanced"
        ).maxMilliseconds, 0)
    }
}
