import SwiftUI
import UIKit

struct DeviceStressTestView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var controller = DeviceStressTestController.shared
    @ObservedObject private var collaborative = CollaborativeStressCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCollaborativePeerID = ""
    let onStart: () -> Void

    init(model: AppModel, onStart: @escaping () -> Void = {}) {
        self.model = model
        self.onStart = onStart
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("测试方案", selection: $controller.configuration.preset) {
                        ForEach(DeviceStressPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .onChange(of: controller.configuration.preset) { preset in
                        controller.applyPresetDefaults(preset)
                    }

                    Text(controller.configuration.preset.subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    if controller.configuration.preset != .endurance {
                        Stepper(
                            "循环：\(controller.configuration.requestedCycles)",
                            value: $controller.configuration.requestedCycles,
                            in: 1...10_000,
                            step: controller.configuration.requestedCycles >= 100 ? 25 : 1
                        )
                    } else {
                        HStack {
                            Text("循环")
                            Spacer()
                            Text("直到停止/熔断")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(VeilTheme.gold)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("动作间隔")
                            Spacer()
                            Text("\(controller.configuration.stepDelayMilliseconds) ms")
                                .font(.system(.caption, design: .monospaced))
                        }
                        Slider(
                            value: Binding(
                                get: { Double(controller.configuration.stepDelayMilliseconds) },
                                set: { controller.configuration.stepDelayMilliseconds = Int($0.rounded()) }
                            ),
                            in: 15...1_000,
                            step: 5
                        )
                        .tint(VeilTheme.gold)
                    }
                } header: {
                    Text("DEVICE BURN-IN")
                } footer: {
                    Text("15 ms 是内部状态机允许的最低节拍。实际 Sheet/Modal 会自动给予更长 settle 时间，避免把“动画尚未完成”误判成故障。")
                }

                Section("覆盖模块") {
                    stressToggle(
                        "Sheet / Modal 高频开关",
                        detail: "身份管理、应用锁配置、备份密码页、Agent 诊断页反复呈现/关闭。",
                        isOn: $controller.configuration.exercisePresentations
                    )
                    stressToggle(
                        "BLE 启停与恢复链路",
                        detail: "反复 stop/start/refresh；会短暂中断当前 BLE 会话，但测试结束会恢复原始运行状态。",
                        isOn: $controller.configuration.exerciseBLEChurn
                    )
                    stressToggle(
                        "SQLite 完整性检查",
                        detail: "执行只读完整性检查并同步 A9 存储状态；不改写聊天数据。",
                        isOn: $controller.configuration.exerciseStorageIntegrity
                    )
                    stressToggle(
                        "Agent + MaleCNS",
                        detail: "反复触发本地运行时准备、诊断页、VFLY 载入路径和 compute trim。",
                        isOn: $controller.configuration.exerciseAgentAndMaleCNS
                    )
                    stressToggle(
                        "缓存/内存压力路径",
                        detail: "每 5 轮主动走一次内存告警清理路径；Extreme/Endurance 默认开启。",
                        isOn: $controller.configuration.exerciseMemoryPressure
                    )
                    stressToggle(
                        "每一步抓 UI 结构",
                        detail: "将窗口/控制器路径/可见 View 数等同步写入黑匣子；日志更大但定位更精确。",
                        isOn: $controller.configuration.captureEveryStep
                    )
                }

                Section("协同设备压力") {
                    if let invitation = collaborative.pendingInvitation,
                       let peer = collaborative.pendingInvitationPeerID {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("收到协同压力邀请").font(.headline)
                            Text("设备 \(String(peer.prefix(8)).uppercased()) · CODE \(String(invitation.sessionID.prefix(6)).uppercased())")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(VeilTheme.gold)
                            Text("只进入临时 E2EE Stress Channel；不会写入普通聊天记录。")
                                .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                        }
                        HStack {
                            Button("接收邀请并开始") { collaborative.acceptPendingInvitation() }
                                .buttonStyle(.borderedProminent).tint(VeilTheme.gold)
                            Button("拒绝") { collaborative.declinePendingInvitation() }.buttonStyle(.bordered)
                        }
                    } else {
                        Picker("协同设备", selection: $selectedCollaborativePeerID) {
                            Text("选择设备").tag("")
                            ForEach(model.conversations) { conversation in
                                let secure = model.sessions.hasSecureSession(for: conversation.peerIdentityID)
                                Text("\(conversation.title)\(secure ? " · SECURE" : " · OFFLINE")")
                                    .tag(conversation.peerIdentityID)
                            }
                        }
                        stressToggle("双向高速文字", detail: "synthetic text 走真实加密消息链路，但在 SQLite 入库前截获。", isOn: Binding(get: { collaborative.scenario.enableText }, set: { collaborative.scenario.enableText = $0 }))
                        stressToggle("图片级 bulk", detail: "合成二进制图片负载走真实 attachmentChunk / BLE bulk 队列，不读取相册。", isOn: Binding(get: { collaborative.scenario.enableImages }, set: { collaborative.scenario.enableImages = $0 }))
                        stressToggle("语音级 WAV/PCM bulk", detail: "本地生成 WAV/PCM 风格负载，不开启麦克风、不采集真实语音。", isOn: Binding(get: { collaborative.scenario.enableVoice }, set: { collaborative.scenario.enableVoice = $0 }))
                        stressToggle("临时五子棋协议", detail: "用真实 MiniGameCodec + GomokuState 双机收发，不进入正式对局历史。", isOn: Binding(get: { collaborative.scenario.enableGame }, set: { collaborative.scenario.enableGame = $0 }))
                        HStack {
                            Text("状态"); Spacer()
                            Text(collaborative.state.rawValue.uppercased())
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(collaborative.state == .running ? VeilTheme.success : VeilTheme.secondaryText)
                        }
                        if collaborative.metrics.sentFrames > 0 || collaborative.metrics.receivedFrames > 0 {
                            Text("TX \(collaborative.metrics.sentFrames) / RX \(collaborative.metrics.receivedFrames) · drop \(collaborative.metrics.droppedFrames) · backpressure \(collaborative.metrics.temporaryUnavailableCount) · bulk ok \(collaborative.metrics.bulkTransfersVerified) · game \(collaborative.metrics.gamePacketsReceived)")
                                .font(.caption2.monospacedDigit()).foregroundColor(VeilTheme.secondaryText)
                        }
                        HStack {
                            Button("发送协同邀请") {
                                collaborative.attach(model: model)
                                collaborative.invite(peerIdentityID: selectedCollaborativePeerID)
                            }
                            .buttonStyle(.borderedProminent).tint(VeilTheme.gold)
                            .disabled(selectedCollaborativePeerID.isEmpty || collaborative.state == .running || collaborative.state == .inviting)
                            if collaborative.state == .running || collaborative.state == .ready || collaborative.state == .inviting {
                                Button("停止协同", role: .destructive) { collaborative.stop(reason: "user_stop") }.buttonStyle(.bordered)
                            }
                        }
                    }
                } header: {
                    Text("TEMP E2EE STRESS CHANNEL")
                } footer: {
                    Text("双方必须先完成普通 VeilLink 信任与 Secure Session。邀请不会自动配对，也不会自动开始；旧版本可能把兼容压力帧显示成普通测试文本，因此协同测试应使用同一 I11 构建。")
                }

                Section("安全熔断") {
                    safetyRow("温度", value: thermalText, icon: "thermometer.medium")
                    safetyRow("电量", value: batteryText, icon: "battery.50")
                    safetyRow("前台", value: UIApplication.shared.applicationState == .active ? "ACTIVE" : "NOT ACTIVE", icon: "iphone")
                    Text("达到 critical thermal、未充电且电量低于 5%、离开前台，或连续收到 2 次真实内存警告时自动停止。Serious thermal 会自动插入 2 秒降速窗口。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }

                Section {
                    Button {
                        RuntimeDiagnosticsBridge.shared.recordSemanticAction(
                            "owner.stress.start",
                            metadata: [
                                "preset": controller.configuration.preset.rawValue,
                                "cycles": String(controller.configuration.requestedCycles),
                                "delay_ms": String(controller.configuration.stepDelayMilliseconds)
                            ]
                        )
                        controller.start(model: model)
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onStart() }
                    } label: {
                        HStack {
                            Image(systemName: "bolt.horizontal.circle.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("开始真机压力测试")
                                    .fontWeight(.semibold)
                                Text("启动后自动返回主界面，右上角保留 STOP / PAUSE HUD")
                                    .font(.caption2)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VeilTheme.gold)
                    .disabled(controller.isRunning)
                    .accessibilityIdentifier("owner.stress.start")
                } footer: {
                    Text("本机 Burn-In 不发送真实聊天。协同模式只发送 synthetic 临时压力帧/二进制负载；不读取真实聊天正文、相册、麦克风、密钥或 Prompt。BLE churn 与内存 trim 属于有意施压路径。")
                }
            }
            .navigationTitle("真机压力测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            collaborative.attach(model: model)
            if selectedCollaborativePeerID.isEmpty {
                selectedCollaborativePeerID = model.conversations.first(where: { model.sessions.hasSecureSession(for: $0.peerIdentityID) })?.peerIdentityID ?? ""
            }
        }
        .telemetryScreen("owner.stress.configure")
    }

    @ViewBuilder
    private func stressToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .tint(VeilTheme.gold)
    }

    private func safetyRow(_ title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
        }
    }

    private var thermalText: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "NOMINAL"
        case .fair: return "FAIR"
        case .serious: return "SERIOUS"
        case .critical: return "CRITICAL"
        @unknown default: return "UNKNOWN"
        }
    }

    private var batteryText: String {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return "UNKNOWN" }
        return "\(Int((level * 100).rounded()))%"
    }
}

