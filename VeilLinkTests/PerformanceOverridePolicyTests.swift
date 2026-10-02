import XCTest
@testable import VeilLink

final class PerformanceOverridePolicyTests: XCTestCase {
    func testDisabledOverrideReturnsBaseProfileUnchanged() {
        let base = DevicePerformancePolicy.profile(machineIdentifier: "iPhone8,4", osMajorVersion: 15)
        let effective = PerformanceOverridePolicy.effectiveProfile(base: base, snapshot: .automatic)
        XCTAssertEqual(effective, base)
    }

    func testGodModeCanLiftOnlyRequestedPerformanceGuards() {
        let base = DevicePerformancePolicy.profile(machineIdentifier: "iPhone9,1", osMajorVersion: 15)
        let snapshot = PerformanceOverrideSnapshot(
            isEnabled: true,
            highDefinitionPreview: true,
            expandedAttachmentCache: true,
            disableRefreshCoalescing: true,
            forceFullVisualEffects: true,
            allowPersistentAnimations: false
        )
        let effective = PerformanceOverridePolicy.effectiveProfile(base: base, snapshot: snapshot)

        XCTAssertEqual(effective.imagePreviewMaxPixelSize, 2_048)
        XCTAssertEqual(effective.outboundAttachmentCacheBytes, 16 * 1_024 * 1_024)
        XCTAssertEqual(effective.messageRefreshDebounceNanoseconds, 0)
        XCTAssertEqual(effective.transferVisualComplexity, .full)
        XCTAssertTrue(effective.shouldPrecomputeTransferShards)
        XCTAssertEqual(effective.bleQueueByteLimit, base.bleQueueByteLimit)
        XCTAssertEqual(effective.messageWindowInitial, base.messageWindowInitial)
    }

    func testPersistentAnimationPermissionDoesNotAlterTransportBudgets() {
        let base = DevicePerformancePolicy.profile(machineIdentifier: "iPhone8,4", osMajorVersion: 15)
        let snapshot = PerformanceOverrideSnapshot(
            isEnabled: true,
            highDefinitionPreview: false,
            expandedAttachmentCache: false,
            disableRefreshCoalescing: false,
            forceFullVisualEffects: false,
            allowPersistentAnimations: true
        )
        let effective = PerformanceOverridePolicy.effectiveProfile(base: base, snapshot: snapshot)
        XCTAssertEqual(effective.bleQueuePacketLimit, base.bleQueuePacketLimit)
        XCTAssertEqual(effective.bleReassemblyByteLimit, base.bleReassemblyByteLimit)
        XCTAssertEqual(effective.outboundAttachmentCacheBytes, base.outboundAttachmentCacheBytes)
    }

    func testCompactDevicesKeepEfficientTransientMotion() {
        let quality = PerformanceOverridePolicy.transientMotionQuality(
            reduceMotionEnabled: false,
            visualComplexity: .minimal,
            snapshot: .automatic
        )
        XCTAssertEqual(quality, .efficient)
    }

    func testReduceMotionWinsDuringAutomaticPolicy() {
        let quality = PerformanceOverridePolicy.transientMotionQuality(
            reduceMotionEnabled: true,
            visualComplexity: .full,
            snapshot: .automatic
        )
        XCTAssertEqual(quality, .reduced)
    }

    func testGodModeCanForceHighQualityMotionAcrossAllGuards() {
        let snapshot = PerformanceOverrideSnapshot(
            isEnabled: true,
            highDefinitionPreview: false,
            expandedAttachmentCache: false,
            disableRefreshCoalescing: false,
            forceFullVisualEffects: true,
            allowPersistentAnimations: false
        )
        let quality = PerformanceOverridePolicy.transientMotionQuality(
            reduceMotionEnabled: true,
            visualComplexity: .minimal,
            snapshot: snapshot
        )
        XCTAssertEqual(quality, .high)
    }

    func testPersistentMotionRequiresItsOwnGodModePermission() {
        let fullVisualsOnly = PerformanceOverrideSnapshot(
            isEnabled: true,
            highDefinitionPreview: false,
            expandedAttachmentCache: false,
            disableRefreshCoalescing: false,
            forceFullVisualEffects: true,
            allowPersistentAnimations: false
        )
        XCTAssertFalse(PerformanceOverridePolicy.allowsPersistentMotion(
            baseAllows: true,
            usesLegacyCompositor: false,
            runtimeConstrained: false,
            snapshot: fullVisualsOnly
        ))

        let fullyArmed = PerformanceOverrideSnapshot(
            isEnabled: true,
            highDefinitionPreview: false,
            expandedAttachmentCache: false,
            disableRefreshCoalescing: false,
            forceFullVisualEffects: true,
            allowPersistentAnimations: true
        )
        XCTAssertTrue(PerformanceOverridePolicy.allowsPersistentMotion(
            baseAllows: false,
            usesLegacyCompositor: true,
            runtimeConstrained: true,
            snapshot: fullyArmed
        ))
    }

    @MainActor
    func testChaosPresetAndRestoreAutomaticPolicy() {
        let suite = "PerformanceOverridePolicyTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Unable to create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PerformanceOverrideStore(defaults: defaults)
        let controller = PerformanceOverrideController(store: store)

        controller.enableChaosPreset()
        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(controller.riskCount, 5)
        XCTAssertTrue(store.snapshot().allowPersistentAnimations)

        controller.restoreAutomaticPolicy()
        XCTAssertEqual(controller.snapshot, .automatic)
        XCTAssertEqual(store.snapshot(), .automatic)
    }
}
