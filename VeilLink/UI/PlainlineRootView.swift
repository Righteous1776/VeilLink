import SwiftUI
import UIKit

/// 白描（Plainline）实验风格的根容器。
///
/// 设计语言：一页纸。无卡片、无图标栏、无材质与阴影——
/// 只由排版、留白与发丝线组织界面。底部系统 TabView 被
/// 替换为发丝文字通道，顶部保留一枚字标。内容与遥测完全
/// 复用既有五个分区视图，本视图只负责框架（chrome）。
struct VeilPlainlineRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            wordmarkHeader
            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            navRail
        }
        .onChange(of: model.selectedSection) { section in
            RuntimeDiagnosticsBridge.shared.recordSemanticAction(
                "navigation.tab",
                metadata: ["section": section.rawValue, "chrome": "plainline"]
            )
        }
    }

    /// 顶部字标：产品名 + 当前分区名 + 风格记，底部一根发丝线。
    private var wordmarkHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: VeilSpacing.sm) {
                Text("VeilLink")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(VeilTheme.text)
                Text(model.selectedSection.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VeilTheme.secondaryText)
                Spacer()
                Text("白描 · PLAINLINE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(VeilTheme.gold)
            }
            .padding(.horizontal, VeilSpacing.lg)
            .padding(.vertical, VeilSpacing.sm)
            Rectangle()
                .fill(VeilTheme.hairline)
                .frame(height: 0.5)
        }
    }

    /// 内容区：五个既有分区视图原样复用（含各自遥测），保持导航栈行为一致。
    private var sectionContent: some View {
        Group {
            switch model.selectedSection {
            case .chats:
                NavigationView {
                    ConversationListView(model: model, usesNavigationLinks: true)
                        .telemetryScreen("chats.list")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .nearby:
                NavigationView {
                    NearbyView(model: model)
                        .telemetryScreen("nearby")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .games:
                NavigationView {
                    GameLobbyView(model: model)
                        .telemetryScreen("games.lobby")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .agent:
                NavigationView {
                    AgentHomeView(model: model)
                        .telemetryScreen("agent.home")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .settings:
                NavigationView {
                    SettingsView(model: model)
                        .telemetryScreen("settings")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    /// 底部导航：发丝线 + 五枚文字通道。选中项以金色短画线标记，
    /// 未读数以金色小号上标呈现。无图标、无胶囊、无背景填充。
    private var navRail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(VeilTheme.hairline)
                .frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(SidebarSection.allCases) { section in
                    Button {
                        guard model.selectedSection != section else { return }
                        model.selectedSection = section
                    } label: {
                        VStack(spacing: 5) {
                            Rectangle()
                                .fill(model.selectedSection == section ? VeilTheme.gold : Color.clear)
                                .frame(width: 20, height: 2)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(section.rawValue)
                                    .font(.system(
                                        size: 13,
                                        weight: model.selectedSection == section ? .semibold : .regular
                                    ))
                                if section == .chats, model.totalUnreadCount > 0 {
                                    Text(model.totalUnreadCount > 99 ? "99+" : "\(model.totalUnreadCount)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(VeilTheme.gold)
                                }
                            }
                            .foregroundColor(
                                model.selectedSection == section ? VeilTheme.text : VeilTheme.secondaryText
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VeilSpacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(section.rawValue))
                    .accessibilityAddTraits(model.selectedSection == section ? .isSelected : [])
                }
            }
            .padding(.horizontal, VeilSpacing.xs)
            .padding(.bottom, VeilSpacing.xxs)
        }
    }
}

/// 白描风格的授权闸门。
///
/// 复用应用锁密码（AppLockController.unlock(pin:)）做身份验证：
/// 只消费既有公开 API，不触碰 keychain、PasswordKDF 等任何密钥/校验面。
/// 未启用应用锁时不允许直接开启，引导先前往“安全 → 应用锁”设置密码。
struct PlainlineUnlockSheet: View {
    @ObservedObject var controller: AppLockController
    var onAuthorized: () -> Void
    var onConfigureLock: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var localError: String?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: VeilSpacing.lg) {
                if controller.isEnabled {
                    unlockForm
                } else {
                    lockRequired
                }
                Spacer()
            }
            .padding(VeilSpacing.lg)
            .background(VeilTheme.background.ignoresSafeArea())
            .navigationTitle("白描授权")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var unlockForm: some View {
        Group {
            VStack(alignment: .leading, spacing: VeilSpacing.xs) {
                Text("输入应用锁密码以启用白描")
                    .font(.headline)
                    .foregroundColor(VeilTheme.text)
                Text("白描是一套极简字排版面：无材质、无阴影，仅留白、发丝线与文字。验证通过后立即切换；切回原来的风格无需再次验证。")
                    .font(.subheadline)
                    .foregroundColor(VeilTheme.secondaryText)
            }
            SecureField("6 位数字密码", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .padding(VeilSpacing.sm)
                .overlay(
                    Rectangle()
                        .fill(VeilTheme.hairline)
                        .frame(height: 0.5)
                        .padding(.horizontal, VeilSpacing.xxs),
                    alignment: .bottom
                )
                .onChange(of: pin) { _ in localError = nil }
            if let message = localError ?? controller.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Button(action: attemptUnlock) {
                Text("验证并切换")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VeilTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VeilSpacing.sm)
            }
            .buttonStyle(.plain)
            .disabled(pin.utf8.count != 6)
            .opacity(pin.utf8.count == 6 ? 1 : 0.45)
        }
    }

    private var lockRequired: some View {
        Group {
            VStack(alignment: .leading, spacing: VeilSpacing.xs) {
                Text("需要先设置应用锁密码")
                    .font(.headline)
                    .foregroundColor(VeilTheme.text)
                Text("白描属于实验风格，需凭密码授权开启。请先在“设置 → 安全 → 应用锁”中设置 6 位数字密码，然后再回来切换。")
                    .font(.subheadline)
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Button {
                dismiss()
                onConfigureLock()
            } label: {
                Text("去设置应用锁")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VeilTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VeilSpacing.sm)
            }
            .buttonStyle(.plain)
        }
    }

    private func attemptUnlock() {
        guard pin.utf8.count == 6, pin.utf8.allSatisfy({ (48...57).contains($0) }) else {
            localError = "请输入 6 位数字。"
            return
        }
        if controller.unlock(pin: pin) {
            localError = nil
            onAuthorized()
            dismiss()
        }
    }
}
