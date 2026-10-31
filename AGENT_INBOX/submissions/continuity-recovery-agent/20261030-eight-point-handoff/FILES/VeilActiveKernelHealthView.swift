import SwiftUI

/// Active-core presentation. Does not borrow frozen A9 data when only A10 is
/// evaluating. Staleness is scoped to both the runtime mode and its session.
struct VeilActiveKernelHealthView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var ultra: A10UltraOmegaShadowCoordinator

    init(model: AppModel) {
        self.model = model
        _ultra = ObservedObject(wrappedValue: model.a10Ultra)
    }

    var body: some View {
        let sample = ultra.lastRuntimeSample
        let eligible = sample?.environment.modeSessionID == model.kernelRuntime.modeSessionID &&
            sample?.environment.mode == model.kernelRuntime.mode &&
            abs(sample?.timestamp.timeIntervalSinceNow ?? .infinity) <= 30
        return VStack(alignment: .leading, spacing: 12) {
            Label("A10 Ultra Ω · 实时监测", systemImage: "cpu")
                .font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
            if eligible, let sample, let decision = sample.ultraDecision,
               let budget = sample.ultraBudget {
                Text("本模式样本 " + String(sample.sampleID.prefix(8)).uppercased())
                    .font(.caption.monospaced()).foregroundColor(VeilTheme.secondaryText)
                HStack(spacing: 8) {
                    metric("健康", "\(decision.healthScore)")
                    metric("状态", decision.light)
                    metric("风险", "\(decision.riskBasisPoints)")
                }
                HStack(spacing: 8) {
                    metric("CPU", "\(budget.cpuPct)%")
                    metric("语言", "\(budget.languagePct)%")
                    metric("A10 延迟", "\(sample.ultraLatencyNanos / 1_000_000)ms")
                }
            } else {
                Label("等待 A10 当前模式的新采样，暂不展示过期 A9 健康数据。", systemImage: "clock")
                    .font(.footnote).foregroundColor(VeilTheme.secondaryText)
            }
            Text("运行模式：\(model.kernelRuntime.mode.title)。治理观察不授予数据/密钥/网络修改权限。")
                .font(.caption2).foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard()
    }

    private func metric(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.caption2).foregroundColor(VeilTheme.secondaryText)
            Text(value).font(.caption.monospacedDigit()).foregroundColor(VeilTheme.text)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
