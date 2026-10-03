import Foundation

enum VeilSkeuomorphicSurfaceRole: String, CaseIterable, Equatable, Sendable {
    case denseScroll
    case toolPanel
    case arcadeConsole
    case tacticalMap
}

enum VeilSkeuomorphicVisualTier: String, Equatable, Sendable {
    case essential
    case efficient
    case full
}

struct VeilSkeuomorphicRenderBudget: Equatable, Sendable {
    let tier: VeilSkeuomorphicVisualTier
    let outerShadowLayers: Int
    let maxShadowRadius: Double
    let maxDecorativeOverlayLayers: Int
    let allowsInnerHighlight: Bool
    let allowsSpecularGradient: Bool
    let allowsBackdropMaterial: Bool
    let allowsAnimatedGlow: Bool
    let allows3DTilt: Bool
    let maxTiltDegrees: Double
    let maxContinuousDecorativeAnimations: Int
    let gaugeSegmentLimit: Int
    let grilleDensityScale: Double
}

enum VeilSkeuomorphicPerformancePolicy {
    static func budget(
        visualComplexity: TransferVisualComplexity,
        usesLegacyCompositor: Bool,
        runtimeConstrained: Bool,
        reduceMotionEnabled: Bool,
        forceFullVisualEffects: Bool,
        persistentMotionAllowed: Bool,
        role: VeilSkeuomorphicSurfaceRole
    ) -> VeilSkeuomorphicRenderBudget {
        let tier: VeilSkeuomorphicVisualTier
        if forceFullVisualEffects {
            tier = .full
        } else if runtimeConstrained || visualComplexity == .minimal {
            tier = .essential
        } else if usesLegacyCompositor || visualComplexity == .balanced {
            tier = .efficient
        } else {
            tier = .full
        }

        let transientMotionAllowed = forceFullVisualEffects || !reduceMotionEnabled
        let continuousMotionAllowed = transientMotionAllowed && persistentMotionAllowed
        let budget: VeilSkeuomorphicRenderBudget

        switch tier {
        case .essential:
            budget = VeilSkeuomorphicRenderBudget(
                tier: .essential,
                outerShadowLayers: 0,
                maxShadowRadius: 0,
                maxDecorativeOverlayLayers: 1,
                allowsInnerHighlight: true,
                allowsSpecularGradient: false,
                allowsBackdropMaterial: false,
                allowsAnimatedGlow: false,
                allows3DTilt: false,
                maxTiltDegrees: 0,
                maxContinuousDecorativeAnimations: 0,
                gaugeSegmentLimit: 6,
                grilleDensityScale: 0.60
            )

        case .efficient:
            budget = VeilSkeuomorphicRenderBudget(
                tier: .efficient,
                outerShadowLayers: 1,
                maxShadowRadius: 4,
                maxDecorativeOverlayLayers: 2,
                allowsInnerHighlight: true,
                allowsSpecularGradient: true,
                allowsBackdropMaterial: false,
                allowsAnimatedGlow: false,
                allows3DTilt: transientMotionAllowed,
                maxTiltDegrees: transientMotionAllowed ? 2.2 : 0,
                maxContinuousDecorativeAnimations: continuousMotionAllowed ? 1 : 0,
                gaugeSegmentLimit: 10,
                grilleDensityScale: 0.80
            )

        case .full:
            budget = VeilSkeuomorphicRenderBudget(
                tier: .full,
                outerShadowLayers: 2,
                maxShadowRadius: 12,
                maxDecorativeOverlayLayers: 3,
                allowsInnerHighlight: true,
                allowsSpecularGradient: true,
                allowsBackdropMaterial: true,
                allowsAnimatedGlow: continuousMotionAllowed,
                allows3DTilt: transientMotionAllowed,
                maxTiltDegrees: transientMotionAllowed ? 6.0 : 0,
                maxContinuousDecorativeAnimations: continuousMotionAllowed ? 2 : 0,
                gaugeSegmentLimit: 16,
                grilleDensityScale: 1.0
            )
        }

        return applyingRoleCap(budget, role: role)
    }

