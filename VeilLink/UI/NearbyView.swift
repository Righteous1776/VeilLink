import SwiftUI

struct NearbyView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var bluetooth: BLETransport
    @ObservedObject var sessions: SessionCoordinator

    init(model: AppModel) {
        self.model = model
        bluetooth = model.bluetooth
        sessions = model.sessions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(VeilTheme.gold.opacity(0.18), lineWidth: 10).frame(width: 78, height: 78)
                        Circle().fill(VeilTheme.gold).frame(width: 12, height: 12)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(bluetooth.statusText).font(.headline)
                        Text("仅广播匿名服务标识，身份资料在握手后加密交换。")
                            .font(.footnote)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    Spacer()
                }
                .veilCard()

                if sessions.nearbyPeers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(VeilTheme.gold)
                        Text("等待附近的 VeilLink 设备")
                        Text("两台设备都应保持应用前台运行")
                            .font(.footnote)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 54)
                } else {
                    ForEach(sessions.nearbyPeers) { peer in
                        NearbyPeerCard(model: model, peer: peer)
                    }
                }
            }
            .frame(maxWidth: 760)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(VeilTheme.background)
        .navigationTitle("附近设备")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(bluetooth.isRunning ? "暂停" : "扫描") {
                    bluetooth.isRunning ? bluetooth.stop() : bluetooth.start()
                }
            }
        }
    }
}

private struct NearbyPeerCard: View {
    @ObservedObject var model: AppModel
    let peer: NearbyPeer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.displayName).font(.headline)
                    Text(signalDescription).font(.footnote).foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Text(trustLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(peer.trustState == .trusted ? .green : (peer.trustState == .blocked ? .red : VeilTheme.gold))
            }

            if peer.trustState == .blocked {
                Text("该身份已在本机黑名单中。")
                    .font(.footnote)
                    .foregroundColor(VeilTheme.danger)
            } else if let code = peer.pairingCode {
                VStack(spacing: 6) {
                    Text("核对双方屏幕上的六码")
                        .font(.footnote)
                        .foregroundColor(VeilTheme.secondaryText)
                    Text(code)
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .tracking(7)
                    HStack {
                        Button("不是这台设备", role: .destructive) { model.sessions.rejectPairing(peerID: peer.id) }
                        Spacer()
                        Button("六码一致") {
                            model.sessions.confirmPairing(peerID: peer.id)
                            model.reloadConversations()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VeilTheme.gold)
                    }
                }
            } else if peer.trustState == .discovered {
                Button("建立安全连接") { model.bluetooth.connect(to: peer.transportID) }
                    .buttonStyle(.borderedProminent)
                    .tint(VeilTheme.gold)
            }
        }
        .veilCard()
    }

    private var trustLabel: String {
        switch peer.trustState {
        case .discovered: return "未连接"
        case .awaitingConfirmation: return "待验证"
        case .trusted: return "已信任"
        case .blocked: return "已拉黑"
        }
    }

    private var signalDescription: String {
        switch peer.rssi {
        case -55...0: return "信号很强 · \(peer.rssi) dBm"
        case -72..<(-55): return "信号良好 · \(peer.rssi) dBm"
        default: return "信号较弱 · \(peer.rssi) dBm"
        }
    }
}
