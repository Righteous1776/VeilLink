import Combine
import Foundation

@MainActor
final class PerformanceOverrideController: ObservableObject {
    @Published var isEnabled: Bool { didSet { persistIfNeeded() } }
    @Published var highDefinitionPreview: Bool { didSet { persistIfNeeded() } }
    @Published var expandedAttachmentCache: Bool { didSet { persistIfNeeded() } }
    @Published var disableRefreshCoalescing: Bool { didSet { persistIfNeeded() } }
    @Published var forceFullVisualEffects: Bool { didSet { persistIfNeeded() } }
    @Published var allowPersistentAnimations: Bool { didSet { persistIfNeeded() } }

    var onChange: (() -> Void)?
    private var isApplyingBatch = false
    private let store: PerformanceOverrideStore

    init(store: PerformanceOverrideStore = .shared) {
        self.store = store
        let snapshot = store.snapshot()
        isEnabled = snapshot.isEnabled
        highDefinitionPreview = snapshot.highDefinitionPreview
        expandedAttachmentCache = snapshot.expandedAttachmentCache
        disableRefreshCoalescing = snapshot.disableRefreshCoalescing
        forceFullVisualEffects = snapshot.forceFullVisualEffects
        allowPersistentAnimations = snapshot.allowPersistentAnimations
    }

    var snapshot: PerformanceOverrideSnapshot {
        PerformanceOverrideSnapshot(
            isEnabled: isEnabled,
            highDefinitionPreview: highDefinitionPreview,
            expandedAttachmentCache: expandedAttachmentCache,
            disableRefreshCoalescing: disableRefreshCoalescing,
            forceFullVisualEffects: forceFullVisualEffects,
            allowPersistentAnimations: allowPersistentAnimations
        )
    }

    var riskCount: Int { snapshot.activeRiskCount }

    var riskLabel: String {
        switch riskCount {
        case 0: return "理性尚存"
        case 1: return "轻微亵渎"
        case 2: return "开始藐视设备建议"
        case 3: return "热力学正在旁观"
        case 4: return "散热系统已提出异议"
        default: return "物理定律已提交工单"
        }
    }

    func enableChaosPreset() {
        applyBatch(
            PerformanceOverrideSnapshot(
                isEnabled: true,
                highDefinitionPreview: true,
                expandedAttachmentCache: true,
                disableRefreshCoalescing: true,
                forceFullVisualEffects: true,
                allowPersistentAnimations: true
            )
        )
    }

    func restoreAutomaticPolicy() {
        applyBatch(.automatic)
    }

    private func applyBatch(_ value: PerformanceOverrideSnapshot) {
        isApplyingBatch = true
        isEnabled = value.isEnabled
        highDefinitionPreview = value.highDefinitionPreview
        expandedAttachmentCache = value.expandedAttachmentCache
        disableRefreshCoalescing = value.disableRefreshCoalescing
        forceFullVisualEffects = value.forceFullVisualEffects
        allowPersistentAnimations = value.allowPersistentAnimations
        isApplyingBatch = false
        persist()
    }

    private func persistIfNeeded() {
        guard !isApplyingBatch else { return }
        persist()
    }

    private func persist() {
        store.update(snapshot)
        onChange?()
    }
}
