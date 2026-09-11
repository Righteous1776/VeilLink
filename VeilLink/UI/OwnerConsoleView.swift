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
    @Environment(\.dismiss) private var dismiss
    @State private var scanProgress: Double = 0

    init(model: AppModel) {
        self.model = model
        ownerMode = model.ownerMode
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    consoleHeader
                    diagnosticCard
                    capabilityCard
                    easterEggCard
                    Text("权限边界：Owner Mode 不读取消息正文、不导出私钥、不绕过其他用户的应用锁。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                        .padding(.top, 8)
                }
                .frame(maxWidth: 760)
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(VeilTheme.background.ignoresSafeArea())
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
