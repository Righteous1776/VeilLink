import BackgroundTasks
import Combine
import Foundation
import UIKit

#if canImport(ActivityKit)
import ActivityKit
#endif

enum VeilBackgroundTier: String, Codable, Equatable {
    case legacyBluetooth = "BLE BACKGROUND"
    case liveActivityBluetooth = "LIVE ACTIVITY + BLE"
}

struct VeilBackgroundCapabilityProfile: Equatable {
    let tier: VeilBackgroundTier
    let liveActivityEligible: Bool
    let shouldUseShortTransitionWindow: Bool
    let appRefreshEligible: Bool

    static func resolve(
        osMajorVersion: Int,
        liveActivitiesAllowed: Bool,
        backgroundRefreshAllowed: Bool
    ) -> VeilBackgroundCapabilityProfile {
        let live = osMajorVersion >= 16 && liveActivitiesAllowed
        return VeilBackgroundCapabilityProfile(
            tier: live ? .liveActivityBluetooth : .legacyBluetooth,
            liveActivityEligible: live,
            shouldUseShortTransitionWindow: true,
            appRefreshEligible: backgroundRefreshAllowed
        )
    }
}

@MainActor
protocol VeilLiveActivityDriving: AnyObject {
    var isActive: Bool { get }
    func ensureStarted(state: VeilBackgroundActivitySnapshot)
    func update(state: VeilBackgroundActivitySnapshot)
    func end()
}

struct VeilBackgroundActivitySnapshot: Equatable {
    let mode: String
    let connectedBLEPeers: Int
    let connectedLANPeers: Int
    let meshNeighbors: Int
    let updatedAt: Date
}

@MainActor
final class VeilBackgroundContinuityCenter: ObservableObject {
    static let shared = VeilBackgroundContinuityCenter()
    static let appRefreshIdentifier = "studio.zeo.veillink.background.refresh"

    @Published private(set) var statusText = "后台连续性待初始化"
    @Published private(set) var liveActivityActive = false
    @Published private(set) var lastBackgroundWakeAt: Date?
    @Published private(set) var lastRefreshResult = "尚未执行后台刷新"

    private static let continuityKey = "background.continuity.enabled"
    private static let liveActivityKey = "background.liveActivity.enabled"

    weak var model: AppModel?
    private var transitionTask: UIBackgroundTaskIdentifier = .invalid
    private var transitionEndTask: Task<Void, Never>?
    private var liveActivityDriver: VeilLiveActivityDriving?

    private init() {
        UserDefaults.standard.register(defaults: [
            Self.continuityKey: true,
            Self.liveActivityKey: true
        ])
    }

