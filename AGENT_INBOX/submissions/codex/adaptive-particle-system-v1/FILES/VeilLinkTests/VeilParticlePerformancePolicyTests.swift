import XCTest
@testable import VeilLink

final class VeilParticlePerformancePolicyTests: XCTestCase {
    func testLegacyDeviceIsOffInAutomaticMode() {
        XCTAssertEqual(resolve(legacy: true).quality, .off)
    }

    func testReduceMotionIsOffInAutomaticMode() {
        XCTAssertEqual(resolve(reduceMotion: true).quality, .off)
    }

    func testLowPowerModeIsOffInAutomaticMode() {
        XCTAssertEqual(resolve(lowPower: true).quality, .off)
    }

    func testSeriousAndCriticalThermalStatesAreOff() {
        XCTAssertEqual(resolve(thermal: .serious).quality, .off)
        XCTAssertEqual(resolve(thermal: .critical).quality, .off)
    }

    func testFairThermalStateDowngradesToEfficient() {
        let budget = resolve(thermal: .fair)
        XCTAssertEqual(budget.quality, .efficient)
        XCTAssertEqual(budget.frameInterval, 1.0 / 15.0, accuracy: 0.0001)
        XCTAssertFalse(budget.usesGlow)
    }

    func testFullModernProfileUsesBoundedBalancedBudget() {
        let budget = resolve()
        XCTAssertEqual(budget.quality, .balanced)
        XCTAssertEqual(budget.ambientCount, 22)
        XCTAssertEqual(budget.burstCount, 42)
        XCTAssertLessThanOrEqual(budget.maximumTrailSamples * budget.trailFragmentsPerSample, 36)
    }

    func testGodModeForcesCinematicEffectsOnLegacyReducedCriticalDevice() {
        let budget = resolve(
            legacy: true,
            reduceMotion: true,
            lowPower: true,
            thermal: .critical,
            forceFull: true,
            persistent: true
        )
        XCTAssertEqual(budget.quality, .cinematic)
        XCTAssertEqual(budget.ambientCount, 48)
        XCTAssertEqual(budget.frameInterval, 1.0 / 60.0, accuracy: 0.0001)
    }

    func testGodTransientOverrideDoesNotImplicitlyEnablePersistentAmbient() {
        let budget = resolve(legacy: true, forceFull: true, persistent: false)
        XCTAssertEqual(budget.quality, .cinematic)
        XCTAssertEqual(budget.ambientCount, 0)
        XCTAssertGreaterThan(budget.burstCount, 0)
    }

    func testInactiveAppAlwaysDisablesRenderingIncludingGodMode() {
        XCTAssertEqual(resolve(active: false, forceFull: true, persistent: true), .off)
    }

    func testSeedIsDeterministicAndNormalized() {
        for lane in 0..<100 {
            let first = VeilParticleSeed.unit(42, lane: lane)
            XCTAssertEqual(first, VeilParticleSeed.unit(42, lane: lane))
            XCTAssertGreaterThanOrEqual(first, 0)
            XCTAssertLessThan(first, 1)
        }
    }

    private func resolve(
        active: Bool = true,
        legacy: Bool = false,
        reduceMotion: Bool = false,
        lowPower: Bool = false,
        thermal: VeilParticleThermalLevel = .nominal,
        complexity: TransferVisualComplexity = .full,
        forceFull: Bool = false,
        persistent: Bool = true
    ) -> VeilParticleBudget {
        VeilParticlePerformancePolicy.resolve(.init(
            isAppActive: active,
            usesLegacyCompositor: legacy,
            reduceMotionEnabled: reduceMotion,
            lowPowerModeEnabled: lowPower,
            thermalLevel: thermal,
            visualComplexity: complexity,
            forceFullVisualEffects: forceFull,
            allowPersistentAnimations: persistent
        ))
    }
}
