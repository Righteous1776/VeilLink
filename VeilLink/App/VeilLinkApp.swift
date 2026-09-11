import SwiftUI

@main
struct VeilLinkApp: App {
    @StateObject private var bootstrap = AppBootstrap()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let model = bootstrap.model {
                    RootContainer(model: model)
                        .onAppear { model.start() }
                        .onChange(of: scenePhase) { phase in
                            if phase != .active {
                                model.appLock.lock()
                                model.ownerMode.lock()
                            }
                        }
                } else {
                    StartupFailureView(message: bootstrap.errorMessage)
                }
            }
            .preferredColorScheme(.dark)
        }
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
                .foregroundColor(VeilTheme.gold)
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
        .background(VeilTheme.background.ignoresSafeArea())
    }
}

private struct RootContainer: View {
    @ObservedObject var model: AppModel
    @ObservedObject var identity: IdentityManager
    @ObservedObject var appLock: AppLockController

    init(model: AppModel) {
        self.model = model
        identity = model.identity
        appLock = model.appLock
    }

    var body: some View {
        ZStack {
            VeilTheme.background.ignoresSafeArea()
            if identity.activeIdentity == nil {
                OnboardingView(model: model)
            } else if appLock.isLocked {
                LockScreenView(controller: appLock)
            } else {
                AdaptiveRootView(model: model)
            }
        }
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
