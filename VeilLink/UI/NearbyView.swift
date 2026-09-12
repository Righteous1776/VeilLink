import SwiftUI

struct NearbyView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var bluetooth: BLETransport
    @ObservedObject var sessions: SessionCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) {
        self.model = model
        bluetooth = model.bluetooth
        sessions = model.sessions
    }

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    RadarStatusView(isRunning: bluetooth.isRunning, reduceMotion: reduceMotion)
                        .frame(width: 86, height: 86)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(bluetooth.isRunning ? VeilTheme.success : VeilTheme.tertiaryText)
                                .frame(width: 7, height: 7)
                            Text(bluetooth.statusText)
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                        }
                        Text("仅广播匿名服务标识 · 身份资料在安全握手后交换")
                            .font(.footnote)
                            .foregroundColor(VeilTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .veilCard(emphasized: bluetooth.isRunning)

                if sessions.nearbyPeers.isEmpty {
                    VStack(spacing: 13) {
                        VeilIdentityGlyph(seed: "VeilLink/Nearby/Waiting", size: 68, active: bluetooth.isRunning)
                        HStack(spacing: 8) {
                            Text("LOCAL")
                            VeilLinkTrace(active: bluetooth.isRunning, width: 68)
                            Text("…")
                        }
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.mutedGold)
                        Text("等待附近的 VeilLink 设备")
                            .font(.system(.body, design: .rounded).weight(.medium))
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
        }
        .background(VeilAmbientBackground())
        .navigationTitle("附近设备")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    model.haptics.selection()
                    bluetooth.isRunning ? bluetooth.stop() : bluetooth.start()
                } label: {
                    Label(bluetooth.isRunning ? "暂停" : "扫描", systemImage: bluetooth.isRunning ? "pause.fill" : "dot.radiowaves.left.and.right")
                        .foregroundColor(VeilTheme.gold)
                }
            }
        }
    }
}

private struct RadarStatusView: View {
    let isRunning: Bool
    let reduceMotion: Bool
    @State private var pulse = false
    @State private var sweep = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VeilTheme.gold.opacity(0.13), VeilTheme.obsidian.opacity(0.86)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 42
                    )
                )

            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .trim(from: 0.06 + CGFloat(ring) * 0.08, to: 0.70 + CGFloat(ring) * 0.05)
                    .stroke(
                        ring == 0 ? VeilTheme.gold.opacity(0.34) : Color.white.opacity(0.095),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .scaleEffect(0.42 + CGFloat(ring) * 0.25)
                    .rotationEffect(.degrees(Double(ring * 79 - 28)))
            }

            if isRunning {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [VeilTheme.goldBright.opacity(0.78), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1, height: 35)
                    .offset(y: -17.5)
                    .rotationEffect(.degrees(sweep ? 360 : 0), anchor: .bottom)
                    .opacity(reduceMotion ? 0.28 : 0.72)
            }

            if isRunning {
                Circle()
                    .stroke(VeilTheme.gold.opacity(0.36), lineWidth: 1)
                    .scaleEffect(pulse ? 1.0 : 0.68)
                    .opacity(pulse ? 0 : 0.55)
            }

            ZStack {
                VeilPanelShape(cut: 3, radius: 1)
                    .fill(VeilTheme.goldBright)
                    .frame(width: 9, height: 9)
                VeilPanelShape(cut: 2, radius: 1)
                    .stroke(Color.black.opacity(0.50), lineWidth: 0.7)
                    .frame(width: 5, height: 5)
            }
            .shadow(color: VeilTheme.gold.opacity(0.55), radius: 8)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(isRunning ? "SCAN" : "IDLE")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(isRunning ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                .offset(x: 2, y: 2)
        }
        .onAppear { updateMotion() }
        .onChange(of: isRunning) { _ in updateMotion() }
        .onChange(of: reduceMotion) { _ in updateMotion() }
    }

    private func updateMotion() {
        pulse = false
        sweep = false
        guard isRunning, !reduceMotion, VeilRenderProfile.allowsPersistentAnimations else { return }
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            pulse = true
        }
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
            sweep = true
        }
    }
}

private struct NearbyPeerCard: View {
    @ObservedObject var model: AppModel
    let peer: NearbyPeer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VeilIdentityGlyph(
                    seed: peer.id,
                    size: 42,
                    active: peer.trustState == .trusted || peer.trustState == .awaitingConfirmation
                )
                VStack(alignment: .leading, spacing: 5) {
                    Text(peer.displayName)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                    HStack(spacing: 7) {
                        Text(signalDescription)
                            .font(.footnote)
                            .foregroundColor(VeilTheme.secondaryText)
                        VeilLinkTrace(active: peer.trustState == .awaitingConfirmation, width: 30)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(trustLabel.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(trustColor)
                    Rectangle()
                        .fill(trustColor.opacity(0.52))
                        .frame(width: 28, height: 1)
                }
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
                    HStack(spacing: 7) {
                        ForEach(Array(code.enumerated()), id: \.offset) { index, character in
                            Text(String(character))
                                .font(.system(size: 27, weight: .semibold, design: .monospaced))
                                .frame(width: 34, height: 43)
                                .background(index < 3 ? VeilTheme.gold.opacity(0.075) : Color.white.opacity(0.030))
                                .clipShape(VeilPanelShape(cut: 6, radius: 4))
                                .overlay(VeilPanelShape(cut: 6, radius: 4).stroke(VeilTheme.hairline, lineWidth: 1))
                        }
                    }
                    HStack {
                        Button("不是这台设备", role: .destructive) {
                            model.haptics.warning()
                            model.sessions.rejectPairing(peerID: peer.id)
                        }
                        Spacer()
                        Button("六码一致") {
                            model.sessions.confirmPairing(peerID: peer.id)
                            model.reloadConversations()
                            model.haptics.resolved()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VeilTheme.gold)
                    }
                }
            } else if peer.trustState == .discovered {
                Button("建立安全连接") {
                    model.haptics.impact()
                    model.bluetooth.connect(to: peer.transportID)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(VeilTheme.gold)
            }
        }
        .veilCard(emphasized: peer.trustState == .awaitingConfirmation)
    }

    private var trustColor: Color {
        switch peer.trustState {
        case .trusted: return VeilTheme.success
        case .blocked: return VeilTheme.danger
        case .awaitingConfirmation: return VeilTheme.goldBright
        case .discovered: return VeilTheme.secondaryText
        }
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
