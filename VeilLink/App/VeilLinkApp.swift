import SwiftUI

@main
struct VeilLinkApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootContainer(model: model)
                .preferredColorScheme(.dark)
                .onAppear { model.start() }
                .onChange(of: scenePhase) { phase in
                    if phase != .active {
                        model.appLock.lock()
                        model.ownerMode.lock()
                    }
                }
        }
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
