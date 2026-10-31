import SwiftUI

/// Read-only surface. Diagnostic capture and file integrity verification
/// remain owned by their existing engines; this view never initiates scans.
struct VeilBackgroundGovernanceStatusView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var a10: A10UltraOmegaShadowCoordinator

    init(model: AppModel) {
        self.model = model
        _a10 = ObservedObject(wrappedValue: model.a10Ultra)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Label("后台治理状态", systemImage: "checkmark.shield")
                    .font(.title3.bold())
                Text("诊断、链路采样和完整性工作由各自的引擎负责。此页面只显示状态，不会自行读取文件或修改设备。")
                    .font(.footnote).foregroundColor(.secondary)
                status("蓝牙", model.bluetooth.statusText)
                status("附近设备", "\(model.sessions.nearbyPeers.count)")
                status("本地数据库", model.a9Health.databaseIntegrity.title)
                status("内核", model.kernelRuntime.mode.title)
                let activeA10 = model.kernelRuntime.mode == .a10OnlyLab ||
                    model.kernelRuntime.mode == .a10Independent
                if activeA10 {
                    let sample = a10.lastRuntimeSample
                    let valid = sample?.environment.modeSessionID == model.kernelRuntime.modeSessionID &&
                        sample?.environment.mode == model.kernelRuntime.mode &&
                        abs(sample?.timestamp.timeIntervalSinceNow ?? .infinity) <= 30
                    status("A10 实时样本", valid ? String(sample!.sampleID.prefix(8)) : "等待新样本")
                } else {
                    status("A9 状态", model.a9Health.decision.light.title)
                }
                Text("文件完整性不能凭空自动判断：只有用户明确选择文件后才可计算 SHA-256。后台不会擅自读取 iCloud Drive 或私人文档。")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(16)
        }
        .navigationTitle("运行状态")
    }

    private func status(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary).lineLimit(2)
        }
        .font(.subheadline)
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
