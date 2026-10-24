import Foundation
import XCTest
@testable import VeilLink

final class VeilTrollStoreReadinessGateTests: XCTestCase {
    private let checkedAt: TimeInterval = 1_800_000_000

    private func input(
        source: VeilInstallationClass = .trollStore,
        declared: Bool = true,
        status: VeilRuntimeProbeStatus = .verifiedAvailable,
        probedAt: TimeInterval? = 1_800_000_000,
        enabled: Bool = true,
        protected: Bool = true,
        foreground: Bool = true,
        thermal: Bool = false,
        lowPower: Bool = false,
        legacy: Bool = false
    ) -> VeilEnhancedGateInput {
        VeilEnhancedGateInput(
            installation: source,
            capabilityDeclaredInSignedApp: declared,
            probe: probedAt.map { VeilRuntimeProbeEvidence(status: status, observedAt: $0) },
            explicitlyEnabledByUser: enabled,
            protectedDataAvailable: protected,
            foregroundActive: foreground,
            thermalConstrained: thermal,
            lowPowerMode: lowPower,
            legacyHardware: legacy
        )
    }

    func testOrdinaryInstallAlwaysUsesSafeStandardPath() {
        for source: VeilInstallationClass in [.ordinary, .simulator, .unknown] {
            let decision = VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(source: source), now: checkedAt)
            XCTAssertFalse(decision.enhancedAllowed)
            XCTAssertEqual(decision.reason, .ordinaryDistribution)
            XCTAssertTrue(decision.useStandardFallback)
        }
    }

    func testBothTrollStoreVariantsAreCandidatesNotAutomaticGrants() {
        for source: VeilInstallationClass in [.trollStore, .trollStoreLite] {
            XCTAssertTrue(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(source: source), now: checkedAt).enhancedAllowed)
            XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(source: source, declared: false), now: checkedAt).reason, .capabilityNotDeclared)
        }
    }

    func testExplicitUserOptInIsMandatory() {
        let decision = VeilTrollStoreReadinessGate.evaluate(.extendedLocalDiagnostics, input: input(enabled: false), now: checkedAt)
        XCTAssertEqual(decision.reason, .disabledByUser)
    }

    func testMissingOrFailedProbeAlwaysDeniesEnhancement() {
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(probedAt: nil), now: checkedAt).reason, .probeUnverifiedOrExpired)
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(status: .notChecked), now: checkedAt).reason, .probeUnverifiedOrExpired)
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(status: .verifiedUnavailable), now: checkedAt).reason, .probeUnavailable)
    }

    func testStaleAndFutureProbeEvidenceDenied() {
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(probedAt: checkedAt - 601), now: checkedAt).reason, .probeUnverifiedOrExpired)
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(probedAt: checkedAt + 10), now: checkedAt).reason, .probeUnverifiedOrExpired)
        XCTAssertTrue(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(probedAt: checkedAt - 600), now: checkedAt).enhancedAllowed)
    }

    func testLockedDeviceNeverGetsEnhancedPath() {
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.backgroundLinkContinuity, input: input(protected: false), now: checkedAt).reason, .protectedDataUnavailable)
    }

    func testForegroundRequirementsDifferByFeature() {
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(foreground: false), now: checkedAt).reason, .backgroundRestricted)
        XCTAssertTrue(VeilTrollStoreReadinessGate.evaluate(.backgroundLinkContinuity, input: input(foreground: false), now: checkedAt).enhancedAllowed)
    }

    func testLegacyDeviceDisablesHighMemoryInferenceOnly() {
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.highMemoryLocalInference, input: input(legacy: true), now: checkedAt).reason, .deviceResourceGuard)
        XCTAssertTrue(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(legacy: true), now: checkedAt).enhancedAllowed)
    }

    func testLowPowerAndThermalPressureFallBack() {
        for constrained in [input(lowPower: true), input(thermal: true)] {
            XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.highMemoryLocalInference, input: constrained, now: checkedAt).reason, .deviceResourceGuard)
        }
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.backgroundLinkContinuity, input: input(thermal: true), now: checkedAt).reason, .deviceResourceGuard)
    }

    func testNoEnhancementFromMissingOrNonFiniteTime() {
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(), now: .nan).reason, .probeUnverifiedOrExpired)
        XCTAssertEqual(VeilTrollStoreReadinessGate.evaluate(.expandedFileWorkspace, input: input(probedAt: .infinity), now: checkedAt).reason, .probeUnverifiedOrExpired)
    }
}
