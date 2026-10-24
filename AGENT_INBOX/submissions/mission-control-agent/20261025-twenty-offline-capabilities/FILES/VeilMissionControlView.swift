import SwiftUI

/// This screen is explicitly an offline, simulated analysis lab until real
/// telemetry adapters and device-specific privacy gates are separately approved.
struct VeilMissionControlView: View {
    @State private var scenario: VeilMissionScenario = .healthy
    @State private var onlyWarnings = false
    private let sections = ["链路与路由", "传输与恢复", "可靠性与隐私", "设备与诊断"]

    private var findings: [VeilMissionFinding] {
        let all = VeilMissionControlEngine.analyzeAll(scenario.snapshot)
        return onlyWarnings ? all.filter { $0.severity != .normal } : all
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    Label("MISSION CONTROL / LOCAL LAB", systemImage: "waveform.path.ecg.rectangle")
                        .font(.caption.monospaced().weight(.bold))
                    Text("20 项离线决策引擎").font(.title2.weight(.bold))
                    Text("当前运行的是内置模拟样本，不会读取真实聊天、密钥或设备日志，也不会修改传输队列。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.10)))

                Picker("模拟场景", selection: $scenario) {
                    ForEach(VeilMissionScenario.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("missionControl.scenario")

                Toggle("只看异常与建议", isOn: $onlyWarnings)
                    .accessibilityIdentifier("missionControl.onlyWarnings")

                ForEach(sections, id: \.self) { group in
                    let entries = findings.filter { $0.feature.group == group }
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group).font(.headline).padding(.bottom, 2)
                            ForEach(entries) { item in
                                DisclosureGroup {
                                    Text(item.explanation)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 6)
                                } label: {
                                    HStack(alignment: .center, spacing: 10) {
                                        Image(systemName: symbol(for: item.severity))
                                            .foregroundColor(tint(for: item.severity))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.feature.title).font(.subheadline.weight(.semibold))
                                            Text(item.headline).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer(minLength: 8)
                                        Text(item.value)
                                            .font(.caption.monospacedDigit())
                                            .multilineTextAlignment(.trailing)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.08)))
                                .accessibilityIdentifier("missionControl.\(item.feature.rawValue)")
                            }
                        }
                    }
                }
                Text("架构：零数据库迁移 · 零网络请求 · 不改变现有 Wire v4 / A9 / A10。真实诊断接入须经过独立安全与隐私验收。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
            .padding(16)
        }
        .navigationTitle("任务控制中心")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func symbol(for severity: VeilMissionSeverity) -> String {
        switch severity {
        case .normal: return "checkmark.circle"
        case .caution: return "exclamationmark.triangle"
        case .blocked: return "xmark.octagon"
        }
    }

    private func tint(for severity: VeilMissionSeverity) -> Color {
        switch severity {
        case .normal: return .green
        case .caution: return .orange
        case .blocked: return .red
        }
    }
}
