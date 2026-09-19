import SwiftUI
import UIKit

struct DeviceStressTestView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var controller = DeviceStressTestController.shared
    @Environment(\.dismiss) private var dismiss
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
                    Text("测试不会主动删除消息、身份或联系人，不会自动确认配对，不会发送真实聊天/附件，不会改写账号密码。BLE churn 与内存 trim 属于有意施压路径。")
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
