import SwiftUI

struct OwnerUnlockSheet: View {
    @ObservedObject var model: AppModel
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 46))
                    .foregroundColor(VeilTheme.gold)
                Text("OWNER AUTHORIZATION")
                    .font(.system(.headline, design: .monospaced))
                SecureField("主身份账户密码", text: $password)
                    .textFieldStyle(VeilTextFieldStyle())
                if let primary = model.identity.primaryIdentity {
                    Text("主身份：\(primary.displayName) · \(primary.id.prefix(8))")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                if let error = model.ownerMode.lastError {
                    Text(error).font(.footnote).foregroundColor(VeilTheme.danger)
                }
                Button("开启 20 分钟本机授权") {
                    if model.ownerMode.authorizeLocal(password: password, identity: model.identity) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onSuccess() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.gold)
                Spacer()
            }
            .padding(24)
            .background(VeilTheme.background.ignoresSafeArea())
            .navigationTitle("Owner Mode")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
    }
}

struct OwnerConsoleView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ownerMode: OwnerModeController
    @ObservedObject var performanceOverrides: PerformanceOverrideController
    @Environment(\.dismiss) private var dismiss
    @State private var scanProgress: Double = 0

    init(model: AppModel) {
        self.model = model
        ownerMode = model.ownerMode
        performanceOverrides = model.performanceOverrides
    }

    var body: some View {
        NavigationView {
            VeilStableScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    consoleHeader
                    diagnosticCard
                    capabilityCard
                    performanceOverrideCard
                    easterEggCard
                    Text("权限边界：Owner Mode 不读取消息正文、不导出私钥、不绕过其他用户的应用锁。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                        .padding(.top, 8)
                }
            }
            .background(VeilTheme.background)
            .navigationTitle("ROOT OBSERVATORY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("退出") { ownerMode.lock(); dismiss() } }
            }
        }
        .accentColor(VeilTheme.gold)
        .onAppear {
            ownerMode.refreshExpiration()
            if !ownerMode.isUnlocked { dismiss() }
        }
    }

    private var consoleHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AUTHORITY ACCEPTED")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(VeilTheme.gold)
            Text("权限已提升，但隐私仍高于权限。")
                .font(.subheadline)
            if let expires = ownerMode.expiresAt {
                Text("授权失效：\(expires.formatted())")
                    .font(.caption).foregroundColor(VeilTheme.secondaryText)
            }
        }
        .veilCard()
    }

    private var diagnosticCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYSTEM DIAGNOSTICS").font(.system(.subheadline, design: .monospaced)).foregroundColor(VeilTheme.gold)
            consoleRow("SQLite", value: model.database.integrityCheck())
            consoleRow("BLE", value: model.bluetooth.statusText)
            consoleRow("Nodes", value: "\(model.sessions.nearbyPeers.count)")
            consoleRow("Protocol", value: "VL-BLE/4")
            consoleRow("Profile", value: VeilDevicePerformance.diagnosticLabel)
        }
        .veilCard()
    }

    private var capabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CAPABILITIES").font(.system(.subheadline, design: .monospaced)).foregroundColor(VeilTheme.gold)
            capabilityRow("脱敏诊断", capability: .diagnostics)
            capabilityRow("协议参数调试", capability: .protocolTuning)
            capabilityRow("群组成员治理", capability: .groupModeration)
            capabilityRow("用户授权彩蛋", capability: .visualEffects)
        }
        .foregroundColor(VeilTheme.text)
        .veilCard()
    }

    private var performanceOverrideCard: some View {
        let canTune = ownerMode.isAuthorized(for: .protocolTuning)
        let canAnimate = ownerMode.isAuthorized(for: .visualEffects)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THERMAL HERESY")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                    Text("上帝性能台 · 违抗硬件建议，但不违抗加密协议")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Text("\(performanceOverrides.riskCount)/5")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(performanceOverrides.riskCount >= 4 ? VeilTheme.danger : VeilTheme.goldBright)
            }

            Toggle(isOn: $performanceOverrides.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("解除设备封印")
                    Text(performanceOverrides.isEnabled ? "OVERRIDE ARMED · \(performanceOverrides.riskLabel)" : "AUTO POLICY · 设备仍有尊严")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
            .disabled(!canTune)

            Divider().background(Color.white.opacity(0.08))

            godToggle(
                "高清预览越狱",
                subtitle: "把聊天图片预览上限提高到 2048 px；不改变原始附件和传输质量。",
                isOn: $performanceOverrides.highDefinitionPreview,
                enabled: performanceOverrides.isEnabled && canTune
            )
            godToggle(
                "附件缓存贪婪症",
                subtitle: "把发送附件内存缓存放宽到至少 16 MiB；更快重发，也更吃 RAM。",
                isOn: $performanceOverrides.expandedAttachmentCache,
                enabled: performanceOverrides.isEnabled && canTune
            )
            godToggle(
                "关闭刷新合并器",
                subtitle: "消息状态一到就刷新，不再等设备档位的 debounce。响应更直接，CPU 也更直接。",
                isOn: $performanceOverrides.disableRefreshCoalescing,
                enabled: performanceOverrides.isEnabled && canTune
            )
            godToggle(
                "完整动态效果",
                subtitle: "强制使用 Full motion / 30 碎片完整效果；SE1 与 iPhone 7 也不例外。",
                isOn: $performanceOverrides.forceFullVisualEffects,
                enabled: performanceOverrides.isEnabled && canAnimate
            )
            godToggle(
                "永动机许可",
                subtitle: "重新允许雷达和 Link Trace 的持续动画。iOS 15 旧机闪屏风险会回来。",
                isOn: $performanceOverrides.allowPersistentAnimations,
                enabled: performanceOverrides.isEnabled && canAnimate
            )

            HStack(spacing: 10) {
                Button("把散热交给命运") {
                    model.haptics.warning()
                    performanceOverrides.enableChaosPreset()
                }
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.danger)
                .disabled(!canTune || !canAnimate)

                Button("恢复理智") {
                    performanceOverrides.restoreAutomaticPolicy()
                    model.handleMemoryPressure()
                    model.haptics.resolved()
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.gold)
            }

            Text("本面板只覆盖本机性能策略。Protocol 4、Schema V8、密钥与消息内容规则不会因此改变。高风险选项会持久化，直到你手动恢复自动策略。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .veilCard(emphasized: performanceOverrides.isEnabled)
    }

    private func godToggle(
        _ title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        enabled: Bool
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(VeilTheme.gold)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.46)
    }

    private var easterEggCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UNIVERSE DECRYPTION").font(.system(.subheadline, design: .monospaced)).foregroundColor(VeilTheme.gold)
            ProgressView(value: scanProgress).tint(VeilTheme.gold)
            Button("尝试解密宇宙") {
                withAnimation(.easeInOut(duration: 1.8)) { scanProgress = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    model.alertMessage = "权限不足：宇宙启用了端到端加密。"
                    scanProgress = 0
                }
            }
            .buttonStyle(.bordered)
            .disabled(!ownerMode.isAuthorized(for: .visualEffects))
        }
        .veilCard()
    }

    private func capabilityRow(_ title: String, capability: OwnerCapability) -> some View {
        let enabled = ownerMode.isAuthorized(for: capability)
        return Label(title, systemImage: enabled ? "checkmark.circle" : "minus.circle")
            .foregroundColor(enabled ? VeilTheme.text : VeilTheme.secondaryText)
    }

    private func consoleRow(_ name: String, value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).foregroundColor(.green).lineLimit(1)
        }
        .font(.system(.caption, design: .monospaced))
    }
}
