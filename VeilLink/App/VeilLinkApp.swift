import Combine
import SwiftUI
import UIKit

@main
struct VeilLinkApp: App {
    @UIApplicationDelegateAdaptor(VeilBackgroundAppDelegate.self) private var backgroundDelegate
    @StateObject private var bootstrap = AppBootstrap()
    @StateObject private var appearance = VeilAppearanceController.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        TacticalLocalRenderCache.warmUp()
        VeilChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !bootstrap.onboarding.isCompleted {
                    VeilReleaseActivationView(
                        controller: bootstrap.onboarding,
                        legal: bootstrap.legal
                    ) {
                        bootstrap.completeFirstActivation()
                    }
                } else if !bootstrap.legal.isSatisfied {
                    LegalConsentGateView(controller: bootstrap.legal) {
                        bootstrap.activateAfterLegalAcceptance()
                    }
                } else if let model = bootstrap.model {
                    RootContainer(model: model)
                        .onAppear {
                            RuntimeDiagnosticsBridge.shared.attach(to: model)
                            DeviceStressTestController.shared.attach(model: model)
                            RuntimeDiagnosticsBridge.shared.recordLifecycle("root.appear")
                            VeilBackgroundContinuityCenter.shared.attach(to: model)
                            model.start()
                        }
                        .onChange(of: scenePhase) { phase in
                            RuntimeDiagnosticsBridge.shared.recordLifecycle("scene.\(String(describing: phase))")
                            DeviceStressTestController.shared.handleSceneActive(phase == .active)
                            model.bluetooth.setForegroundActive(phase == .active)
                            switch phase {
                            case .active:
                                model.handleForegroundTransition()
                                VeilBackgroundContinuityCenter.shared.becameActive(model: model)
                            case .inactive:
                                // Start/refresh the visible continuity surface while the app is
                                // still eligible to create a Live Activity. Do not lock/reset yet.
                                VeilBackgroundContinuityCenter.shared.prepareForBackgroundTransition(model: model)
                            case .background:
                                VeilBackgroundContinuityCenter.shared.enteredBackground(model: model)
                                model.handleBackgroundTransition()
                                model.appLock.lock()
                                model.ownerMode.lock()
                            @unknown default:
                                break
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                            RuntimeDiagnosticsBridge.shared.recordMemoryPressure()
                            DeviceStressTestController.shared.noteMemoryWarning()
                            VeilBackgroundContinuityCenter.shared.handleMemoryPressure()
                            model.handleMemoryPressure()
                        }
                } else {
                    StartupFailureView(message: bootstrap.errorMessage)
                }
            }
            .preferredColorScheme(appearance.preferredColorScheme)
            .onAppear {
                appearance.synchronizeSystemAppearance()
                VeilChrome.configure()
            }
            .onChange(of: appearance.colorMode) { _ in
                appearance.synchronizeSystemAppearance()
                VeilChrome.configure()
            }
            .onChange(of: appearance.selection) { _ in VeilChrome.configure() }
        }
    }
}

enum VeilChrome {
    @MainActor
    static func configure() {
        let appearance = VeilAppearanceController.shared
        let appleSoft = appearance.isAppleSoft
        let navigation = UINavigationBarAppearance()
        if appleSoft {
            navigation.configureWithTransparentBackground()
            navigation.backgroundColor = .clear
            if #available(iOS 26.0, *) {
                // Keep system chrome unpainted so current SDKs can supply native Liquid Glass.
            } else {
                navigation.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
            navigation.shadowColor = .clear
            navigation.titleTextAttributes = [.foregroundColor: UIColor.label]
            navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        } else {
            navigation.configureWithOpaqueBackground()
            navigation.backgroundColor = UIColor(VeilTheme.background).withAlphaComponent(0.96)
            navigation.shadowColor = UIColor(VeilTheme.hairline)
            navigation.titleTextAttributes = [.foregroundColor: UIColor(VeilTheme.text)]
            navigation.largeTitleTextAttributes = [.foregroundColor: UIColor(VeilTheme.text)]
        }

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigation
        navigationBar.compactAppearance = navigation
        navigationBar.scrollEdgeAppearance = navigation
        navigationBar.tintColor = appleSoft ? .systemBlue : UIColor(VeilTheme.gold)

        let tab = UITabBarAppearance()
        if appleSoft {
            tab.configureWithTransparentBackground()
            tab.backgroundColor = .clear
            if #available(iOS 26.0, *) {
                // Standard tab chrome can adopt platform Liquid Glass.
            } else {
                tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
            tab.shadowColor = .clear
        } else {
            tab.configureWithOpaqueBackground()
            tab.backgroundColor = UIColor(VeilTheme.background).withAlphaComponent(0.985)
            tab.shadowColor = UIColor(VeilTheme.hairline)
        }
        let selected = appleSoft ? UIColor.systemBlue : UIColor(VeilTheme.goldBright)
        let normal = appleSoft ? UIColor.secondaryLabel : UIColor(VeilTheme.secondaryText)
        for appearance in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            appearance.selected.iconColor = selected
            appearance.selected.titleTextAttributes = [.foregroundColor: selected]
            appearance.normal.iconColor = normal
            appearance.normal.titleTextAttributes = [.foregroundColor: normal]
        }
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab
    }
}

