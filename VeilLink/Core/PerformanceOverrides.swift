import Foundation

struct PerformanceOverrideSnapshot: Equatable, Sendable {
    var isEnabled: Bool
    var highDefinitionPreview: Bool
    var expandedAttachmentCache: Bool
    var disableRefreshCoalescing: Bool
    var forceFullVisualEffects: Bool
    var allowPersistentAnimations: Bool

    static let automatic = PerformanceOverrideSnapshot(
        isEnabled: false,
        highDefinitionPreview: false,
        expandedAttachmentCache: false,
        disableRefreshCoalescing: false,
        forceFullVisualEffects: false,
        allowPersistentAnimations: false
    )

    var activeRiskCount: Int {
        guard isEnabled else { return 0 }
        return [
            highDefinitionPreview,
            expandedAttachmentCache,
            disableRefreshCoalescing,
            forceFullVisualEffects,
            allowPersistentAnimations
        ].filter { $0 }.count
    }
}

final class PerformanceOverrideStore: @unchecked Sendable {
    static let shared = PerformanceOverrideStore()

    private enum Key {
        static let enabled = "developer.performanceOverride.enabled"
        static let highDefinitionPreview = "developer.performanceOverride.highDefinitionPreview"
        static let expandedAttachmentCache = "developer.performanceOverride.expandedAttachmentCache"
        static let disableRefreshCoalescing = "developer.performanceOverride.disableRefreshCoalescing"
        static let forceFullVisualEffects = "developer.performanceOverride.forceFullVisualEffects"
        static let allowPersistentAnimations = "developer.performanceOverride.allowPersistentAnimations"
    }

    private let lock = NSLock()
    private let defaults: UserDefaults
    private var value: PerformanceOverrideSnapshot

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        value = PerformanceOverrideSnapshot(
            isEnabled: defaults.bool(forKey: Key.enabled),
            highDefinitionPreview: defaults.bool(forKey: Key.highDefinitionPreview),
            expandedAttachmentCache: defaults.bool(forKey: Key.expandedAttachmentCache),
            disableRefreshCoalescing: defaults.bool(forKey: Key.disableRefreshCoalescing),
            forceFullVisualEffects: defaults.bool(forKey: Key.forceFullVisualEffects),
            allowPersistentAnimations: defaults.bool(forKey: Key.allowPersistentAnimations)
        )
    }

    func snapshot() -> PerformanceOverrideSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func update(_ snapshot: PerformanceOverrideSnapshot) {
        lock.lock()
        value = snapshot
        lock.unlock()

        defaults.set(snapshot.isEnabled, forKey: Key.enabled)
        defaults.set(snapshot.highDefinitionPreview, forKey: Key.highDefinitionPreview)
        defaults.set(snapshot.expandedAttachmentCache, forKey: Key.expandedAttachmentCache)
        defaults.set(snapshot.disableRefreshCoalescing, forKey: Key.disableRefreshCoalescing)
        defaults.set(snapshot.forceFullVisualEffects, forKey: Key.forceFullVisualEffects)
        defaults.set(snapshot.allowPersistentAnimations, forKey: Key.allowPersistentAnimations)
    }
}

enum PerformanceOverridePolicy {
    static func effectiveProfile(
        base: DevicePerformanceProfile,
        snapshot: PerformanceOverrideSnapshot
    ) -> DevicePerformanceProfile {
        guard snapshot.isEnabled else { return base }

        return DevicePerformanceProfile(
            label: snapshot.activeRiskCount == 0 ? base.label : "\(base.label)+GOD\(snapshot.activeRiskCount)",
            messageWindowInitial: base.messageWindowInitial,
            messageWindowIncrement: base.messageWindowIncrement,
            messageWindowMaximum: base.messageWindowMaximum,
            decryptedBodyCacheEntries: base.decryptedBodyCacheEntries,
            imagePreviewMaxPixelSize: snapshot.highDefinitionPreview ? max(base.imagePreviewMaxPixelSize, 2_048) : base.imagePreviewMaxPixelSize,
            imagePreviewCacheCount: base.imagePreviewCacheCount,
            imagePreviewCacheBytes: base.imagePreviewCacheBytes,
            outboundAttachmentCacheBytes: snapshot.expandedAttachmentCache ? max(base.outboundAttachmentCacheBytes, 16 * 1_024 * 1_024) : base.outboundAttachmentCacheBytes,
            bleQueuePacketLimit: base.bleQueuePacketLimit,
            bleQueueByteLimit: base.bleQueueByteLimit,
            bleReassemblyMessageLimit: base.bleReassemblyMessageLimit,
            bleReassemblyPerSourceLimit: base.bleReassemblyPerSourceLimit,
            bleReassemblyByteLimit: base.bleReassemblyByteLimit,
            messageRefreshDebounceNanoseconds: snapshot.disableRefreshCoalescing ? 0 : base.messageRefreshDebounceNanoseconds,
            transferVisualComplexity: snapshot.forceFullVisualEffects ? .full : base.transferVisualComplexity,
            shouldPrecomputeTransferShards: snapshot.forceFullVisualEffects ? true : base.shouldPrecomputeTransferShards,
            aggressiveBackgroundCacheTrim: base.aggressiveBackgroundCacheTrim
        )
    }
}

enum VeilPerformanceOverrides {
    static var snapshot: PerformanceOverrideSnapshot { PerformanceOverrideStore.shared.snapshot() }

    static var forceFullVisualEffects: Bool {
        let value = snapshot
        return value.isEnabled && value.forceFullVisualEffects
    }

    static var allowPersistentAnimations: Bool {
        let value = snapshot
        return value.isEnabled && value.allowPersistentAnimations
    }
}
