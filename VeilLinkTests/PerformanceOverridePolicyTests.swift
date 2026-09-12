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
