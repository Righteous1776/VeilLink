import SwiftUI
import UIKit

struct VeilToolCenterView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var matchesWalkie: Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return q.isEmpty || "对讲机 walkie talkie ptt 语音".contains(q)
    }

    private func matches(_ keywords: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return q.isEmpty || keywords.lowercased().contains(q)
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
                .veilCompactToolSurface(cornerRadius: 14)

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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                    if matches("密码 password 随机 安全 生成器") {
                        toolLink("安全密码", detail: "系统随机数 · 强度估算", icon: "key.fill", destination: VeilPasswordToolView())
                    }
                    if matches("指纹 hash sha256 文本 校验 摘要") {
                        toolLink("文本指纹", detail: "SHA-256 · 字节统计", icon: "number", destination: VeilFingerprintToolView())
                    }
                    if matches("二维码 qr 临时 文本 分享") {
                        toolLink("临时二维码", detail: "短文本离线转码", icon: "qrcode", destination: VeilTemporaryQRToolView())
                    }
                    if matches("网络 局域网 lan 蓝牙 ble 链路 诊断") {
                        toolLink("链路仪表", detail: "LAN 与 BLE 速览", icon: "wave.3.right.circle.fill", destination: VeilLinkPulseToolView(model: model))
                    }
                }
                .animation(reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal ? nil : VeilMotion.transit, value: query)
            }
        }
        .padding(.horizontal, 14)
        .background(VeilAmbientBackground())
        .navigationTitle("工具")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toolLink<Destination: View>(_ title: String, detail: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(VeilTheme.gold)
                    .frame(width: 42, height: 42)
                    .background(VeilTheme.gold.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundColor(VeilTheme.text)
                    Text(detail).font(.caption2).foregroundColor(VeilTheme.secondaryText).lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundColor(VeilTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(14)
            .veilCompactToolSurface(cornerRadius: 16)
        }
        .buttonStyle(VeilPressStyle())
    }
}

struct VeilToolCenterToolbarLink: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationLink(destination: VeilToolCenterView(model: model)) {
            Image(systemName: "square.grid.2x2")
        }
        .accessibilityLabel("打开工具中心")
    }
}

struct VeilPasswordToolView: View {
    @State private var recipe = VeilPasswordRecipe()
    @State private var generated = ""
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(generated.isEmpty ? "点击生成" : generated)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundColor(VeilTheme.goldBright)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .id(generated)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                    HStack {
                        Label("约 \(VeilLocalToolEngine.passwordEntropyBits(recipe: recipe)) bit", systemImage: "shield.lefthalf.filled")
                        Spacer()
                        Text("\(recipe.length) 位")
                    }
                    .font(.caption.monospaced())
                    .foregroundColor(VeilTheme.secondaryText)
                }
                .veilCard(emphasized: true)

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Text("长度").frame(width: 42, alignment: .leading)
                        Slider(value: lengthBinding, in: 12...64, step: 1)
                        Text("\(recipe.length)").monospacedDigit().frame(width: 28, alignment: .trailing)
                    }
                    Toggle("包含大写字母", isOn: $recipe.uppercase)
                    Toggle("包含数字", isOn: $recipe.digits)
                    Toggle("包含符号", isOn: $recipe.symbols)
                    Toggle("排除易混淆字符 Il1O0o", isOn: $recipe.excludesAmbiguous)
                }
                .tint(VeilTheme.gold)
                .veilCard()

                HStack(spacing: 10) {
                    Button("重新生成") { regenerate() }.buttonStyle(VeilGamePrimaryButtonStyle())
                    Button(copied ? "已复制" : "复制") {
                        UIPasteboard.general.string = generated
                        copied = true
                    }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                    .disabled(generated.isEmpty)
                }
                privacyNote("密码仅在本机内存中生成；复制后由系统剪贴板管理，请在使用后覆盖剪贴板。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("安全密码")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if generated.isEmpty { regenerate() } }
    }

    private var lengthBinding: Binding<Double> {
        Binding(get: { Double(recipe.length) }, set: { recipe.length = Int($0); regenerate() })
    }

    private func regenerate() {
        let update = {
            generated = VeilLocalToolEngine.password(recipe: recipe)
            copied = false
        }
        if reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal { update() }
        else { withAnimation(VeilMotion.resolve, update) }
    }
}

