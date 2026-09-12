import SwiftUI
import UIKit

@main
struct VeilLinkApp: App {
    @StateObject private var bootstrap = AppBootstrap()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        VeilChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let model = bootstrap.model {
                    RootContainer(model: model)
                        .onAppear { model.start() }
                        .onChange(of: scenePhase) { phase in
                            if phase != .active {
                                model.trimCachesForBackgroundIfNeeded()
                                model.appLock.lock()
                                model.ownerMode.lock()
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                            model.handleMemoryPressure()
                        }
                } else {
                    StartupFailureView(message: bootstrap.errorMessage)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

private enum VeilChrome {
    static func configure() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = UIColor(red: 0.012, green: 0.013, blue: 0.017, alpha: 0.96)
        navigation.shadowColor = UIColor.white.withAlphaComponent(0.045)
        navigation.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.94)]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.94)]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigation
        navigationBar.compactAppearance = navigation
        navigationBar.scrollEdgeAppearance = navigation
        navigationBar.tintColor = UIColor(red: 0.86, green: 0.64, blue: 0.24, alpha: 1)

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.020, green: 0.021, blue: 0.026, alpha: 0.985)
        tab.shadowColor = UIColor.white.withAlphaComponent(0.05)
        let selected = UIColor(red: 0.98, green: 0.82, blue: 0.46, alpha: 1)
        let normal = UIColor.white.withAlphaComponent(0.42)
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
    let model: AppModel?
    let errorMessage: String

    init() {
        do {
            model = try AppModel()
            errorMessage = ""
        } catch {
            model = nil
            errorMessage = error.localizedDescription
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) {
        self.model = model
        identity = model.identity
        appLock = model.appLock
    }

    var body: some View {
        ZStack {
            VeilAmbientBackground()
            if identity.activeIdentity == nil {
                OnboardingView(model: model)
                    .transition(.opacity)
            } else if appLock.isLocked {
                LockScreenView(controller: appLock, haptics: model.haptics)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.992)))
            } else {
                AdaptiveRootView(model: model)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.006)))
            }
        }
        .animation(reduceMotion ? nil : VeilMotion.reveal, value: appLock.isLocked)
        .animation(reduceMotion ? nil : VeilMotion.reveal, value: identity.activeIdentity?.id)
        .alert("VeilLink", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("确定", role: .cancel) { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}
