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
                    let success = model.ownerMode.authorizeLocal(password: password, identity: model.identity)
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction(
                        "owner.authorize_local",
                        metadata: ["success": String(success)]
                    )
                    if success {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onSuccess() }
                    }
                }
                .accessibilityIdentifier("owner.authorize_local")
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.gold)
                Spacer()
            }
            .padding(24)
            .background(VeilTheme.background.ignoresSafeArea())
            .navigationTitle("Owner Mode")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
        }
        .telemetryScreen("owner.unlock")
    }
}

struct OwnerConsoleView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ownerMode: OwnerModeController
    @ObservedObject var performanceOverrides: PerformanceOverrideController
    @ObservedObject var diagnostics: DiagnosticLogStore
    @ObservedObject var telemetry: DeepTelemetry
    @ObservedObject var stressTest: DeviceStressTestController
    @Environment(\.dismiss) private var dismiss
    @State private var scanProgress: Double = 0
    @State private var diagnosticExportURL: URL?
    @State private var stressExportURL: URL?
    @State private var showsClearDiagnosticsConfirmation = false
    @State private var showsStressConfiguration = false

    init(model: AppModel) {
        self.model = model
        ownerMode = model.ownerMode
        performanceOverrides = model.performanceOverrides
        diagnostics = DiagnosticLogStore.shared
        telemetry = DeepTelemetry.shared
        stressTest = DeviceStressTestController.shared
    }

    var body: some View {
        NavigationView {
            VeilStableScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    consoleHeader
                    diagnosticCard
                    deepTelemetryCard
                    deviceStressCard
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("退出") {
                        RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.exit")
                        ownerMode.lock()
                        dismiss()
                    }
                }
            }
        }
        .accentColor(VeilTheme.gold)
        .onAppear {
            ownerMode.refreshExpiration()
            RuntimeDiagnosticsBridge.shared.captureIncidentSnapshot(for: model, reason: "owner.console.appear")
            if !ownerMode.isUnlocked { dismiss() }
        }
        .sheet(isPresented: Binding(
            get: { diagnosticExportURL != nil },
            set: { if !$0 { diagnosticExportURL = nil } }
        )) {
            if let url = diagnosticExportURL {
                DiagnosticsExportShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showsStressConfiguration) {
            DeviceStressTestView(model: model) {
                showsStressConfiguration = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    ownerMode.lock()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { stressExportURL != nil },
            set: { if !$0 { stressExportURL = nil } }
        )) {
            if let url = stressExportURL {
                DiagnosticsExportShareSheet(items: [url])
            }
        }
        .confirmationDialog(
            "清空 Deep Telemetry？",
            isPresented: $showsClearDiagnosticsConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) {
                RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.telemetry.clear")
                diagnostics.clear()
                model.haptics.selection()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删除本机诊断事件，不会删除聊天、身份、附件或备份。")
        }
        .telemetryScreen("owner.console")
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


    private var deepTelemetryCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DEEP TELEMETRY")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                    Text("黑匣子 · UI / BLE / Runtime / Device 全链路")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Text("\(diagnostics.recentEntries.count)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(VeilTheme.goldBright)
            }

            HStack(spacing: 8) {
                telemetryMetric("磁盘", diagnostics.diskUsageText)
                telemetryMetric("上限", diagnostics.retentionText)
                telemetryMetric("会话", diagnostics.runtimeSessionID)
            }

            NavigationLink {
                DiagnosticsLogView(store: diagnostics)
            } label: {
                HStack {
                    Image(systemName: "waveform.path.ecg.rectangle")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("打开完整时间线")
                            .fontWeight(.semibold)
                        Text("UI 点击/手势/显示、输入生命周期、链路、Agent、A9、系统状态")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
            }
            .buttonStyle(VeilPressStyle())
            .accessibilityIdentifier("owner.telemetry.timeline")

            Divider().background(Color.white.opacity(0.08))

            Toggle(isOn: $telemetry.rawTouchCaptureEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("全量 UI 触摸黑匣子")
                    Text("记录每次点击/滑动的坐标、命中 View 类型、层级路径与 accessibility ID；不抓取任意 UI 文本。")
                        .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
            .onChange(of: telemetry.rawTouchCaptureEnabled) { value in
                RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.telemetry.raw_touch", metadata: ["enabled": String(value)])
            }

            Toggle(isOn: $telemetry.inputLifecycleCaptureEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("输入控件生命周期")
                    Text("记录聚焦、结束、键盘类型和字符长度；永远不记录输入内容。")
                        .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
            .onChange(of: telemetry.inputLifecycleCaptureEnabled) { value in
                RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.telemetry.input", metadata: ["enabled": String(value)])
            }

            Toggle(isOn: $telemetry.postInteractionSnapshotsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("交互后 UI 结构快照")
                    Text("每次操作后采样窗口、控制器路径、可见 View 数量和第一响应者，不截图、不 OCR。")
                        .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
            .onChange(of: telemetry.postInteractionSnapshotsEnabled) { value in
                RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.telemetry.ui_snapshot", metadata: ["enabled": String(value)])
            }

            Toggle(isOn: $telemetry.performanceWatchEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("主线程卡顿与系统快照")
                    Text("检测约 350 ms 以上的主线程延迟，并周期记录温度、低电量、屏幕、设备与磁盘状态。")
                        .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
            .onChange(of: telemetry.performanceWatchEnabled) { value in
                RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.telemetry.performance", metadata: ["enabled": String(value)])
            }

            Divider().background(Color.white.opacity(0.08))

            HStack(spacing: 10) {
                Button("立即抓取状态") {
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.telemetry.capture_now")
                    RuntimeDiagnosticsBridge.shared.captureIncidentSnapshot(for: model, reason: "owner.manual_snapshot")
                    model.haptics.selection()
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.gold)
                .accessibilityIdentifier("owner.telemetry.capture_now")

                Button("导出黑匣子") {
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.telemetry.export")
                    do {
                        diagnosticExportURL = try RuntimeDiagnosticsBridge.shared.exportBundle(for: model)
                        model.haptics.resolved()
                    } catch {
                        model.alertMessage = "导出诊断包失败：\(error.localizedDescription)"
                        model.haptics.error()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.gold)
                .accessibilityIdentifier("owner.telemetry.export")
            }

            Button(role: .destructive) {
                showsClearDiagnosticsConfirmation = true
            } label: {
                Label("清空本机黑匣子", systemImage: "trash")
            }
            .accessibilityIdentifier("owner.telemetry.clear")

            Text("Deep Telemetry 持续在本机记录，以保留故障发生前的上下文，但读取/导出入口只放在 Owner Mode。允许记录 Device ID、IDFV、Identity ID、BLE UUID、Conversation ID 等技术标识；仍禁止记录消息正文、输入文本、图片内容、密码/PIN、私钥、会话密钥、配对码和 AI Prompt。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .veilCard(emphasized: true)
    }

    private func telemetryMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.tertiaryText)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.035))
        .clipShape(VeilPanelShape(cut: 6, radius: 4))
    }


    private var deviceStressCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DEVICE BURN-IN")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                    Text("真机自动巡检 / UI 高频操作 / 运行时压力测试")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Text(stressTest.isRunning ? "RUN" : (stressTest.lastSummary == nil ? "IDLE" : "DONE"))
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(stressTest.isRunning ? VeilTheme.success : VeilTheme.goldBright)
            }

            if stressTest.isRunning {
                HStack(spacing: 8) {
                    telemetryMetric("循环", String(stressTest.currentCycle))
                    telemetryMetric("步骤", String(stressTest.completedSteps))
                    telemetryMetric("失败", String(stressTest.failedSteps))
                }
                Text(stressTest.currentStep)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Button(stressTest.isPaused ? "继续" : "暂停") {
                        stressTest.togglePause()
                    }
                    .buttonStyle(.bordered)
                    .tint(VeilTheme.gold)

                    Button("停止测试", role: .destructive) {
                        stressTest.stop(reason: "owner_stop")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VeilTheme.danger)
                }
            } else {
                Button {
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.stress.configure")
                    showsStressConfiguration = true
                } label: {
                    HStack {
                        Image(systemName: "bolt.horizontal.circle")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("配置并启动真机压力测试")
                                .fontWeight(.semibold)
                            Text("快速巡检 / 标准压力 / 极速轰炸 / 持续烧机")
                                .font(.caption2)
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
                .buttonStyle(VeilPressStyle())
                .disabled(!ownerMode.isAuthorized(for: .diagnostics))
                .accessibilityIdentifier("owner.stress.configure")
            }

            if let summary = stressTest.lastSummary {
                Divider().background(Color.white.opacity(0.08))
                HStack(spacing: 8) {
                    telemetryMetric("结果", summary.stopReason)
                    telemetryMetric("P/S/F", "\(summary.passedSteps)/\(summary.skippedSteps)/\(summary.failedSteps)")
                    telemetryMetric("轮数", String(summary.completedCycles))
                }
            }

            if let url = stressTest.lastExportURL, !stressTest.isRunning {
                Button {
                    stressExportURL = url
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.stress.share_last")
                } label: {
                    Label("分享最近压力测试包", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.gold)
                .accessibilityIdentifier("owner.stress.share")
            }

            Text("测试在 VeilLink 内部驱动真实页面状态并反复运行安全功能路径。不会伪造系统级触摸去控制其他 App，也不会主动删消息/身份、确认配对或发送真实聊天。若测试途中崩溃/被系统终止，下次启动会把上一 stress session 标记为 INCOMPLETE。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .veilCard(emphasized: stressTest.isRunning)
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
            .onChange(of: performanceOverrides.isEnabled) { value in
                RuntimeDiagnosticsBridge.shared.recordSemanticAction(
                    "owner.performance_override",
                    metadata: ["enabled": String(value)]
                )
            }

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
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.performance.chaos_preset")
                    model.haptics.warning()
                    performanceOverrides.enableChaosPreset()
                }
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.danger)
                .disabled(!canTune || !canAnimate)

                Button("恢复理智") {
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.performance.restore_auto")
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
        .onChange(of: isOn.wrappedValue) { value in
            RuntimeDiagnosticsBridge.shared.recordSemanticAction(
                "owner.god_toggle",
                metadata: ["name": title, "enabled": String(value)]
            )
        }
    }

    private var easterEggCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UNIVERSE DECRYPTION").font(.system(.subheadline, design: .monospaced)).foregroundColor(VeilTheme.gold)
            ProgressView(value: scanProgress).tint(VeilTheme.gold)
            Button("尝试解密宇宙") {
                RuntimeDiagnosticsBridge.shared.recordSemanticAction("owner.easter_egg.universe")
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
