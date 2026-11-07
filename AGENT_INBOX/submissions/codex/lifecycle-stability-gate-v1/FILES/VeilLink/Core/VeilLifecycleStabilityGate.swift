import Foundation

enum VeilLifecyclePhase: Equatable, Sendable {
    case active
    case inactive
    case background
}

enum VeilLifecycleEvent: Equatable, Sendable {
    case rootAppeared(VeilLifecyclePhase)
    case sceneChanged(VeilLifecyclePhase)
    case memoryWarning(uptime: TimeInterval)
}

enum VeilLifecycleAction: Equatable, Sendable {
    case attachRuntime
    case startRuntime
    case setHostForeground(Bool)
    case enterForeground
    case prepareBackground
    case enterBackground
    case handleMemoryPressure
}

/// A pure state machine that turns noisy SwiftUI/UIKit lifecycle delivery into exactly-once work.
/// It does not suppress real transitions: active -> inactive -> background -> active still emits
/// every required action in order. It only removes duplicate notifications and warning bursts.
struct VeilLifecycleStabilityGate: Sendable {
    static let memoryWarningCooldown: TimeInterval = 2

    private(set) var phase: VeilLifecyclePhase?
    private(set) var runtimeAttached = false
    private(set) var runtimeStarted = false
    private(set) var backgroundPrepared = false
    private var lastHandledMemoryWarningUptime: TimeInterval?

    mutating func consume(_ event: VeilLifecycleEvent) -> [VeilLifecycleAction] {
        switch event {
        case .rootAppeared(let currentPhase):
            var actions: [VeilLifecycleAction] = []
            let firstStart = !runtimeStarted
            if !runtimeAttached {
                runtimeAttached = true
                actions.append(.attachRuntime)
            }
            if !runtimeStarted {
                runtimeStarted = true
                actions.append(.startRuntime)
            }
            actions.append(contentsOf: transition(to: currentPhase, forceInitial: firstStart))
            return actions

        case .sceneChanged(let nextPhase):
            guard runtimeAttached, runtimeStarted else {
                phase = nextPhase
                return []
            }
            return transition(to: nextPhase, forceInitial: false)

        case .memoryWarning(let uptime):
            guard runtimeAttached, runtimeStarted, uptime.isFinite, uptime >= 0 else { return [] }
            if let last = lastHandledMemoryWarningUptime,
               uptime >= last,
               uptime - last < Self.memoryWarningCooldown {
                return []
            }
            lastHandledMemoryWarningUptime = uptime
            return [.handleMemoryPressure]
        }
    }

    private mutating func transition(
        to next: VeilLifecyclePhase,
        forceInitial: Bool
    ) -> [VeilLifecycleAction] {
        guard forceInitial || phase != next else { return [] }
        let previous = phase
        phase = next

        switch next {
        case .active:
            backgroundPrepared = false
            return [.setHostForeground(true), .enterForeground]

        case .inactive:
            guard !backgroundPrepared else {
                return previous == .active ? [.setHostForeground(false)] : []
            }
            backgroundPrepared = true
            return [.setHostForeground(false), .prepareBackground]

        case .background:
            var actions: [VeilLifecycleAction] = []
            if previous != .inactive { actions.append(.setHostForeground(false)) }
            if !backgroundPrepared {
                backgroundPrepared = true
                actions.append(.prepareBackground)
            }
            actions.append(.enterBackground)
            return actions
        }
    }
}
