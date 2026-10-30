import SwiftUI

/// The developer stratum of Owner Mode. It exposes only VeilLink's own
/// read-only runtime map and separately unlocks controlled training injection;
/// it does not bypass iOS privacy prompts, the sandbox, encryption or other
/// users' locks.
struct DeveloperModeConsoleView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var ownerMode: OwnerModeController
    @ObservedObject private var gate: DeveloperLearningLabGate
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var message: String?

    init(model: AppModel) {
        self.model = model
        ownerMode = model.ownerMode
        gate = model.developerLearningGate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("DEVELOPER STRATUM")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(VeilTheme.goldBright)
                Text("Owner Mode 的开发者层。只开放 VeilLink 自身的受控训练入口和只读运行时观测；系统隐私授权、沙盒、端到端加密与应用锁边界保持不变。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                runtimeMap
                authorizationCard
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("开发者模式")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard ownerMode.isAuthorized(for: .developerTraining) else { dismiss() }
        }
        .alert("开发者模式", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var runtimeMap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LIVE RUNTIME MAP · READ ONLY")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(VeilTheme.gold)
            runtimeRow("棋谱训练", value: "独立本地 JSON · 写入受开发者门保护")
            runtimeRow("五子棋搜索", value: "威胁评估 + 训练强化候选")
            runtimeRow("中国象棋搜索", value: "Alpha-Beta + 安静搜索 + 训练预判")
            runtimeRow("治理运行时", value: model.activeGovernanceEngineName)
            runtimeRow("隐私边界", value: "iOS 授权与应用沙盒仍生效")
        }
        .veilCard()
    }

    private var authorizationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if gate.isAuthorized {
                Label("开发者训练已授权", systemImage: "checkmark.shield.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(VeilTheme.success)
                Text("五子棋页面已显示“开发训练室”；本次授权在离开应用、Owner Mode 退出或十分钟后失效。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                Button("锁定开发者训练") { gate.lock() }
                    .buttonStyle(.bordered)
            } else {
                Text(gate.isConfigured ? "验证开发者口令" : "初始化开发者口令")
                    .font(.subheadline.weight(.bold))
                Text(gate.isConfigured
                    ? "输入仅你知道的 8 位数字口令。明文不会保存；设备 Keychain 会保存高成本验证器和随机设备秘密。"
                    : "首次仅能在已开启的 Owner Mode 中设置。请自选 8 位数字口令；不要发送给任何人。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                SecureField("8 位数字口令", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(.body, design: .monospaced))
                    .padding(11)
                    .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button(gate.isConfigured ? "验证并开启" : "初始化本机密钥") {
                    let success = gate.isConfigured
                        ? gate.unlock(pin: pin)
                        : gate.configure(pin: pin, appLock: model.appLock)
                    if success {
                        pin = ""
                        model.haptics.resolved()
                    }
                    if let error = gate.errorMessage { message = error }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pin.count != 8)
            }
        }
        .veilCard(emphasized: true)
    }

    private func runtimeRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.caption.weight(.semibold)).foregroundColor(VeilTheme.text)
            Spacer()
            Text(value).font(.caption2.monospaced()).foregroundColor(VeilTheme.secondaryText).multilineTextAlignment(.trailing)
        }
    }
}