@MainActor
private final class AppBootstrap: ObservableObject {
    @Published private(set) var model: AppModel?
    @Published private(set) var errorMessage = ""
    let legal: VeilLegalConsentController
    let onboarding: VeilFirstRunOnboardingController

    private let keychain: KeychainStore
    private var legalCancellable: AnyCancellable?

    init() {
        keychain = KeychainStore()
        legal = VeilLegalConsentController(keychain: keychain)
        onboarding = VeilFirstRunOnboardingController()
        legalCancellable = legal.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        if legal.isSatisfied && onboarding.isCompleted { initializeModel() }
    }

    func completeFirstActivation() {
        guard legal.isSatisfied else { return }
        onboarding.complete()
        if model == nil {
            initializeModel()
        } else {
            model?.activateAfterLegalAcceptance()
        }
    }

    func activateAfterLegalAcceptance() {
        guard legal.isSatisfied, onboarding.isCompleted else { return }
        if model == nil {
            initializeModel()
        } else {
            model?.activateAfterLegalAcceptance()
        }
    }

    private func initializeModel() {
        guard legal.isSatisfied, onboarding.isCompleted, model == nil else { return }
        let diagnostics = RuntimeDiagnosticsBridge.shared
        diagnostics.recordStartupBegin()
        do {
            model = try AppModel(keychain: keychain, legalConsent: legal)
            errorMessage = ""
            diagnostics.recordStartupSuccess()
        } catch {
            model = nil
            errorMessage = error.localizedDescription
            diagnostics.recordStartupFailure(error)
        }
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(VeilTheme.goldBright)
            Text("本地数据未能安全打开")
                .font(.title3.weight(.semibold))
            Text("VeilLink 没有自动重建或覆盖数据库，以避免造成不可逆的数据丢失。请重新启动应用；如果问题持续存在，再使用最近的有效备份恢复。")
                .multilineTextAlignment(.center)
                .foregroundColor(VeilTheme.secondaryText)
            if !message.isEmpty {
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundColor(VeilTheme.secondaryText)
                    .textSelection(.enabled)
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VeilAmbientBackground())
    }
}

private struct RootContainer: View {
    @ObservedObject var model: AppModel
    @ObservedObject var identity: IdentityManager
    @ObservedObject var appLock: AppLockController
    @ObservedObject var legalConsent: VeilLegalConsentController
    @ObservedObject var stressTest: DeviceStressTestController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) {
        self.model = model
        identity = model.identity
        appLock = model.appLock
        legalConsent = model.legalConsent
        stressTest = DeviceStressTestController.shared
    }

    var body: some View {
        ZStack {
            VeilAmbientBackground()
            if !legalConsent.isSatisfied {
                LegalConsentGateView(controller: legalConsent) {
                    model.activateAfterLegalAcceptance()
                }
                .transition(.opacity)
            } else if identity.activeIdentity == nil {
                OnboardingView(model: model)
                    .telemetryScreen("onboarding")
                    .transition(.opacity)
            } else if appLock.isLocked {
                LockScreenView(controller: appLock, haptics: model.haptics)
                    .telemetryScreen("lock")
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.992)))
            } else {
                AdaptiveRootView(model: model)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.006)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if stressTest.isRunning {
                DeviceStressTestHUD(controller: stressTest)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
        .animation(reduceMotion ? nil : VeilMotion.reveal, value: appLock.isLocked)
        .animation(reduceMotion ? nil : VeilMotion.reveal, value: identity.activeIdentity?.id)
        .alert("VeilLink", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("确定", role: .cancel) {
                RuntimeDiagnosticsBridge.shared.recordSemanticAction("alert.dismiss")
                model.alertMessage = nil
            }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}
