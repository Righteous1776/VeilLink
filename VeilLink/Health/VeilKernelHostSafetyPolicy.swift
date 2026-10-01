import Foundation

enum VeilKernelHostSafetyFallbackReason: String, Equatable, Sendable {
    case storageP0 = "HOST_STORAGE_P0_FALLBACK"
    case thermalCritical = "HOST_THERMAL_CRITICAL_FALLBACK"
}

/// Minimal host-owned safety floor for A10-only LAB.
/// This is not a second health chip. It only prevents an experiment from keeping a stale frozen
/// compute plan alive through a host-level P0 / critical OS condition.
enum VeilKernelHostSafetyPolicy {
    static func fallbackReason(for input: VeilA9Input) -> VeilKernelHostSafetyFallbackReason? {
        if input.databaseIntegrity == .failed { return .storageP0 }
        if input.thermalLevel == .critical { return .thermalCritical }
        return nil
    }
}
