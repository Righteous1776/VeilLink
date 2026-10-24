import Foundation

enum VeilParticleThermalLevel: Int, Comparable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum VeilParticleQuality: String, Equatable, Sendable {
    case off
    case efficient
    case balanced
    case cinematic
}

struct VeilParticlePerformanceInputs: Equatable {
    let isAppActive: Bool
    let usesLegacyCompositor: Bool
    let reduceMotionEnabled: Bool
    let lowPowerModeEnabled: Bool
    let thermalLevel: VeilParticleThermalLevel
    let visualComplexity: TransferVisualComplexity
    let forceFullVisualEffects: Bool
    let allowPersistentAnimations: Bool
}

struct VeilParticleBudget: Equatable, Sendable {
    let quality: VeilParticleQuality
    let ambientCount: Int
    let trailFragmentsPerSample: Int
    let burstCount: Int
    let maximumTrailSamples: Int
    let frameInterval: TimeInterval
    let usesGlow: Bool

    var isEnabled: Bool { quality != .off }
    var allowsAmbientMotion: Bool { ambientCount > 0 }

    static let off = VeilParticleBudget(
        quality: .off,
        ambientCount: 0,
        trailFragmentsPerSample: 0,
        burstCount: 0,
        maximumTrailSamples: 0,
        frameInterval: 1,
        usesGlow: false
    )
}

enum VeilParticlePerformancePolicy {
    static func resolve(_ input: VeilParticlePerformanceInputs) -> VeilParticleBudget {
        guard input.isAppActive else { return .off }

        // God Mode is deliberately authoritative for visual quality, including on legacy
        // devices and with Reduce Motion enabled. Persistent ambience still requires its
        // separate explicit switch so a transient-effects override cannot create an endless loop.
        if input.forceFullVisualEffects {
            return VeilParticleBudget(
                quality: .cinematic,
                ambientCount: input.allowPersistentAnimations ? 48 : 0,
                trailFragmentsPerSample: 5,
                burstCount: 84,
                maximumTrailSamples: 18,
                frameInterval: 1.0 / 60.0,
                usesGlow: true
            )
        }

        guard !input.usesLegacyCompositor,
              !input.reduceMotionEnabled,
              !input.lowPowerModeEnabled,
              input.thermalLevel < .serious,
              input.visualComplexity != .minimal else { return .off }

        if input.thermalLevel == .fair || input.visualComplexity == .balanced {
            return VeilParticleBudget(
                quality: .efficient,
                ambientCount: input.allowPersistentAnimations ? 8 : 0,
                trailFragmentsPerSample: 2,
                burstCount: 18,
                maximumTrailSamples: 8,
                frameInterval: 1.0 / 15.0,
                usesGlow: false
            )
        }

        return VeilParticleBudget(
            quality: .balanced,
            ambientCount: input.allowPersistentAnimations ? 22 : 0,
            trailFragmentsPerSample: 3,
            burstCount: 42,
            maximumTrailSamples: 12,
            frameInterval: 1.0 / 30.0,
            usesGlow: true
        )
    }
}

enum VeilParticleSeed {
    static func unit(_ seed: Int, lane: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed &+ lane &* 7_919))
        value ^= value >> 30
        value &*= 0xbf58_476d_1ce4_e5b9
        value ^= value >> 27
        value &*= 0x94d0_49bb_1331_11eb
        value ^= value >> 31
        return Double(value % 10_000) / 10_000
    }
}
