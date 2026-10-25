import Foundation

/// Fixed-step simulation clock separate from the renderer's variable refresh.
/// Prevents background catch-up storms and long-frame physics explosions.
public struct VeilFramePacer: Sendable {
    public struct Step: Equatable, Sendable {
        public let simulationSteps: Int
        public let stepSeconds: Double
        public let interpolation: Double
        public let droppedSeconds: Double
    }
    public static let fixedStep: Double = 1.0 / 60
    private var previous: Double?
    private var remainder = 0.0
    public private(set) var totalDroppedSeconds = 0.0
    public private(set) var totalSimSteps = 0
    public init() {}
    public mutating func reset() { previous = nil; remainder = 0 }
    public mutating func advance(now: Double, maxCatchUpSteps: Int = 4) -> Step? {
        guard now.isFinite, now >= 0, (1...8).contains(maxCatchUpSteps) else { return nil }
        guard let last = previous else { previous = now; return Step(simulationSteps: 0, stepSeconds: Self.fixedStep, interpolation: 0, droppedSeconds: 0) }
        guard now >= last else { return nil }
        previous = now
        // Never force 60 simulated seconds after a 60s background pause.
        let delta = min(now - last, 0.25)
        let dropped = max(0, now - last - delta)
        remainder += delta
        let requested = Int((remainder + 1e-10) / Self.fixedStep)
        let steps = min(requested, maxCatchUpSteps)
        remainder -= Double(steps) * Self.fixedStep
        let cappedRemainder = min(remainder, Self.fixedStep * 0.999999)
        let overflow = max(0, remainder - cappedRemainder)
        remainder = cappedRemainder
        totalDroppedSeconds += dropped + overflow
        totalSimSteps += steps
        return Step(simulationSteps: steps, stepSeconds: Self.fixedStep,
                    interpolation: max(0, min(remainder / Self.fixedStep, 1)), droppedSeconds: dropped + overflow)
    }
}

/// Rendering budgets are targets, not proof of physical-device performance.
/// Limits only the local entertainment scene, not the chat application's global refresh.
public struct VeilRenderBudget: Equatable, Sendable {
    public enum Tier: String, Codable, Sendable { case legacy, balanced, high }
    public let tier: Tier
    public let targetFPS: Int
    public let visibleNotes: Int
    public let particleBudget: Int
    public let maxSprites: Int
    public init(tier: Tier) {
        self.tier = tier
        switch tier {
        case .legacy: targetFPS = 30; visibleNotes = 5; particleBudget = 0; maxSprites = 48
        case .balanced: targetFPS = 30; visibleNotes = 8; particleBudget = 16; maxSprites = 96
        case .high: targetFPS = 60; visibleNotes = 12; particleBudget = 32; maxSprites = 160
        }
    }
}