    private static func applyingRoleCap(
        _ budget: VeilSkeuomorphicRenderBudget,
        role: VeilSkeuomorphicSurfaceRole
    ) -> VeilSkeuomorphicRenderBudget {
        switch role {
        case .toolPanel:
            return budget

        case .denseScroll:
            return VeilSkeuomorphicRenderBudget(
                tier: budget.tier,
                outerShadowLayers: min(budget.outerShadowLayers, 1),
                maxShadowRadius: min(budget.maxShadowRadius, 4),
                maxDecorativeOverlayLayers: min(budget.maxDecorativeOverlayLayers, 2),
                allowsInnerHighlight: budget.allowsInnerHighlight,
                allowsSpecularGradient: budget.allowsSpecularGradient,
                allowsBackdropMaterial: false,
                allowsAnimatedGlow: false,
                allows3DTilt: budget.allows3DTilt,
                maxTiltDegrees: min(budget.maxTiltDegrees, 2.2),
                maxContinuousDecorativeAnimations: 0,
                gaugeSegmentLimit: min(budget.gaugeSegmentLimit, 10),
                grilleDensityScale: min(budget.grilleDensityScale, 0.80)
            )

        case .arcadeConsole:
            return VeilSkeuomorphicRenderBudget(
                tier: budget.tier,
                outerShadowLayers: min(budget.outerShadowLayers, 2),
                maxShadowRadius: min(budget.maxShadowRadius, 8),
                maxDecorativeOverlayLayers: min(budget.maxDecorativeOverlayLayers, 3),
                allowsInnerHighlight: budget.allowsInnerHighlight,
                allowsSpecularGradient: budget.allowsSpecularGradient,
                allowsBackdropMaterial: budget.allowsBackdropMaterial,
                allowsAnimatedGlow: budget.allowsAnimatedGlow,
                allows3DTilt: budget.allows3DTilt,
                maxTiltDegrees: min(budget.maxTiltDegrees, 4.0),
                maxContinuousDecorativeAnimations: min(
                    budget.maxContinuousDecorativeAnimations,
                    1
                ),
                gaugeSegmentLimit: min(budget.gaugeSegmentLimit, 14),
                grilleDensityScale: budget.grilleDensityScale
            )

        case .tacticalMap:
            return VeilSkeuomorphicRenderBudget(
                tier: budget.tier,
                outerShadowLayers: min(budget.outerShadowLayers, 1),
                maxShadowRadius: min(budget.maxShadowRadius, 4),
                maxDecorativeOverlayLayers: min(budget.maxDecorativeOverlayLayers, 2),
                allowsInnerHighlight: budget.allowsInnerHighlight,
                allowsSpecularGradient: budget.allowsSpecularGradient,
                allowsBackdropMaterial: false,
                allowsAnimatedGlow: false,
                allows3DTilt: false,
                maxTiltDegrees: 0,
                maxContinuousDecorativeAnimations: 0,
                gaugeSegmentLimit: min(budget.gaugeSegmentLimit, 8),
                grilleDensityScale: min(budget.grilleDensityScale, 0.75)
            )
        }
    }
}

enum VeilSkeuomorphicPerformance {
    private static var runtimeConstrained: Bool {
        let process = ProcessInfo.processInfo
        return process.isLowPowerModeEnabled
            || process.thermalState == .serious
            || process.thermalState == .critical
    }

    static func currentBudget(
        for role: VeilSkeuomorphicSurfaceRole,
        reduceMotionRequested: Bool
    ) -> VeilSkeuomorphicRenderBudget {
        let snapshot = PerformanceOverrideStore.shared.snapshot()
        let usesLegacyCompositor = VeilRenderProfile.usesLegacyCompositorPath
        let isRuntimeConstrained = runtimeConstrained
        let persistentMotionAllowed = PerformanceOverridePolicy.allowsPersistentMotion(
            baseAllows: VeilRenderProfile.allowsPersistentAnimations,
            usesLegacyCompositor: usesLegacyCompositor,
            runtimeConstrained: isRuntimeConstrained,
            snapshot: snapshot
        )

        return VeilSkeuomorphicPerformancePolicy.budget(
            visualComplexity: VeilDevicePerformance.current.transferVisualComplexity,
            usesLegacyCompositor: usesLegacyCompositor,
            runtimeConstrained: isRuntimeConstrained,
            reduceMotionEnabled: reduceMotionRequested,
            forceFullVisualEffects: snapshot.isEnabled && snapshot.forceFullVisualEffects,
            persistentMotionAllowed: persistentMotionAllowed,
            role: role
        )
    }
}
