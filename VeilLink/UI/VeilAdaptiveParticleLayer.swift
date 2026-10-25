import SwiftUI

private struct VeilParticleTrailSample: Equatable {
    let point: CGPoint
    let time: TimeInterval
}

private struct VeilParticleBurst: Equatable {
    let id: Int
    let origin: CGPoint?
    let time: TimeInterval
}

private struct VeilAdaptiveParticleModifier: ViewModifier {
    let eventToken: String
    let overrideSnapshot: PerformanceOverrideSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var trail: [VeilParticleTrailSample] = []
    @State private var burst: VeilParticleBurst?
    @State private var eventSequence = 0
    @State private var runtimeRevision = 0

    private var budget: VeilParticleBudget {
        VeilParticlePerformancePolicy.resolve(.init(
            isAppActive: scenePhase == .active,
            usesLegacyCompositor: VeilRenderProfile.usesLegacyCompositorPath,
            reduceMotionEnabled: reduceMotion,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalLevel: thermalLevel,
            visualComplexity: VeilDevicePerformance.base.transferVisualComplexity,
            forceFullVisualEffects: overrideSnapshot.isEnabled && overrideSnapshot.forceFullVisualEffects,
            allowPersistentAnimations: overrideSnapshot.isEnabled
                ? overrideSnapshot.allowPersistentAnimations
                : VeilRenderProfile.allowsPersistentAnimations
        ))
    }

    func body(content: Content) -> some View {
        let resolvedBudget = budget
        content
            .overlay {
                if resolvedBudget.isEnabled {
                    TimelineView(.animation(
                        minimumInterval: resolvedBudget.frameInterval,
                        paused: !resolvedBudget.allowsAmbientMotion && trail.isEmpty && burst == nil
                    )) { timeline in
                        VeilAdaptiveParticleCanvas(
                            time: timeline.date.timeIntervalSinceReferenceDate,
                            budget: resolvedBudget,
                            trail: trail,
                            burst: burst,
                            runtimeRevision: runtimeRevision
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            // Visual-only: never compete with Slider, scroll, game drag, or back gestures.
            .onChange(of: eventToken) { _ in
                guard resolvedBudget.burstCount > 0 else { return }
                emitBurst(at: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                runtimeRevision &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
                runtimeRevision &+= 1
            }
    }

    private func dragGesture(budget: VeilParticleBudget) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard budget.trailFragmentsPerSample > 0 else { return }
                let now = Date().timeIntervalSinceReferenceDate
                if let last = trail.last {
                    let distance = hypot(value.location.x - last.point.x, value.location.y - last.point.y)
                    guard distance >= 10 || now - last.time >= 0.05 else { return }
                    if now - last.time > 0.7 { trail.removeAll(keepingCapacity: true) }
                }
                trail.append(.init(point: value.location, time: now))
                if trail.count > budget.maximumTrailSamples {
                    trail.removeFirst(trail.count - budget.maximumTrailSamples)
                }
            }
            .onEnded { value in
                guard budget.burstCount > 0 else { return }
                emitBurst(at: value.location)
            }
    }

    private func emitBurst(at point: CGPoint?) {
        eventSequence &+= 1
        let sequence = eventSequence
        burst = VeilParticleBurst(
            id: sequence,
            origin: point,
            time: Date().timeIntervalSinceReferenceDate
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard eventSequence == sequence else { return }
            burst = nil
            trail.removeAll(keepingCapacity: true)
        }
    }

    private var thermalLevel: VeilParticleThermalLevel {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .serious
        }
    }
}

private struct VeilAdaptiveParticleCanvas: View {
    let time: TimeInterval
    let budget: VeilParticleBudget
    let trail: [VeilParticleTrailSample]
    let burst: VeilParticleBurst?
    let runtimeRevision: Int

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            context.blendMode = .plusLighter
            drawAmbient(context: &context, size: size)
            drawTrail(context: &context)
            drawBurst(context: &context, size: size)
        }
        .id(runtimeRevision)
    }

