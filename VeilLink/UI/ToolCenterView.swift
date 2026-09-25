import SwiftUI

struct VeilToolCenterView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""

    private var matchesWalkie: Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return q.isEmpty || "对讲机 walkie talkie ptt 语音".contains(q)
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(VeilTheme.secondaryText)
                    TextField("搜索工具", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 14).fill(VeilAppearanceController.shared.palette.recess.opacity(0.74)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(VeilTheme.hairline, lineWidth: 1))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOOLS").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.3).foregroundColor(VeilTheme.mutedGold)
                        Text("工具中心").font(.title2.bold()).foregroundColor(VeilTheme.text)
                    }
                    Spacer()
                    Text(VeilAppearanceController.shared.appearanceLabel)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(VeilTheme.tertiaryText)
                }

                if matchesWalkie {
                    NavigationLink(destination: VeilWalkieTalkieView(model: model)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [VeilTheme.panelSoft, VeilTheme.panel], startPoint: .top, endPoint: .bottom))
                                VStack(spacing: 6) {
                                    VeilSpeakerGrille(columns: 6, rows: 4)
                                    HStack(spacing: 6) { VeilIndicatorLamp(active: true); Text("PTT").font(.system(size: 8, weight: .bold, design: .monospaced)) }
                                }
                            }
                            .frame(width: 80, height: 80)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("对讲机").font(.headline).foregroundColor(VeilTheme.text)
                                Text("附近 E2EE · 半双工 PTT · 实时语音").font(.caption).foregroundColor(VeilTheme.secondaryText)
                                Text("LIVE AUDIO · JITTER BUFFER · PRIORITY").font(.system(size: 7.5, weight: .bold, design: .monospaced)).tracking(0.8).foregroundColor(VeilTheme.mutedGold)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundColor(VeilTheme.tertiaryText)
                        }
                        .padding(14)
                    }
                    .buttonStyle(VeilPressStyle())
                    .background(VeilInstrumentPlate(shape: RoundedRectangle(cornerRadius: 20, style: .continuous), emphasized: true))
                }
            }
        }
        .padding(.horizontal, 14)
        .background(VeilAmbientBackground())
        .navigationTitle("工具")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VeilWalkieTalkieView: View {
    @ObservedObject var model: AppModel
    @StateObject private var radio = VeilWalkieTalkieAudioController()
    @State private var openToTrustedNearby = true
    @State private var selectedPeerIDs = Set<String>()
    @State private var pressed = false

    private var trustedPeers: [NearbyPeer] { model.sessions.nearbyPeers.filter { $0.trustState == .trusted } }
    private var recipients: [String] {
        if openToTrustedNearby { return trustedPeers.map(\.id) }
        return trustedPeers.filter { selectedPeerIDs.contains($0.id) }.map(\.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                radioFace
                peerPanel
                Text("PTT 实时音频使用当前已建立的 E2EE 会话。实时音频优先于图片/附件传输，但仍让位于握手、ACK 与安全控制包；未确认身份不会收到语音。")
                    .font(.caption).foregroundColor(VeilTheme.secondaryText)
            }
            .padding(18)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("对讲机")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let controller = radio
            controller.sendControl = { packet, peers in model.sessions.sendPTTControl(packet, to: peers) }
            controller.sendAudioFrame = { frame, peers in model.sessions.sendPTTAudioFrame(frame, to: peers) }
            model.sessions.onPTTControl = { [weak controller] incoming in controller?.receiveControl(incoming) }
            model.sessions.onPTTAudioFrame = { [weak controller] incoming in controller?.receiveAudio(incoming) }
        }
        .onDisappear {
            radio.stopAll()
            model.sessions.onPTTControl = nil
            model.sessions.onPTTAudioFrame = nil
        }
    }

    private var radioFace: some View {
        VStack(spacing: 17) {
            HStack(alignment: .top, spacing: 12) {
                VeilLCDDisplay(title: "CHANNEL", value: channelLabel)
                Spacer()
                HStack(spacing: 10) {
                    statusLamp("TX", active: radio.state == .transmitting, color: VeilTheme.danger)
                    statusLamp("RX", active: isReceiving, color: VeilAppearanceController.shared.palette.indicator)
                }
            }

            HStack(spacing: 22) {
                VStack(spacing: 10) {
                    VeilSpeakerGrille(columns: 8, rows: 9)
                    Text("SPEAKER").font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(1).foregroundColor(VeilTheme.tertiaryText)
                }
                Spacer()
                ZStack {
                    VeilInstrumentKnob(value: Double(max(0.08, radio.meter))).frame(width: 112, height: 112)
                    VStack(spacing: 2) {
                        Text("RF").font(.system(size: 9, weight: .bold, design: .monospaced))
                        Text(radio.signalLabel).font(.system(size: 7, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(VeilTheme.tertiaryText)
                }
            }

            HStack(spacing: 8) {
                meterTile("BUF", "\(radio.jitterDepth)")
                meterTile("PLC", "\(radio.concealedFrames)")
                meterTile("RX LOSS", "\(radio.droppedFrames)")
                meterTile("TX DROP", "\(radio.transmitDroppedFrames)")
            }

            Text(statusText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(VeilTheme.secondaryText)

            Text("PTT")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 88)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(
                            colors: pressed
                                ? [Color(red: 0.72, green: 0.04, blue: 0.035), Color(red: 0.31, green: 0.01, blue: 0.01)]
                                : [VeilTheme.goldBright, VeilTheme.goldDeep],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(pressed ? 0.05 : 0.18))
                        .frame(height: pressed ? 8 : 16)
                        .padding(.horizontal, 7)
                        .padding(.top, 5)
                        .allowsHitTesting(false)
                }
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(pressed ? 0.10 : 0.25), lineWidth: 1))
                .offset(y: pressed ? 4 : 0)
                .scaleEffect(pressed ? 0.992 : 1)
                .shadow(color: Color.black.opacity(pressed ? 0.10 : 0.50), radius: pressed ? 1 : 9, x: 0, y: pressed ? 1 : 7)
                .contentShape(RoundedRectangle(cornerRadius: 22))
                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    model.haptics.impact()
                    radio.beginTransmit(recipients: recipients)
                }.onEnded { _ in
                    pressed = false
                    radio.endTransmit()
                    model.haptics.resolved()
                })
                .animation(.interactiveSpring(response: 0.17, dampingFraction: 0.72), value: pressed)
                .disabled(recipients.isEmpty || isReceiving)

            HStack {
                Text("G.711 µ-law · 8 kHz · 80 ms")
                Spacer()
                Text("\(VeilDevicePerformance.current.label)")
            }
            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
            .foregroundColor(VeilTheme.tertiaryText)
        }
        .padding(20)
        .background(VeilInstrumentPlate(shape: RoundedRectangle(cornerRadius: 28, style: .continuous), emphasized: true))
    }

    private var peerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("开放给附近已信任设备", isOn: $openToTrustedNearby).tint(VeilTheme.gold)
            if trustedPeers.isEmpty {
                Label("附近没有已信任设备", systemImage: "person.2.slash").font(.caption).foregroundColor(VeilTheme.secondaryText)
            } else if !openToTrustedNearby {
                ForEach(trustedPeers) { peer in
                    Button {
                        if selectedPeerIDs.contains(peer.id) { selectedPeerIDs.remove(peer.id) } else { selectedPeerIDs.insert(peer.id) }
                    } label: {
                        HStack { VeilIndicatorLamp(active: selectedPeerIDs.contains(peer.id)); Text(peer.displayName); Spacer(); Text("\(peer.rssi) dBm").font(.caption2) }
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())
                }
            } else {
                Text("当前频道：\(trustedPeers.count) 台附近已信任设备")
                    .font(.caption).foregroundColor(VeilTheme.secondaryText)
            }
        }
        .veilCard()
    }

    private func statusLamp(_ title: String, active: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            VeilIndicatorLamp(active: active, color: color)
            Text(title).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundColor(VeilTheme.tertiaryText)
        }
    }

    private func meterTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 6.5, weight: .bold, design: .monospaced)).foregroundColor(VeilTheme.tertiaryText)
            Text(value).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(VeilTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(VeilAppearanceController.shared.palette.recess.opacity(0.66)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VeilTheme.hairline, lineWidth: 1))
    }

    private var isReceiving: Bool {
        if case .receiving = radio.state { return true }
        return false
    }

    private var channelLabel: String {
        switch radio.state {
        case .transmitting: return "TX ALL"
        case .receiving: return "RX BUF"
        case .error: return "FAULT"
        default: return "READY"
        }
    }

    private var statusText: String {
        switch radio.state {
        case .transmitting: return "正在发射 · 松开结束"
        case .receiving: return "正在接收 · 缓冲 \(radio.jitterDepth) 帧"
        case .preparing: return "正在启动麦克风"
        case .error(let text): return text
        case .idle: return recipients.isEmpty ? "等待附近设备" : "按住说话"
        }
    }
}