struct DeviceStressTestHUD: View {
    @ObservedObject var controller: DeviceStressTestController

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(controller.isPaused ? VeilTheme.gold : VeilTheme.success)
                    .frame(width: 7, height: 7)
                Text(controller.isPaused ? "BURN-IN PAUSED" : "BURN-IN RUNNING")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                Spacer(minLength: 4)
                Text(controller.sessionID)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
            }

            Text("C\(controller.currentCycle) · #\(controller.completedSteps) · \(controller.currentStep)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            HStack(spacing: 7) {
                Text("P\(controller.passedSteps)")
                    .foregroundColor(VeilTheme.success)
                Text("S\(controller.skippedSteps)")
                    .foregroundColor(VeilTheme.gold)
                Text("F\(controller.failedSteps)")
                    .foregroundColor(controller.failedSteps > 0 ? VeilTheme.danger : VeilTheme.secondaryText)
                Text(String(format: "%.1fs", controller.elapsedSeconds))
                    .foregroundColor(VeilTheme.secondaryText)
                Spacer()
            }
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))

            HStack(spacing: 8) {
                Button(controller.isPaused ? "继续" : "暂停") {
                    controller.togglePause()
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.gold)
                .controlSize(.mini)

                Button("STOP", role: .destructive) {
                    controller.stop(reason: "user_stop")
                }
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.danger)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .frame(width: 245)
        .background(VeilTheme.elevated.opacity(0.96))
        .clipShape(VeilPanelShape(cut: 10, radius: 6))
        .overlay(VeilPanelShape(cut: 10, radius: 6).stroke(VeilTheme.gold.opacity(0.28), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.35), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stress.hud")
    }
}