    var continuityEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.continuityKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.continuityKey)
            if !newValue { stopVisibleContinuitySurface() }
            refreshStatus()
        }
    }

    var liveActivityEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.liveActivityKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.liveActivityKey)
            if !newValue { stopVisibleContinuitySurface() }
            else if let model { prepareForBackgroundTransition(model: model) }
            refreshStatus()
        }
    }

    var supportsLiveActivity: Bool {
        if #available(iOS 16.1, *) { return true }
        return false
    }

    var profile: VeilBackgroundCapabilityProfile {
        VeilBackgroundCapabilityProfile.resolve(
            osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            liveActivitiesAllowed: liveActivitiesAllowedBySystem,
            backgroundRefreshAllowed: UIApplication.shared.backgroundRefreshStatus == .available
        )
    }

    private var liveActivitiesAllowedBySystem: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }

    func attach(to model: AppModel) {
        self.model = model
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit)
            if liveActivityDriver == nil { liveActivityDriver = VeilLiveActivityDriver() }
            #endif
        }
        refreshStatus()
    }

    /// Called while the scene is still transitioning away from active. Starting the Live Activity
    /// here matters because ActivityKit normally requires a foreground app to create it.
    func prepareForBackgroundTransition(model: AppModel) {
        attach(to: model)
        guard continuityEnabled else { return }
        updateVisibleContinuitySurface(startIfNeeded: true)
        statusText = "正在切换到后台连续性模式"
    }

    func enteredBackground(model: AppModel) {
        attach(to: model)
        guard continuityEnabled else {
            statusText = "后台连续性已关闭"
            return
        }
        beginFiniteTransitionWindow()
        scheduleAppRefresh()
        updateVisibleContinuitySurface(startIfNeeded: false)
        statusText = profile.tier.rawValue + " · BLE 等待系统事件唤醒"
    }

    func becameActive(model: AppModel) {
        attach(to: model)
        endFiniteTransitionWindow()
        model.bluetooth.refreshLinks()
        model.lanTurbo.refresh()
        model.meshRouter.replayRecent()
        updateVisibleContinuitySurface(startIfNeeded: true)
        statusText = "前台 · BLE/LAN/Mesh 全速运行"
    }

    func handleMemoryPressure() {
        endFiniteTransitionWindow()
        refreshStatus()
    }

    func refreshNow() {
        guard let model else { return }
        model.bluetooth.refreshLinks()
        model.lanTurbo.refresh()
        model.meshRouter.replayRecent()
        lastRefreshResult = "已请求 BLE/LAN/Mesh 刷新 · \(Date().formatted())"
        updateVisibleContinuitySurface(startIfNeeded: false)
    }

    func scheduleAppRefresh() {
        guard continuityEnabled,
              UIApplication.shared.backgroundRefreshStatus == .available else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lastRefreshResult = "后台刷新调度失败：\(error.localizedDescription)"
        }
    }

    func performAppRefresh(task: BGAppRefreshTask) async {
        scheduleAppRefresh()
        guard continuityEnabled, let model else {
            task.setTaskCompleted(success: false)
            return
        }
        lastBackgroundWakeAt = Date()
        model.bluetooth.refreshLinks()
        model.lanTurbo.refresh()
        model.meshRouter.replayRecent()
        updateVisibleContinuitySurface(startIfNeeded: false)

        // App refresh is opportunistic, not a real-time keepalive. A short observation window gives
        // CoreBluetooth/Network delegates time to deliver already-pending state without spinning.
        do {
            try await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else {
                task.setTaskCompleted(success: false)
                return
            }
            lastRefreshResult = "系统后台刷新完成 · \(Date().formatted())"
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    func stopVisibleContinuitySurface() {
        liveActivityDriver?.end()
        liveActivityActive = false
        refreshStatus()
    }

    private func beginFiniteTransitionWindow() {
        endFiniteTransitionWindow()
        transitionTask = UIApplication.shared.beginBackgroundTask(withName: "VeilLink.BackgroundTransition") { [weak self] in
            Task { @MainActor in self?.endFiniteTransitionWindow() }
        }
        guard transitionTask != .invalid else { return }
        transitionEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled else { return }
            self?.endFiniteTransitionWindow()
        }
    }

    private func endFiniteTransitionWindow() {
        transitionEndTask?.cancel()
        transitionEndTask = nil
        guard transitionTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(transitionTask)
        transitionTask = .invalid
    }

    private func updateVisibleContinuitySurface(startIfNeeded: Bool) {
        guard continuityEnabled, liveActivityEnabled, supportsLiveActivity else {
            liveActivityActive = false
            return
        }
        let snapshot = makeSnapshot()
        if startIfNeeded { liveActivityDriver?.ensureStarted(state: snapshot) }
        else { liveActivityDriver?.update(state: snapshot) }
        liveActivityActive = liveActivityDriver?.isActive ?? false
    }

    private func makeSnapshot() -> VeilBackgroundActivitySnapshot {
        guard let model else {
            return VeilBackgroundActivitySnapshot(
                mode: "VEILLINK", connectedBLEPeers: 0, connectedLANPeers: 0,
                meshNeighbors: 0, updatedAt: Date()
            )
        }
        let ble = model.bluetooth.linkSnapshots.values.filter(\.isConnected).count
        let lan = model.lanTurbo.linkSnapshots.values.filter(\.isReady).count
        let mesh = model.meshRouter.snapshot.neighborCount
        let mode: String
        if lan > 0 { mode = "LAN TURBO + BLE" }
        else if ble > 0 { mode = "BLE E2EE" }
        else { mode = "等待附近链路" }
        return VeilBackgroundActivitySnapshot(
            mode: mode,
            connectedBLEPeers: ble,
            connectedLANPeers: lan,
            meshNeighbors: mesh,
            updatedAt: Date()
        )
    }

    private func refreshStatus() {
        if !continuityEnabled {
            statusText = "后台连续性已关闭"
        } else if UIApplication.shared.applicationState == .active {
            statusText = "前台 · BLE/LAN/Mesh 全速运行"
        } else {
            statusText = profile.tier.rawValue + " · 受 iOS 调度约束"
        }
        liveActivityActive = liveActivityDriver?.isActive ?? false
    }
}

final class VeilBackgroundAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: VeilBackgroundContinuityCenter.appRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let work = Task { @MainActor in
                await VeilBackgroundContinuityCenter.shared.performAppRefresh(task: refreshTask)
            }
            refreshTask.expirationHandler = { work.cancel() }
        }
        return true
    }
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
@MainActor
private final class VeilLiveActivityDriver: VeilLiveActivityDriving {
    private var activity: Activity<VeilBackgroundActivityAttributes>?

    var isActive: Bool { activity != nil }

    func ensureStarted(state: VeilBackgroundActivitySnapshot) {
        if activity == nil {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                activity = try Activity.request(
                    attributes: VeilBackgroundActivityAttributes(instanceID: UUID().uuidString),
                    contentState: contentState(from: state),
                    pushType: nil
                )
            } catch {
                return
            }
        } else {
            update(state: state)
        }
    }

    func update(state: VeilBackgroundActivitySnapshot) {
        guard let activity else { return }
        let content = contentState(from: state)
        Task { await activity.update(using: content) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(using: nil, dismissalPolicy: .immediate) }
    }

    private func contentState(from state: VeilBackgroundActivitySnapshot) -> VeilBackgroundActivityAttributes.ContentState {
        VeilBackgroundActivityAttributes.ContentState(
            mode: state.mode,
            connectedBLEPeers: state.connectedBLEPeers,
            connectedLANPeers: state.connectedLANPeers,
            meshNeighbors: state.meshNeighbors,
            updatedAt: state.updatedAt
        )
    }
}
#endif
