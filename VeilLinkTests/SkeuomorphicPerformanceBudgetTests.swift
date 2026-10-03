import XCTest
@testable import VeilLink

final class SkeuomorphicPerformanceBudgetTests: XCTestCase {
    func testLegacyBalancedToolPanelUsesEfficientBudget() {
        let budget = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .balanced,
            usesLegacyCompositor: true,
            runtimeConstrained: false,
            reduceMotionEnabled: false,
            forceFullVisualEffects: false,
            persistentMotionAllowed: false,
            role: .toolPanel
        )

        XCTAssertEqual(budget.tier, .efficient)
        XCTAssertEqual(budget.outerShadowLayers, 1)
        XCTAssertEqual(budget.maxShadowRadius, 4, accuracy: 0.001)
        XCTAssertFalse(budget.allowsBackdropMaterial)
        XCTAssertTrue(budget.allows3DTilt)
        XCTAssertEqual(budget.maxTiltDegrees, 2.2, accuracy: 0.001)
        XCTAssertEqual(budget.maxContinuousDecorativeAnimations, 0)
    }

    func testMinimalVisualComplexityUsesEssentialBudget() {
        let budget = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .minimal,
            usesLegacyCompositor: false,
            runtimeConstrained: false,
            reduceMotionEnabled: false,
            forceFullVisualEffects: false,
            persistentMotionAllowed: true,
            role: .toolPanel
        )

        XCTAssertEqual(budget.tier, .essential)
        XCTAssertEqual(budget.outerShadowLayers, 0)
        XCTAssertFalse(budget.allowsSpecularGradient)
        XCTAssertFalse(budget.allows3DTilt)
        XCTAssertEqual(budget.maxContinuousDecorativeAnimations, 0)
        XCTAssertEqual(budget.gaugeSegmentLimit, 6)
    }

    func testModernFullToolPanelGetsFullStaticAndMotionBudget() {
        let budget = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .full,
            usesLegacyCompositor: false,
            runtimeConstrained: false,
            reduceMotionEnabled: false,
            forceFullVisualEffects: false,
            persistentMotionAllowed: true,
            role: .toolPanel
        )

        XCTAssertEqual(budget.tier, .full)
        XCTAssertEqual(budget.outerShadowLayers, 2)
        XCTAssertEqual(budget.maxShadowRadius, 12, accuracy: 0.001)
        XCTAssertTrue(budget.allowsBackdropMaterial)
        XCTAssertTrue(budget.allowsAnimatedGlow)
        XCTAssertTrue(budget.allows3DTilt)
        XCTAssertEqual(budget.maxTiltDegrees, 6, accuracy: 0.001)
        XCTAssertEqual(budget.maxContinuousDecorativeAnimations, 2)
        XCTAssertEqual(budget.gaugeSegmentLimit, 16)
        XCTAssertEqual(budget.grilleDensityScale, 1, accuracy: 0.001)
    }

    func testRuntimeConstraintForcesEssentialUnlessExplicitlyOverridden() {
        let automatic = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .full,
            usesLegacyCompositor: false,
            runtimeConstrained: true,
            reduceMotionEnabled: false,
            forceFullVisualEffects: false,
            persistentMotionAllowed: false,
            role: .toolPanel
        )
        XCTAssertEqual(automatic.tier, .essential)

        let forced = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .full,
            usesLegacyCompositor: true,
            runtimeConstrained: true,
            reduceMotionEnabled: true,
            forceFullVisualEffects: true,
            persistentMotionAllowed: false,
            role: .toolPanel
        )
        XCTAssertEqual(forced.tier, .full)
        XCTAssertTrue(forced.allows3DTilt)
        XCTAssertFalse(forced.allowsAnimatedGlow)
        XCTAssertEqual(forced.maxContinuousDecorativeAnimations, 0)
    }

    func testReduceMotionKeepsStaticDepthButRemovesMotion() {
        let budget = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .full,
            usesLegacyCompositor: false,
            runtimeConstrained: false,
            reduceMotionEnabled: true,
            forceFullVisualEffects: false,
            persistentMotionAllowed: true,
            role: .toolPanel
        )

        XCTAssertEqual(budget.tier, .full)
        XCTAssertEqual(budget.outerShadowLayers, 2)
        XCTAssertTrue(budget.allowsBackdropMaterial)
        XCTAssertFalse(budget.allows3DTilt)
        XCTAssertEqual(budget.maxTiltDegrees, 0, accuracy: 0.001)
        XCTAssertFalse(budget.allowsAnimatedGlow)
        XCTAssertEqual(budget.maxContinuousDecorativeAnimations, 0)
    }

    func testDenseScrollCapsFullBudget() {
        let budget = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .full,
            usesLegacyCompositor: false,
            runtimeConstrained: false,
            reduceMotionEnabled: false,
            forceFullVisualEffects: false,
            persistentMotionAllowed: true,
            role: .denseScroll
        )

        XCTAssertEqual(budget.tier, .full)
        XCTAssertEqual(budget.outerShadowLayers, 1)
        XCTAssertEqual(budget.maxShadowRadius, 4, accuracy: 0.001)
        XCTAssertFalse(budget.allowsBackdropMaterial)
        XCTAssertFalse(budget.allowsAnimatedGlow)
        XCTAssertEqual(budget.maxTiltDegrees, 2.2, accuracy: 0.001)
        XCTAssertEqual(budget.maxContinuousDecorativeAnimations, 0)
        XCTAssertEqual(budget.gaugeSegmentLimit, 10)
        XCTAssertEqual(budget.grilleDensityScale, 0.80, accuracy: 0.001)
    }

    func testArcadeConsoleCapsContinuousAnimationAndTilt() {
        let budget = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .full,
            usesLegacyCompositor: false,
            runtimeConstrained: false,
            reduceMotionEnabled: false,
            forceFullVisualEffects: false,
            persistentMotionAllowed: true,
            role: .arcadeConsole
        )

        XCTAssertEqual(budget.maxShadowRadius, 8, accuracy: 0.001)
        XCTAssertEqual(budget.maxTiltDegrees, 4, accuracy: 0.001)
        XCTAssertEqual(budget.maxContinuousDecorativeAnimations, 1)
        XCTAssertEqual(budget.gaugeSegmentLimit, 14)
    }

    func testTacticalMapAlwaysCapsExpensiveDecorativeMotion() {
        let budget = VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: .full,
            usesLegacyCompositor: false,
            runtimeConstrained: false,
            reduceMotionEnabled: false,
            forceFullVisualEffects: false,
            persistentMotionAllowed: true,
            role: .tacticalMap
        )

        XCTAssertEqual(budget.outerShadowLayers, 1)
        XCTAssertEqual(budget.maxShadowRadius, 4, accuracy: 0.001)
        XCTAssertFalse(budget.allowsBackdropMaterial)
        XCTAssertFalse(budget.allowsAnimatedGlow)
        XCTAssertFalse(budget.allows3DTilt)
        XCTAssertEqual(budget.maxContinuousDecorativeAnimations, 0)
        XCTAssertEqual(budget.gaugeSegmentLimit, 8)
        XCTAssertEqual(budget.grilleDensityScale, 0.75, accuracy: 0.001)
    }
}
