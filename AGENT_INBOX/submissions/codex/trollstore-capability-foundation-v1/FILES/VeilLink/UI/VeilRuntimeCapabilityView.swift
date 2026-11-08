import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct VeilRuntimeCapabilityView: View {
    let snapshot: VeilRuntimeEnvironmentSnapshot
    @State private var copied = false

    init(snapshot: VeilRuntimeEnvironmentSnapshot = VeilRuntimeEnvironment.current) {
        self.snapshot = snapshot
    }

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 14) {
                heroCard
                capabilityCard
                safetyCard
                diagnosticsCard
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("运行环境")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(statusColor.opacity(0.14)).frame(width: 52, height: 52)
                    Image(systemName: snapshot.isTrollStore ? "bolt.shield.fill" : "checkmark.shield.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.channel.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(snapshot.profile.title)
                        .font(VeilType.terminalLabel)
                        .foregroundColor(VeilTheme.mutedGold)
                }
                Spacer()
                Text("AUTO")
                    .font(VeilType.terminalLabel)
                    .foregroundColor(VeilTheme.success)
            }
            Text(snapshot.confidence)
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            Text("VeilLink 会按实际安装证据自动选择兼容档位，不会仅凭包名假定高权限。")
                .font(.caption)
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard(emphasized: snapshot.isTrollStore)
    }

    private var capabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("能力矩阵", systemImage: "switch.2")
                .font(VeilType.cardTitle)
                .foregroundColor(VeilTheme.goldBright)
            ForEach(snapshot.capabilities) { capability in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(color(for: capability.state))
                        .frame(width: 7, height: 7)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(capability.title).font(.subheadline.weight(.semibold))
                        Text(capability.detail)
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Text(capability.state.title)
                        .font(VeilType.terminalLabel)
                        .foregroundColor(color(for: capability.state))
                }
                .padding(.vertical, 3)
            }
        }
        .veilCard()
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("增强模式边界", systemImage: "lock.shield.fill")
                .font(VeilType.cardTitle)
                .foregroundColor(VeilTheme.goldBright)
            boundary("来源识别不等于权限验证")
            boundary("每项增强能力单独探测、单独启用、失败即回退")
            boundary("不会自动读取沙盒外文件，也不会静默扩大数据范围")
            boundary("普通签名包始终保持完整基础聊天与传输能力")
        }
        .veilCard()
    }

    private var diagnosticsCard: some View {
        Button {
            UIPasteboard.general.setItems(
                [[UTType.plainText.identifier: snapshot.diagnosticsReport]],
                options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(300)]
            )
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(copied ? VeilTheme.success : VeilTheme.goldBright)
                VStack(alignment: .leading, spacing: 3) {
                    Text(copied ? "已复制能力报告" : "复制能力报告")
                        .font(.headline)
                        .foregroundColor(VeilTheme.text)
                    Text("不含文件路径、身份、消息或密钥；仅在本机剪贴板保留 5 分钟。")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
            }
        }
        .buttonStyle(VeilPressStyle())
        .veilCard()
    }

    private func boundary(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.caption)
            .foregroundColor(VeilTheme.secondaryText)
    }

    private var statusColor: Color {
        snapshot.isTrollStore ? VeilTheme.goldBright : VeilTheme.success
    }

    private func color(for state: VeilCapabilityState) -> Color {
        switch state {
        case .available: return VeilTheme.success
        case .declared: return VeilTheme.goldBright
        case .candidate: return VeilTheme.gold
        case .unavailable: return VeilTheme.tertiaryText
        }
    }
}
