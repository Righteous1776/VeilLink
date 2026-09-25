import SwiftUI

struct VeilBackgroundContinuitySettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var continuity = VeilBackgroundContinuityCenter.shared

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("后台连续性", systemImage: "wave.3.right.circle.fill")
                        .font(.headline)
                        .foregroundColor(VeilTheme.goldBright)
                    Text(continuity.statusText)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("目标是把 Apple 允许的后台能力叠加起来，而不是伪造前台。后台仍由 iOS 调度，用户强制退出 App 后不能继续运行。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                .veilCard(emphasized: true)
                .veilDynamicGlow(active: continuity.continuityEnabled, emphasized: true)

                VStack(alignment: .leading, spacing: 14) {
                    Toggle("启用后台连续性", isOn: Binding(
                        get: { continuity.continuityEnabled },
                        set: { continuity.continuityEnabled = $0 }
                    ))
                    .tint(VeilTheme.gold)

                    Toggle("锁屏 / 灵动岛实时状态", isOn: Binding(
                        get: { continuity.liveActivityEnabled },
                        set: { continuity.liveActivityEnabled = $0 }
                    ))
                    .tint(VeilTheme.gold)
                    .disabled(!continuity.supportsLiveActivity)

                    Toggle("LAN P2P Boost", isOn: $model.lanTurbo.peerToPeerBoostEnabled)
                        .tint(VeilTheme.gold)

                    Toggle("允许 Mesh 中继", isOn: $model.meshRouter.relayEnabled)
                        .tint(VeilTheme.gold)

                    Divider().background(VeilTheme.hairline)
                    Button {
                        continuity.refreshNow()
                        model.haptics.selection()
                    } label: {
                        Label("立即刷新后台链路", systemImage: "arrow.clockwise.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(VeilPressStyle())
                }
                .veilCard()

                VStack(alignment: .leading, spacing: 9) {
                    backgroundRow("CoreBluetooth 后台", value: "已启用")
                    backgroundRow("Central / Peripheral State Restoration", value: "已启用")
                    backgroundRow("有限后台收尾窗口", value: "已启用")
                    backgroundRow("BGAppRefresh", value: UIApplication.shared.backgroundRefreshStatus == .available ? "系统允许" : "系统未允许")
                    backgroundRow("Live Activity", value: continuity.supportsLiveActivity ? (continuity.liveActivityActive ? "运行中" : "可用") : "系统不支持")
                    backgroundRow("LAN / Mesh 常驻", value: "不保证 · BLE 优先保活")
                }
                .veilCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("边界")
                        .font(.headline)
                        .foregroundColor(VeilTheme.goldBright)
                    Text("• iPhone 7 / iOS 15：依靠 CoreBluetooth 后台事件、状态恢复和有限后台任务。")
                    Text("• iOS 16.1+：增加 Live Activity 作为锁屏可见入口。")
                    Text("• iOS 26+：Live Activity + 已实例化 CBManager 可获得更接近前台的 CoreBluetooth 后台权限。")
                    Text("• 画中画只用于真实视频；不会播放静音音频或伪造视频来骗取后台执行。")
                    Text("• 用户从多任务界面强制退出后，iOS 不允许 App 绕过系统继续运行。")
                }
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
                .veilCard()
            }
            .padding(.bottom, 16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("后台连续性")
        .onAppear { continuity.attach(to: model) }
    }

    private func backgroundRow(_ title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundColor(VeilTheme.text)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(VeilTheme.mutedGold)
        }
    }
}