struct VeilFingerprintToolView: View {
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 170)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                let metrics = VeilLocalToolEngine.textMetrics(text)
                HStack(spacing: 8) {
                    metric("字符", "\(metrics.characters)")
                    metric("UTF-8", "\(metrics.utf8Bytes) B")
                    metric("行", "\(metrics.lines)")
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("SHA-256").font(.caption.bold()).foregroundColor(VeilTheme.mutedGold)
                    Text(VeilLocalToolEngine.sha256(text))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("复制指纹") { UIPasteboard.general.string = VeilLocalToolEngine.sha256(text) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                }
                .veilCard(emphasized: true)
                privacyNote("输入内容只在本机计算，不会写入聊天、诊断日志或网络。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("文本指纹")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VeilTemporaryQRToolView: View {
    @State private var text = ""
    @State private var qrImage: UIImage?
    @State private var renderTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                if text.utf8.count > 1_024 {
                    Label("内容过长，请控制在 1024 字节内", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(VeilTheme.danger)
                } else if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .frame(maxWidth: 320)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    Button("复制原文") { UIPasteboard.general.string = text }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                } else {
                    Label("输入文本后自动生成", systemImage: "qrcode")
                        .foregroundColor(VeilTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .veilCard()
                }
                privacyNote("二维码由本机 Core Image 即时生成，不保存、不上传。二维码本身可被任何扫描者读出，请勿放入长期密钥。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("临时二维码")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: text) { value in
            renderTask?.cancel()
            qrImage = nil
            guard !value.isEmpty, value.utf8.count <= 1_024 else { return }
            renderTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                let image = VeilPairQRRenderer.render(text: value)
                if reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal {
                    qrImage = image
                } else {
                    withAnimation(VeilMotion.reveal) { qrImage = image }
                }
            }
        }
        .onDisappear {
            renderTask?.cancel()
            renderTask = nil
        }
    }
}

struct VeilLinkPulseToolView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                linkCard(
                    title: "LAN Turbo",
                    icon: "wifi",
                    active: model.lanTurbo.isRunning,
                    status: model.lanTurbo.statusText,
                    detail: "连接 \(model.lanTurbo.connectedPeerCount) · \(model.lanTurbo.dataPlaneSummary)"
                )
                linkCard(
                    title: "Bluetooth LE",
                    icon: "dot.radiowaves.left.and.right",
                    active: model.bluetooth.isRunning,
                    status: model.bluetooth.isRunning ? "BLE 正在运行" : "BLE 未启动",
                    detail: "连接 \(model.bluetooth.connectedPeerCount) · 追踪 \(model.bluetooth.linkSnapshots.count)"
                )
                Button {
                    model.lanTurbo.refresh()
                    if !model.bluetooth.isRunning { model.bluetooth.start() }
                } label: {
                    Label("刷新本地链路", systemImage: "arrow.clockwise")
                }
                .buttonStyle(VeilGamePrimaryButtonStyle())
                privacyNote("只刷新 VeilLink 自己的 Bonjour/BLE 发现，不进行互联网测速、端口扫描或局域网设备探测。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("链路仪表")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func linkCard(title: String, icon: String, active: Bool, status: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon).font(.headline)
                Spacer()
                VeilIndicatorLamp(active: active)
            }
            Text(status).font(.subheadline).foregroundColor(VeilTheme.text)
            Text(detail).font(.caption.monospaced()).foregroundColor(VeilTheme.secondaryText)
        }
        .veilCard(emphasized: active)
    }
}

private func privacyNote(_ text: String) -> some View {
    Label(text, systemImage: "lock.shield.fill")
        .font(.caption)
        .foregroundColor(VeilTheme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
}

private func metric(_ title: String, _ value: String) -> some View {
    VStack(spacing: 2) {
        Text(value).font(.caption.bold().monospacedDigit()).foregroundColor(VeilTheme.text)
        Text(title).font(.caption2).foregroundColor(VeilTheme.tertiaryText)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .veilCompactToolSurface(cornerRadius: 8)
}

private struct VeilCompactToolSurface: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if VeilRenderProfile.allowsExpensiveVisualEffects {
            content
                .background(.ultraThinMaterial)
                .background(VeilTheme.elevated.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 0.8))
        } else {
            content
                .background(VeilTheme.elevated.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))
        }
    }
}

private extension View {
    func veilCompactToolSurface(cornerRadius: CGFloat) -> some View {
        modifier(VeilCompactToolSurface(cornerRadius: cornerRadius))
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