    private func drawAmbient(context: inout GraphicsContext, size: CGSize) {
        guard budget.ambientCount > 0, size.width > 0, size.height > 0 else { return }
        for index in 0..<budget.ambientCount {
            let xSeed = VeilParticleSeed.unit(73, lane: index * 4)
            let ySeed = VeilParticleSeed.unit(73, lane: index * 4 + 1)
            let speed = 0.018 + VeilParticleSeed.unit(73, lane: index * 4 + 2) * 0.035
            let cycle = (time * speed + ySeed).truncatingRemainder(dividingBy: 1)
            let sway = sin(time * (0.22 + speed) + Double(index)) * 0.025
            let x = size.width * CGFloat(max(0.01, min(0.99, xSeed + sway)))
            let y = size.height * CGFloat(1.03 - cycle * 1.08)
            let radius = CGFloat(0.7 + VeilParticleSeed.unit(73, lane: index * 4 + 3) * 1.8)
            let alpha = 0.05 + sin(cycle * .pi) * 0.16
            let color = index.isMultiple(of: 4) ? VeilTheme.goldBright : VeilTheme.paleMetal
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(alpha))
            )
        }
    }

    private func drawTrail(context: inout GraphicsContext) {
        guard budget.trailFragmentsPerSample > 0 else { return }
        for (sampleIndex, sample) in trail.enumerated() {
            let age = time - sample.time
            guard age >= 0, age < 0.72 else { continue }
            let life = 1 - age / 0.72
            for fragment in 0..<budget.trailFragmentsPerSample {
                let lane = sampleIndex * 11 + fragment
                let angle = VeilParticleSeed.unit(191, lane: lane) * .pi * 2
                let distance = CGFloat(age * (18 + VeilParticleSeed.unit(193, lane: lane) * 34))
                let point = CGPoint(
                    x: sample.point.x + CGFloat(cos(angle)) * distance,
                    y: sample.point.y + CGFloat(sin(angle)) * distance - CGFloat(age * 18)
                )
                let radius = CGFloat(1.2 + VeilParticleSeed.unit(197, lane: lane) * 2.4) * CGFloat(life)
                let color = fragment.isMultiple(of: 2) ? VeilTheme.goldBright : VeilTheme.paleMetal
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color.opacity(life * (budget.usesGlow ? 0.78 : 0.48)))
                )
            }
        }
    }

    private func drawBurst(context: inout GraphicsContext, size: CGSize) {
        guard let burst, budget.burstCount > 0 else { return }
        let age = time - burst.time
        guard age >= 0, age < 0.88 else { return }
        let progress = min(1, age / 0.88)
        let life = 1 - progress
        let origin = burst.origin ?? CGPoint(x: size.width * 0.5, y: size.height * 0.48)

        for index in 0..<budget.burstCount {
            let angle = VeilParticleSeed.unit(burst.id, lane: index * 3) * .pi * 2
            let velocity = 34 + VeilParticleSeed.unit(burst.id, lane: index * 3 + 1) * 150
            let distance = CGFloat(velocity * progress)
            let point = CGPoint(
                x: origin.x + CGFloat(cos(angle)) * distance,
                y: origin.y + CGFloat(sin(angle)) * distance + CGFloat(42 * progress * progress)
            )
            let base = CGFloat(1.2 + VeilParticleSeed.unit(burst.id, lane: index * 3 + 2) * 3.4)
            let radius = max(0.35, base * CGFloat(life))
            let color = index.isMultiple(of: 3) ? VeilTheme.goldBright : (index.isMultiple(of: 2) ? VeilTheme.gold : VeilTheme.paleMetal)
            var shard = Path()
            shard.move(to: CGPoint(x: point.x, y: point.y - radius * 1.7))
            shard.addLine(to: CGPoint(x: point.x + radius, y: point.y))
            shard.addLine(to: CGPoint(x: point.x, y: point.y + radius * 1.7))
            shard.addLine(to: CGPoint(x: point.x - radius, y: point.y))
            shard.closeSubpath()
            context.fill(shard, with: .color(color.opacity(life * (budget.usesGlow ? 0.92 : 0.60))))
        }
    }
}

extension View {
    func veilAdaptiveParticles(
        eventToken: String,
        overrideSnapshot: PerformanceOverrideSnapshot
    ) -> some View {
        modifier(VeilAdaptiveParticleModifier(
            eventToken: eventToken,
            overrideSnapshot: overrideSnapshot
        ))
    }
}
