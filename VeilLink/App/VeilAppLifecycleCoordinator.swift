import SwiftUI
import UIKit

@MainActor
final class VeilAppLifecycleCoordinator: ObservableObject {
    private weak var model: AppModel?
    private var gate = VeilLifecycleStabilityGate()

    func rootAppeared(model: AppModel, scenePhase: ScenePhase) {
        prepare(for: model)
        execute(gate.consume(.rootAppeared(Self.phase(scenePhase))), model: model)
    }

    func sceneChanged(_ scenePhase: ScenePhase, model: AppModel) {
        prepare(for: model)
        let phase = Self.phase(scenePhase)
        let actions = gate.consume(.sceneChanged(phase))
        guard !actions.isEmpty else { return }
        RuntimeDiagnosticsBridge.shared.recordLifecycle("scene.\(Self.label(phase))")
        execute(actions, model: model)
    }

    func memoryWarning(model: AppModel, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        prepare(for: model)
        let actions = gate.consume(.memoryWarning(uptime: uptime))
        guard !actions.isEmpty else { return }
        RuntimeDiagnosticsBridge.shared.recordMemoryPressure()
        DeviceStressTestController.shared.noteMemoryWarning()
        execute(actions, model: model)
    }

    private func prepare(for model: AppModel) {
        guard self.model !== model else { return }
        self.model = model
        gate = VeilLifecycleStabilityGate()
    }

    private func execute(_ actions: [VeilLifecycleAction], model: AppModel) {
        for action in actions {
            switch action {
            case .attachRuntime:
                RuntimeDiagnosticsBridge.shared.attach(to: model)
                DeviceStressTestController.shared.attach(model: model)
                RuntimeDiagnosticsBridge.shared.recordLifecycle("root.appear")
                VeilBackgroundContinuityCenter.shared.attach(to: model)
            case .startRuntime:
                model.start()
            case .setHostForeground(let active):
                DeviceStressTestController.shared.handleSceneActive(active)
                model.bluetooth.setForegroundActive(active)
            case .enterForeground:
                model.handleForegroundTransition()
                VeilBackgroundContinuityCenter.shared.becameActive(model: model)
            case .prepareBackground:
                VeilBackgroundContinuityCenter.shared.prepareForBackgroundTransition(model: model)
            case .enterBackground:
                VeilBackgroundContinuityCenter.shared.enteredBackground(model: model)
                model.handleBackgroundTransition()
                model.appLock.lock()
                model.ownerMode.lock()
                model.developerLearningGate.lock()
            case .handleMemoryPressure:
                VeilBackgroundContinuityCenter.shared.handleMemoryPressure()
                model.handleMemoryPressure()
            }
        }
    }

    private static func phase(_ phase: ScenePhase) -> VeilLifecyclePhase {
        switch phase {
        case .active: return .active
        case .inactive: return .inactive
        case .background: return .background
        @unknown default: return .inactive
        }
    }

    private static func label(_ phase: VeilLifecyclePhase) -> String {
        switch phase {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        }
    }
}
