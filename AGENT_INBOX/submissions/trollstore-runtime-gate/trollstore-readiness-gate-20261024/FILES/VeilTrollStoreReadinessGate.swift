import Foundation

/// An intentionally non-privileged gate for optional TrollStore-specific *candidate* features.
/// Neither package markers nor this decision grants entitlements, permissions or sandbox access.
/// A feature backend must independently enforce all OS permissions at every actual operation.
enum VeilEnhancedFeature: String, CaseIterable {
    case highMemoryLocalInference
    case backgroundLinkContinuity
    case expandedFileWorkspace
    case extendedLocalDiagnostics
}

enum VeilInstallationClass: Equatable {
    case ordinary
    case trollStore
    case trollStoreLite
    case simulator
    case unknown

    var isEnhancedCandidate: Bool {
        self == .trollStore || self == .trollStoreLite
    }
}

enum VeilRuntimeProbeStatus: Equatable {
    case verifiedAvailable
    case verifiedUnavailable
    case notChecked
}

/// App-owned probe evidence; never construct from a received message or untrusted preference.
struct VeilRuntimeProbeEvidence: Equatable {
    let status: VeilRuntimeProbeStatus
    let observedAt: TimeInterval
}

struct VeilEnhancedGateInput {
    let installation: VeilInstallationClass
    let capabilityDeclaredInSignedApp: Bool
    let probe: VeilRuntimeProbeEvidence?
    let explicitlyEnabledByUser: Bool
    let protectedDataAvailable: Bool
    let foregroundActive: Bool
    let thermalConstrained: Bool
    let lowPowerMode: Bool
    let legacyHardware: Bool
}

enum VeilEnhancedGateReason: String, Equatable {
    case permittedCandidate
    case ordinaryDistribution
    case disabledByUser
    case capabilityNotDeclared
    case probeUnavailable
    case probeUnverifiedOrExpired
    case protectedDataUnavailable
    case backgroundRestricted
    case deviceResourceGuard
}

struct VeilEnhancedGateDecision: Equatable {
    let enhancedAllowed: Bool
    let reason: VeilEnhancedGateReason

    /// The existing standard route is always used when optional enhancement is denied.
    var useStandardFallback: Bool { !enhancedAllowed }
}

enum VeilTrollStoreReadinessGate {
    static let maximumProbeAge: TimeInterval = 600

    static func evaluate(
        _ feature: VeilEnhancedFeature,
        input: VeilEnhancedGateInput,
        now: TimeInterval
    ) -> VeilEnhancedGateDecision {
        func denied(_ reason: VeilEnhancedGateReason) -> VeilEnhancedGateDecision {
            VeilEnhancedGateDecision(enhancedAllowed: false, reason: reason)
        }

        guard input.installation.isEnhancedCandidate else { return denied(.ordinaryDistribution) }
        guard input.explicitlyEnabledByUser else { return denied(.disabledByUser) }
        guard input.capabilityDeclaredInSignedApp else { return denied(.capabilityNotDeclared) }
        guard let probe = input.probe else { return denied(.probeUnverifiedOrExpired) }
        guard now.isFinite, probe.observedAt.isFinite,
              probe.observedAt <= now, now - probe.observedAt <= maximumProbeAge else {
            return denied(.probeUnverifiedOrExpired)
        }
        guard probe.status == .verifiedAvailable else {
            return denied(probe.status == .verifiedUnavailable ? .probeUnavailable : .probeUnverifiedOrExpired)
        }
        guard input.protectedDataAvailable else { return denied(.protectedDataUnavailable) }

        if feature != .backgroundLinkContinuity && !input.foregroundActive {
            return denied(.backgroundRestricted)
        }
        if feature == .highMemoryLocalInference &&
            (input.legacyHardware || input.thermalConstrained || input.lowPowerMode) {
            return denied(.deviceResourceGuard)
        }
        if feature == .backgroundLinkContinuity && input.thermalConstrained {
            return denied(.deviceResourceGuard)
        }

        return VeilEnhancedGateDecision(enhancedAllowed: true, reason: .permittedCandidate)
    }
}
