import SwiftUI

struct VeilInternetRelaySettingsView: View {
    @ObservedObject var relay: InternetRelayTransport
    @ObservedObject private var settings = VeilRelaySettings.shared
    @ObservedObject var model: AppModel

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Internet Relay", systemImage: "network")
                            .font(.headline)
                            .foregroundColor(VeilTheme.goldBright)
                        Spacer()
                        Text(relay.connectedPeerCount > 0 ? "ACTIVE" : "IDLE")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(relay.connectedPeerCount > 0 ? VeilTheme.success : VeilTheme.tertiaryText)
                    }
                    Text("远距离通道只搬运额外封装后的密文。首次信任既可以通过近距六码完成，也可以使用 60 秒一次性远程二维码 + 双方六码确认。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    Toggle("启用远距离中继", isOn: $settings.enabled)
                        .onChange(of: settings.enabled) { _ in refresh() }
                    Picker("路由策略", selection: $settings.mode) {
                        ForEach(VeilRelayMode.allCases) { mode in Text(mode.title).tag(mode) }
                    }
                    .pickerStyle(.menu)
                }
                .veilCard(emphasized: settings.enabled)

                NavigationLink(destination: VeilRemotePairingView(pairing: model.remotePairing, model: model)) {
                    HStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(VeilTheme.goldBright)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("60 秒远程二维码配对").font(.headline).foregroundColor(VeilTheme.text)
                            Text("保存图片 → 微信发送 → 对方从照片导入 → 双方核对六码")
                                .font(.caption).foregroundColor(VeilTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(VeilTheme.tertiaryText)
                    }
                }
                .buttonStyle(VeilPressStyle())
                .veilCard(emphasized: model.remotePairing.isOffering || model.remotePairing.candidate != nil)

                providerCard(region: .domestic, title: "国内通道", subtitle: "推荐：腾讯 CloudBase HTTP 云函数 / 云托管")
                providerCard(region: .international, title: "国际通道", subtitle: "推荐：Cloudflare Workers + Durable Objects")

                VStack(alignment: .leading, spacing: 10) {
                    Label("隐私与双发规则", systemImage: "lock.shield")
                        .font(.headline)
                        .foregroundColor(VeilTheme.goldBright)
                    Text("智能双通道仅对小型控制/聊天帧并行竞速；大附件选择当前 RTT 最优通道，失败后由持久发送队列切换。国内和国际提供商使用不同 mailbox、token 与外层加密密钥，降低跨提供商直接关联。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    HStack {
                        Text("离线密文 TTL")
                        Spacer()
                        Text("\(Int(settings.messageTTLHours)) 小时")
                            .font(.caption.monospaced())
                    }
                    Slider(value: $settings.messageTTLHours, in: 1...168, step: 1)
                }
                .veilCard()

                Button {
                    relay.refreshNow()
                    model.haptics.selection()
                } label: {
                    Label("立即探测双通道", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VeilPressStyle())
                .veilCard()
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("远程中继")
        .onDisappear { refresh() }
    }

    @ViewBuilder
    private func providerCard(region: VeilRelayRegion, title: String, subtitle: String) -> some View {
        let snapshot = relay.providerSnapshots[region]
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption2).foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Circle()
                    .fill(snapshot?.reachable == true ? VeilTheme.success : VeilTheme.tertiaryText)
                    .frame(width: 8, height: 8)
            }
            TextField(
                region == .domestic ? "https://你的国内 Relay Endpoint" : "https://你的国际 Relay Endpoint",
                text: region == .domestic ? $settings.domesticEndpoint : $settings.internationalEndpoint
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .font(.caption.monospaced())
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            if let ms = snapshot?.roundTripMilliseconds {
                Text(String(format: "RTT %.0f ms · failure %d", ms, snapshot?.consecutiveFailures ?? 0))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
            }
        }
        .veilCard(emphasized: snapshot?.reachable == true)
    }

    private func refresh() {
        if settings.enabled {
            relay.start(peerIdentityIDs: model.conversations.map(\.peerIdentityID))
            relay.refreshNow()
        } else {
            relay.stop(reason: "远程中继已关闭")
        }
    }
}
