import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

    private var hasCommsMatches: Bool {
        matches("二维码 qr 临时 文本 分享")
        || matches("网络 局域网 lan 蓝牙 ble 链路 诊断")
    }

    private var hasSecureMatches: Bool {
        matches("密码 password 随机 安全 生成器")
        || matches("指纹 hash sha256 文本 校验 摘要")
        || matches("uuid guid 唯一 标识符 批量")
        || matches("随机 决策 抽签 骰子 硬币 random dice")
    }

    private var hasDataMatches: Bool {
        matches("json 格式化 校验 压缩 pretty minify")
        || matches("base64 编码 解码 utf8")
        || matches("url uri 百分号 percent 编码 解码")
        || matches("文本 清理 去重 排序 空行 trim clean")
        || matches("摩斯 morse 电码 编码 解码 sos")
    }

    private var hasLabMatches: Bool {
        matches("时间戳 timestamp unix iso8601 日期 时间")
        || matches("颜色 color hex rgb 转换 色块")
    }

    private var matchedModuleCount: Int {
        var count = matchesWalkie ? 1 : 0
        let keywords = [
            "二维码 qr 临时 文本 分享",
            "网络 局域网 lan 蓝牙 ble 链路 诊断",
            "密码 password 随机 安全 生成器",
            "指纹 hash sha256 文本 校验 摘要",
            "uuid guid 唯一 标识符 批量",
            "随机 决策 抽签 骰子 硬币 random dice",
            "json 格式化 校验 压缩 pretty minify",
            "base64 编码 解码 utf8",
            "url uri 百分号 percent 编码 解码",
            "文本 清理 去重 排序 空行 trim clean",
            "摩斯 morse 电码 编码 解码 sos",
            "时间戳 timestamp unix iso8601 日期 时间",
            "颜色 color hex rgb 转换 色块"
        ]
        count += keywords.filter(matches).count
        return count
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(VeilTheme.gold)
                    TextField("搜索本地模块", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textFieldStyle(.plain)
                    VeilIndicatorLamp(active: query.isEmpty == false)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .veilCompactToolSurface(cornerRadius: 14)

                VeilInstrumentDeck(
                    title: "VeilLink 本地仪器台",
                    subtitle: "所有工具默认离线处理；输入不进入诊断、遥测或网络上传。",
                    symbol: "wrench.and.screwdriver.fill",
                    emphasized: true
                ) {
                    HStack(spacing: 10) {
                        VeilLCDDisplay(title: "MODULES", value: query.isEmpty ? "13 + PTT" : "\(matchedModuleCount) FOUND")
                            .frame(maxWidth: .infinity)
                        VeilLCDDisplay(title: "MODE", value: "LOCAL")
                            .frame(maxWidth: .infinity)
                    }
                    HStack {
                        VeilInstrumentLabel(title: "PRIVACY", value: "LOCAL ONLY", active: true)
                        Spacer()
                        VeilInstrumentLabel(title: "RENDER", value: VeilRenderProfile.allowsExpensiveVisualEffects ? "FULL" : "LITE", active: true)
                    }
                }

                if matchesWalkie {
                    NavigationLink(destination: VeilWalkieTalkieView(model: model)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.black.opacity(0.24))
                                VStack(spacing: 7) {
                                    VeilSpeakerGrille(columns: 7, rows: 5)
                                    HStack(spacing: 6) {
                                        VeilIndicatorLamp(active: true)
                                        Text("LIVE AUDIO")
                                            .font(.system(size: 7.5, weight: .black, design: .monospaced))
                                            .tracking(0.8)
                                    }
                                }
                            }
                            .frame(width: 88, height: 88)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.09), lineWidth: 0.7))

                            VStack(alignment: .leading, spacing: 5) {
                                Text("对讲机")
                                    .font(.headline)
                                    .foregroundColor(VeilTheme.text)
                                Text("附近 E2EE · 半双工 PTT · 实时语音")
                                    .font(.caption)
                                    .foregroundColor(VeilTheme.secondaryText)
                                HStack(spacing: 6) {
                                    VeilInstrumentLabel(title: "LINK", value: "BLE", active: model.bluetooth.isRunning)
                                    VeilInstrumentLabel(title: "AUDIO", value: "PTT", active: true)
                                }
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .foregroundColor(VeilTheme.gold)
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                    .background(
                        VeilInstrumentPlate(
                            shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                            emphasized: true
                        )
                    )
                }

                if hasCommsMatches {
                    VeilInstrumentRackSection(
                    title: "通信与链路",
                    subtitle: "本地分享、无线状态与短距通信。",
                    code: "COMMS"
                ) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                        if matches("二维码 qr 临时 文本 分享") {
                            toolLink("临时二维码", detail: "短文本离线转码", icon: "qrcode", destination: VeilTemporaryQRToolView())
                        }
                        if matches("网络 局域网 lan 蓝牙 ble 链路 诊断") {
                            toolLink("链路仪表", detail: "LAN 与 BLE 速览", icon: "wave.3.right.circle.fill", destination: VeilLinkPulseToolView(model: model))
                        }
                    }
                    }
                }

                if hasSecureMatches {
                    VeilInstrumentRackSection(
                    title: "安全与身份",
                    subtitle: "随机、安全校验与本地标识生成。",
                    code: "SECURE"
                ) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                        if matches("密码 password 随机 安全 生成器") {
                            toolLink("安全密码", detail: "系统随机数 · 强度估算", icon: "key.fill", destination: VeilPasswordToolView())
                        }
                        if matches("指纹 hash sha256 文本 校验 摘要") {
                            toolLink("文本指纹", detail: "SHA-256 · 字节统计", icon: "number", destination: VeilFingerprintToolView())
                        }
                        if matches("uuid guid 唯一 标识符 批量") {
                            toolLink("UUID 批量", detail: "本地生成 · 一键复制", icon: "barcode", destination: VeilUUIDToolView())
                        }
                        if matches("随机 决策 抽签 骰子 硬币 random dice") {
                            toolLink("随机决策", detail: "抽签 · 硬币 · 多面骰", icon: "die.face.5.fill", destination: VeilRandomDecisionToolView())
                        }
                    }
                    }
                }

                if hasDataMatches {
                    VeilInstrumentRackSection(
                    title: "数据与文本",
                    subtitle: "编码、清理、格式化与轻量文本处理。",
                    code: "DATA"
                ) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                        if matches("json 格式化 校验 压缩 pretty minify") {
                            toolLink("JSON 工坊", detail: "校验 · 整理 · 压缩", icon: "curlybraces", destination: VeilJSONToolView())
                        }
                        if matches("base64 编码 解码 utf8") {
                            toolLink("Base64", detail: "UTF-8 本地编解码", icon: "textformat.abc", destination: VeilTextCodecToolView(kind: .base64))
                        }
                        if matches("url uri 百分号 percent 编码 解码") {
                            toolLink("URL 编码", detail: "RFC 3986 百分号转码", icon: "link", destination: VeilTextCodecToolView(kind: .urlPercent))
                        }
                        if matches("文本 清理 去重 排序 空行 trim clean") {
                            toolLink("文本清理", detail: "修剪 · 去重 · 排序", icon: "text.alignleft", destination: VeilTextCleanerToolView())
                        }
                        if matches("摩斯 morse 电码 编码 解码 sos") {
                            toolLink("摩斯电码", detail: "A–Z / 0–9 双向转换", icon: "waveform.path", destination: VeilMorseToolView())
                        }
                    }
                    }
                }

                if hasLabMatches {
                    VeilInstrumentRackSection(
                    title: "转换与实验",
                    subtitle: "时间、色彩与日常工程转换。",
                    code: "LAB"
                ) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                        if matches("时间戳 timestamp unix iso8601 日期 时间") {
                            toolLink("时间戳", detail: "Unix ↔ ISO 8601 UTC", icon: "clock.arrow.2.circlepath", destination: VeilTimestampToolView())
                        }
                        if matches("颜色 color hex rgb 转换 色块") {
                            toolLink("颜色实验室", detail: "HEX ↔ RGB · 色块预览", icon: "paintpalette.fill", destination: VeilColorLabToolView())
                        }
                    }
                    }
                }

                if matchedModuleCount == 0 {
                    VeilInstrumentDeck(
                        title: "未找到本地模块",
                        subtitle: "换一个关键词；工具不会联网搜索，也不会把查询发出设备。",
                        symbol: "magnifyingglass"
                    ) {
                        VeilLCDDisplay(title: "RESULT", value: "0 MATCH")
                    }
                }

                Color.clear
                    .frame(height: 1)
                    .animation(VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion), value: query)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 20)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("工具")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toolLink<Destination: View>(_ title: String, detail: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.24))
                        Image(systemName: icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(VeilTheme.goldBright)
                    }
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.7))
                    Spacer()
                    VeilIndicatorLamp(active: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(VeilTheme.text)
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                HStack {
                    Text("LOCAL")
                        .font(.system(size: 7.5, weight: .black, design: .monospaced))
                        .tracking(0.9)
                        .foregroundColor(VeilTheme.mutedGold)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundColor(VeilTheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(13)
        }
        .buttonStyle(.plain)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 15, style: .continuous),
                emphasized: false
            )
        )
        .overlay(alignment: .topTrailing) {
            VeilScrewHead().padding(6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .veilSpatialPress(maximumTilt: 2.4, cornerRadius: 15, highlightColor: VeilTheme.goldBright)
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
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "生成结果", role: .output, active: !generated.isEmpty) {
                    Text(generated.isEmpty ? "READY" : generated)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundColor(VeilTheme.goldBright)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                        .id(generated)
                        .transition(.opacity)

                    VeilStatusStrip(
                        leftTitle: "ENTROPY",
                        leftValue: "~\(VeilLocalToolEngine.passwordEntropyBits(recipe: recipe)) bit",
                        rightTitle: "LENGTH",
                        rightValue: "\(recipe.length)",
                        active: true
                    )
                }

                VeilInstrumentBay(title: "生成参数", role: .input, active: true) {
                    VeilHardwareSlider(title: "长度", value: lengthBinding, range: 12...64, step: 1)
                    VeilToggleLever(title: "包含大写字母", isOn: $recipe.uppercase)
                    VeilToggleLever(title: "包含数字", isOn: $recipe.digits)
                    VeilToggleLever(title: "包含符号", isOn: $recipe.symbols)
                    VeilToggleLever(title: "排除易混淆字符 Il1O0o", isOn: $recipe.excludesAmbiguous)
                }

                HStack(spacing: 10) {
                    Button("重新生成") { regenerate() }
                        .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                    Button(copied ? "已复制" : "复制") {
                        VeilToolClipboard.copy(generated)
                        copied = true
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())
                    .disabled(generated.isEmpty)
                }

                privacyNote("密码仅在本机内存中生成；复制内容仅留在本设备，并会在 5 分钟后过期。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("安全密码")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if generated.isEmpty { regenerate() } }
    }

    private var lengthBinding: Binding<Double> {
        Binding(
            get: { Double(recipe.length) },
            set: {
                recipe.length = Int($0)
                regenerate()
            }
        )
    }

    private func regenerate() {
        let update = {
            generated = VeilLocalToolEngine.password(recipe: recipe)
            copied = false
        }
        if let animation = VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion) {
            withAnimation(animation, update)
        } else {
            update()
        }
    }
}

struct VeilFingerprintToolView: View {
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "原文输入", role: .input, active: !text.isEmpty) {
                    TextEditor(text: boundedToolText($text))
                        .font(.body)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    toolInputMeter(text)
                }

                let metrics = VeilLocalToolEngine.textMetrics(text)
                VeilStatusStrip(
                    leftTitle: "CHARS",
                    leftValue: "\(metrics.characters)",
                    rightTitle: "UTF-8",
                    rightValue: "\(metrics.utf8Bytes) B",
                    active: !text.isEmpty
                )

                VeilInstrumentBay(title: "SHA-256 指纹", role: .output, active: !text.isEmpty) {
                    Text(VeilLocalToolEngine.sha256(text))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilTheme.goldBright)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        VeilInstrumentLabel(title: "LINES", value: "\(metrics.lines)", active: !text.isEmpty)
                        Spacer()
                        Button("复制指纹") {
                            VeilToolClipboard.copy(VeilLocalToolEngine.sha256(text))
                        }
                        .buttonStyle(VeilPhysicalButtonStyle())
                        .disabled(text.isEmpty)
                    }
                }

                privacyNote("输入内容只在本机计算，不会写入聊天、诊断日志或网络。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
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
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "二维码载荷", role: .input, active: !text.isEmpty) {
                    TextEditor(text: $text)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    VeilGaugeMeter(
                        title: "PAYLOAD",
                        value: min(1, Double(text.utf8.count) / 1024.0),
                        text: "\(text.utf8.count) / 1024 B"
                    )
                }

                if text.utf8.count > 1_024 {
                    Label("内容过长，请控制在 1024 字节内", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(VeilTheme.danger)
                }

                VeilInstrumentBay(title: "QR 光学输出", role: .output, active: qrImage != nil) {
                    Group {
                        if let image = qrImage {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .frame(maxWidth: 300)
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 42, weight: .light))
                                    .foregroundColor(VeilTheme.tertiaryText)
                                Text("等待有效载荷")
                                    .font(.caption.monospaced())
                                    .foregroundColor(VeilTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 160)
                        }
                    }

                    Button("复制原文") { VeilToolClipboard.copy(text) }
                        .buttonStyle(VeilPhysicalButtonStyle())
                        .disabled(text.isEmpty)
                }

                privacyNote("二维码由本机 Core Image 即时生成，不保存、不上传。二维码本身可被任何扫描者读出，请勿放入长期密钥。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
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
                if let animation = VeilMotionPolicy.animation(.reveal, reduceMotionRequested: reduceMotion) {
                    withAnimation(animation) { qrImage = image }
                } else {
                    qrImage = image
                }
            }
        }
        .onDisappear {
            renderTask?.cancel()
            renderTask = nil
        }
    }
}

struct VeilJSONToolView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var structure: VeilJSONStructure?
    @State private var errorText: String?
    @State private var structure: VeilJSONStructure?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "JSON 输入", role: .input, active: !input.isEmpty) {
                    TextEditor(text: boundedToolText($input))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 145)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    toolInputMeter(input)
                }

                HStack(spacing: 9) {
                    Button("整理") { transform(pretty: true) }
                        .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                    Button("压缩") { transform(pretty: false) }
                        .buttonStyle(VeilPhysicalButtonStyle())
                    Button("复制") { VeilToolClipboard.copy(output) }
                        .buttonStyle(VeilPhysicalButtonStyle())
                        .disabled(output.isEmpty)
                }

                VeilStatusStrip(
                    leftTitle: "PARSER",
                    leftValue: errorText == nil && !output.isEmpty ? "VALID" : (errorText == nil ? "IDLE" : "FAULT"),
                    rightTitle: "OUTPUT",
                    rightValue: output.isEmpty ? "0 B" : "\(output.utf8.count) B",
                    active: errorText == nil
                )

                if let structure {
                    HStack(spacing: 8) {
                        VeilLCDDisplay(title: "ROOT", value: structure.rootType)
                            .frame(maxWidth: .infinity)
                        VeilLCDDisplay(title: "NODES", value: "\(structure.nodeCount)")
                            .frame(maxWidth: .infinity)
                    }
                    HStack(spacing: 8) {
                        VeilLCDDisplay(title: "DEPTH", value: "\(structure.maxDepth)")
                            .frame(maxWidth: .infinity)
                        VeilLCDDisplay(title: "KEYS", value: "\(structure.keyCount)")
                            .frame(maxWidth: .infinity)
                    }
                }

                if let errorText {
                    Label(errorText, systemImage: "xmark.octagon.fill")
                        .font(.caption)
                        .foregroundColor(VeilTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VeilInstrumentBay(title: "稳定化输出", role: .output, active: !output.isEmpty) {
                    Text(output.isEmpty ? "{ }" : output)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                }

                privacyNote("JSON 仅在本机解析；错误提示不会包含或记录你的输入内容。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("JSON 工坊")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in
            output = ""
            structure = nil
            errorText = nil
        }
    }

    private func transform(pretty: Bool) {
        do {
            output = try (pretty
                ? VeilLocalToolEngine.prettyJSON(input)
                : VeilLocalToolEngine.minifiedJSON(input))
            structure = try VeilLocalToolEngine.jsonStructure(input)
            errorText = nil
        } catch {
            output = ""
            structure = nil
            errorText = (error as? LocalizedError)?.errorDescription ?? "JSON 格式无效"
        }
    }
}

enum VeilTextCodecKind: Equatable {
    case base64
    case urlPercent

    var title: String { self == .base64 ? "Base64" : "URL 编码" }
    var detail: String { self == .base64 ? "UTF-8 ↔ Base64" : "文本 ↔ RFC 3986 百分号编码" }
}

struct VeilTextCodecToolView: View {
    let kind: VeilTextCodecKind
    @State private var input = ""
    @State private var output = ""
    @State private var usesURLSafeBase64 = false
    @State private var errorText: String?
    @State private var base64URLSafe = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilStatusStrip(
                    leftTitle: "CODEC",
                    leftValue: kind == .base64 ? (base64URLSafe ? "BASE64URL" : "BASE64") : "RFC3986",
                    rightTitle: "MODE",
                    rightValue: "LOCAL",
                    active: true
                )

                if kind == .base64 {
                    VeilToggleLever(title: "URL-safe（无填充）", isOn: $base64URLSafe)
                }

                VeilInstrumentBay(title: "源文本", role: .input, active: !input.isEmpty) {
                    TextEditor(text: boundedToolText($input))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 125)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    toolInputMeter(input)
                }

                HStack(spacing: 9) {
                    Button("编码") { encode() }
                        .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                    Button("解码") { decode() }
                        .buttonStyle(VeilPhysicalButtonStyle())
                    Button("复制") { VeilToolClipboard.copy(output) }
                        .buttonStyle(VeilPhysicalButtonStyle())
                        .disabled(output.isEmpty)
                }

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(VeilTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VeilInstrumentBay(title: "转换输出", role: .output, active: !output.isEmpty) {
                    Text(output.isEmpty ? "READY" : output)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                }

                privacyNote("编解码完全离线。Base64 不是加密，请勿把它当成机密保护。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in
            output = ""
            structure = nil
            errorText = nil
        }
    }

    private func encode() {
        if kind == .base64 {
            output = base64URLSafe
                ? VeilLocalToolEngine.base64URLEncodeUTF8(input)
                : VeilLocalToolEngine.base64EncodeUTF8(input)
        } else {
            output = VeilLocalToolEngine.urlPercentEncode(input)
        }
        errorText = nil
    }

    private func decode() {
        do {
            if kind == .base64 {
                output = try (base64URLSafe
                    ? VeilLocalToolEngine.base64URLDecodeUTF8(input)
                    : VeilLocalToolEngine.base64DecodeUTF8(input))
            } else {
                output = try VeilLocalToolEngine.urlPercentDecode(input)
            }
            errorText = nil
        } catch {
            output = ""
            errorText = (error as? LocalizedError)?.errorDescription ?? "无法解码"
        }
    }
}

struct VeilTimestampToolView: View {
    @State private var timestamp = ""
    @State private var iso8601 = ""
    @State private var usesMilliseconds = false
    @State private var errorText: String?
    @State private var result = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilStatusStrip(
                    leftTitle: "ZONE",
                    leftValue: "UTC",
                    rightTitle: "PRECISION",
                    rightValue: usesMilliseconds ? "MILLI" : "SECOND",
                    active: true
                )

                VeilInstrumentBay(title: "UNIX → UTC", role: .input, active: !timestamp.isEmpty) {
                    TextField(
                        usesMilliseconds ? "毫秒，例如 1700000000123" : "秒，例如 1700000000",
                        text: $timestamp
                    )
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.plain)
                    .veilInstrumentField()

                    VeilToggleLever(title: "输入为毫秒", isOn: $usesMilliseconds)
                    Button("转换为 ISO 8601") { timestampToISO() }
                        .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                }

                VeilInstrumentBay(title: "UTC → UNIX", role: .input, active: !iso8601.isEmpty) {
                    TextField("2023-11-14T22:13:20.123Z", text: $iso8601)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textFieldStyle(.plain)
                        .veilInstrumentField()

                    Button("转换为时间戳") { isoToTimestamp() }
                        .buttonStyle(VeilPhysicalButtonStyle())
                }

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(VeilTheme.danger)
                }

                VeilInstrumentBay(title: "转换结果", role: .output, active: !result.isEmpty) {
                    Text(result.isEmpty ? "READY" : result)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(result.isEmpty ? VeilTheme.tertiaryText : VeilTheme.goldBright)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 9) {
                        Button("填入当前时间") {
                            let now = Date().timeIntervalSince1970
                            timestamp = usesMilliseconds
                                ? String(Int64((now * 1_000).rounded()))
                                : String(Int64(now))
                            timestampToISO()
                        }
                        .buttonStyle(VeilPhysicalButtonStyle())

                        Button("复制结果") { VeilToolClipboard.copy(result) }
                            .buttonStyle(VeilPhysicalButtonStyle())
                            .disabled(result.isEmpty)
                    }
                }

                privacyNote("使用 UTC 进行转换；不读取日历、定位或网络时间。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("时间戳")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func timestampToISO() {
        do {
            guard let value = Int64(timestamp.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw VeilLocalToolError.timestampOutOfRange
            }
            let converted = try (usesMilliseconds
                ? VeilLocalToolEngine.iso8601(unixMilliseconds: value)
                : VeilLocalToolEngine.iso8601(unixSeconds: value))
            iso8601 = converted
            result = converted
            errorText = nil
        } catch {
            result = ""
            errorText = (error as? LocalizedError)?.errorDescription ?? "时间戳无效"
        }
    }

    private func isoToTimestamp() {
        do {
            let value = try (usesMilliseconds
                ? VeilLocalToolEngine.unixMilliseconds(iso8601: iso8601)
                : VeilLocalToolEngine.unixSeconds(iso8601: iso8601))
            timestamp = String(value)
            result = String(value)
            errorText = nil
        } catch {
            result = ""
            errorText = (error as? LocalizedError)?.errorDescription ?? "时间格式无效"
        }
    }
}

struct VeilUUIDToolView: View {
    @State private var count = 4.0
    @State private var values: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "批量参数", role: .input, active: true) {
                    VeilHardwareSlider(title: "数量", value: $count, range: 1...20, step: 1)
                }

                VeilInstrumentBay(title: "UUID 输出", role: .output, active: !values.isEmpty) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(values, id: \.self) { value in
                            Text(value)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                }

                HStack(spacing: 10) {
                    Button("重新生成") { generate() }
                        .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                    Button("复制全部") {
                        VeilToolClipboard.copy(values.joined(separator: "\n"))
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())
                    .disabled(values.isEmpty)
                }

                privacyNote("使用系统 UUID 生成器，不读取设备标识，不把结果关联到 VeilLink 身份。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("UUID 批量")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if values.isEmpty { generate() } }
    }

    private func generate() {
        values = (0..<Int(count)).map { _ in UUID().uuidString.lowercased() }
    }
}

struct VeilTextCleanerToolView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var options = VeilTextCleaningOptions()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "源文本", role: .input, active: !input.isEmpty) {
                    TextEditor(text: boundedToolText($input))
                        .frame(minHeight: 125)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    toolInputMeter(input)
                }

                VeilInstrumentBay(title: "清理规则", role: .status, active: true) {
                    VeilToggleLever(title: "修剪每行首尾空白", isOn: $options.trimsLines)
                    VeilToggleLever(title: "连续空行压成一行", isOn: $options.collapsesBlankLines)
                    VeilToggleLever(title: "删除重复行", isOn: $options.removesDuplicateLines)
                    VeilToggleLever(title: "按字符顺序排序", isOn: $options.sortsLines)
                }

                HStack(spacing: 9) {
                    Button("清理") {
                        output = VeilLocalToolEngine.cleanText(input, options: options)
                    }
                    .buttonStyle(VeilPhysicalButtonStyle(accent: true))

                    Button("复制") { VeilToolClipboard.copy(output) }
                        .buttonStyle(VeilPhysicalButtonStyle())
                        .disabled(output.isEmpty)
                }

                VeilInstrumentBay(title: "清理结果", role: .output, active: !output.isEmpty) {
                    Text(output.isEmpty ? "READY" : output)
                        .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 95, alignment: .topLeading)
                }

                privacyNote("文本只在当前页面内处理；排序采用稳定、可复现的字符顺序。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("文本清理")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in output = "" }
        .onChange(of: options) { _ in output = "" }
    }
}

struct VeilColorLabToolView: View {
    @State private var hex = "#C8A45D"
    @State private var red = "200"
    @State private var green = "164"
    @State private var blue = "93"
    @State private var preview = VeilRGBColor(red: 200, green: 164, blue: 93)
    @State private var errorText: String?
    @State private var lastValidatedHex = "#C8A45D"

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "色彩监视器", role: .status, active: isValidatedColor) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(
                            red: Double(preview.red) / 255,
                            green: Double(preview.green) / 255,
                            blue: Double(preview.blue) / 255
                        ))
                        .frame(height: 130)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .overlay(alignment: .bottomLeading) {
                            Text(lastValidatedHex.isEmpty ? "INVALID" : lastValidatedHex)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.48))
                                .clipShape(Capsule())
                                .padding(8)
                        }
                        .accessibilityLabel("颜色预览 \(hex)")

                    VStack(spacing: 7) {
                        VeilGaugeMeter(title: "RED", value: Double(preview.red) / 255.0, text: "\(preview.red)")
                        VeilGaugeMeter(title: "GREEN", value: Double(preview.green) / 255.0, text: "\(preview.green)")
                        VeilGaugeMeter(title: "BLUE", value: Double(preview.blue) / 255.0, text: "\(preview.blue)")
                    }

                    let hsl = VeilLocalToolEngine.hsl(rgb: preview)
                    VeilStatusStrip(
                        leftTitle: "HUE",
                        leftValue: "\(hsl.hue)°",
                        rightTitle: "SAT / LIGHT",
                        rightValue: "\(hsl.saturation)% / \(hsl.lightness)%",
                        active: isValidatedColor
                    )
                }

                VeilInstrumentBay(title: "颜色输入", role: .input, active: true) {
                    TextField("#RRGGBB", text: $hex)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .veilInstrumentField()

                    HStack(spacing: 8) {
                        colorField("R", text: $red)
                        colorField("G", text: $green)
                        colorField("B", text: $blue)
                    }
                }

                HStack(spacing: 9) {
                    Button("HEX → RGB") { fromHex() }
                        .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                    Button("RGB → HEX") { fromRGB() }
                        .buttonStyle(VeilPhysicalButtonStyle())
                }

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(VeilTheme.danger)
                }

                Button("复制 \(lastValidatedHex)") {
                    VeilToolClipboard.copy(lastValidatedHex)
                }
                .buttonStyle(VeilPhysicalButtonStyle())
                .disabled(!isValidatedColor)

                privacyNote("颜色转换不读取照片或屏幕内容；复制内容仅留在本设备，并会在 5 分钟后过期。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("颜色实验室")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorField(_ title: String, text: Binding<String>) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(VeilTheme.tertiaryText)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .veilInstrumentField()
        }
    }

    private var isValidatedColor: Bool {
        guard hex == lastValidatedHex,
              red == String(preview.red),
              green == String(preview.green),
              blue == String(preview.blue) else { return false }
        return true
    }

    private func fromHex() {
        do {
            let value = try VeilLocalToolEngine.rgb(hex: hex)
            preview = value
            red = String(value.red)
            green = String(value.green)
            blue = String(value.blue)
            hex = try VeilLocalToolEngine.hex(rgb: value)
            lastValidatedHex = hex
            errorText = nil
        } catch {
            lastValidatedHex = ""
            errorText = (error as? LocalizedError)?.errorDescription ?? "颜色无效"
        }
    }

    private func fromRGB() {
        do {
            guard let r = Int(red), let g = Int(green), let b = Int(blue) else {
                throw VeilLocalToolError.rgbOutOfRange
            }
            hex = try VeilLocalToolEngine.hex(red: r, green: g, blue: b)
            preview = VeilRGBColor(red: r, green: g, blue: b)
            lastValidatedHex = hex
            errorText = nil
        } catch {
            lastValidatedHex = ""
            errorText = (error as? LocalizedError)?.errorDescription ?? "颜色无效"
        }
    }
}

struct VeilRandomDecisionToolView: View {
    @State private var choices = "去散步\n看电影\n继续写代码"
    @State private var diceSides = "6"
    @State private var diceCount = "2"
    @State private var result = "等待命运提交 Pull Request"
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "随机输出", role: .output, active: true) {
                    Text(result)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(VeilTheme.goldBright)
                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .center)
                        .multilineTextAlignment(.center)
                }

                VeilInstrumentBay(title: "候选池", role: .input, active: !parsedChoices.isEmpty) {
                    TextEditor(text: boundedToolText($choices))
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    toolInputMeter(choices)
                }

                HStack(spacing: 9) {
                    Button("抽一个") { pick() }
                        .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                    Button("抛硬币") { coin() }
                        .buttonStyle(VeilPhysicalButtonStyle())
                }

                VeilInstrumentBay(title: "骰子模块", role: .input, active: true) {
                    HStack(spacing: 9) {
                        TextField("面数", text: $diceSides)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .veilInstrumentField()
                        TextField("数量", text: $diceCount)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .veilInstrumentField()
                        Button("掷骰") { roll() }
                            .buttonStyle(VeilPhysicalButtonStyle())
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(VeilTheme.danger)
                }

                privacyNote("使用系统安全随机源；结果不联网、不上报，也不会替你承担决定的后果。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("随机决策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var parsedChoices: [String] {
        choices
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func pick() {
        do {
            result = try VeilLocalToolEngine.randomChoice(from: parsedChoices)
            errorText = nil
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription
        }
    }

    private func coin() {
        do {
            result = try VeilLocalToolEngine.randomChoice(from: ["正面", "反面"])
            errorText = nil
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription
        }
    }

    private func roll() {
        do {
            guard let sides = Int(diceSides), let count = Int(diceCount) else {
                throw VeilLocalToolError.invalidDice
            }
            let values = try VeilLocalToolEngine.rollDice(sides: sides, count: count)
            result = values.map(String.init).joined(separator: " + ")
                + " = \(values.reduce(0, +))"
            errorText = nil
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription
        }
    }
}

struct VeilMorseToolView: View {
    @State private var input = ""
    @State private var output = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilInstrumentBay(title: "明文 / 电码输入", role: .input, active: !input.isEmpty) {
                    TextEditor(text: boundedToolText($input))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    toolInputMeter(input)
                }

                HStack(spacing: 9) {
                    Button("编码") {
                        output = VeilLocalToolEngine.morseEncode(input)
                    }
                    .buttonStyle(VeilPhysicalButtonStyle(accent: true))

                    Button("解码") {
                        output = VeilLocalToolEngine.morseDecode(input)
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())

                    Button("复制") {
                        VeilToolClipboard.copy(output)
                    }
                    .buttonStyle(VeilPhysicalButtonStyle())
                    .disabled(output.isEmpty)
                }

                VeilInstrumentBay(title: "信号输出", role: .output, active: !output.isEmpty) {
                    Text(output.isEmpty ? "... --- ..." : output)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.goldBright)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                }

                privacyNote("支持 A–Z 与 0–9；词间使用 /。不支持的字符显示为 ?，转换完全离线。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("摩斯电码")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in output = "" }
    }
}

struct VeilLinkPulseToolView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VeilStatusStrip(
                    leftTitle: "LAN PEERS",
                    leftValue: "\(model.lanTurbo.connectedPeerCount)",
                    rightTitle: "BLE PEERS",
                    rightValue: "\(model.bluetooth.connectedPeerCount)",
                    active: model.lanTurbo.isRunning || model.bluetooth.isRunning
                )

                linkCard(
                    title: "LAN Turbo",
                    icon: "wifi",
                    active: model.lanTurbo.isRunning,
                    status: model.lanTurbo.statusText,
                    detail: model.lanTurbo.dataPlaneSummary,
                    peerCount: model.lanTurbo.connectedPeerCount
                )

                linkCard(
                    title: "Bluetooth LE",
                    icon: "dot.radiowaves.left.and.right",
                    active: model.bluetooth.isRunning,
                    status: model.bluetooth.isRunning ? "BLE 正在运行" : "BLE 未启动",
                    detail: "追踪 \(model.bluetooth.linkSnapshots.count) 条链路快照",
                    peerCount: model.bluetooth.connectedPeerCount
                )

                Button {
                    model.lanTurbo.refresh()
                    if !model.bluetooth.isRunning {
                        model.bluetooth.start()
                    }
                } label: {
                    Label("刷新本地链路", systemImage: "arrow.clockwise")
                }
                .buttonStyle(VeilPhysicalButtonStyle(accent: true))

                privacyNote("只刷新 VeilLink 自己的 Bonjour/BLE 发现，不进行互联网测速、端口扫描或局域网设备探测。")
            }
            .padding(16)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("链路仪表")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func linkCard(
        title: String,
        icon: String,
        active: Bool,
        status: String,
        detail: String,
        peerCount: Int
    ) -> some View {
        VeilInstrumentDeck(
            title: title,
            subtitle: detail,
            symbol: icon,
            emphasized: active
        ) {
            HStack(spacing: 10) {
                VeilLCDDisplay(title: "STATE", value: active ? "ONLINE" : "STANDBY")
                    .frame(maxWidth: .infinity)
                VeilLCDDisplay(title: "PEERS", value: "\(peerCount)")
                    .frame(maxWidth: .infinity)
            }
            VeilGaugeMeter(
                title: "LINK ACTIVITY",
                value: active ? min(1, 0.28 + Double(peerCount) * 0.18) : 0,
                text: active ? status : "OFF"
            )
        }
    }
}

private let veilToolTextByteLimit = 128 * 1_024

private enum VeilToolClipboard {
    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let item: [String: Any] = [UTType.utf8PlainText.identifier: text]
        UIPasteboard.general.setItems(
            [item],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(5 * 60)
            ]
        )
    }
}

private func boundedToolText(_ text: Binding<String>) -> Binding<String> {
    Binding(
        get: { text.wrappedValue },
        set: { value in
            guard value.utf8.count > veilToolTextByteLimit else {
                text.wrappedValue = value
                return
            }
            var data = Data(value.utf8.prefix(veilToolTextByteLimit))
            while !data.isEmpty, String(data: data, encoding: .utf8) == nil {
                data.removeLast()
            }
            text.wrappedValue = String(data: data, encoding: .utf8) ?? ""
        }
    )
}

private func toolInputMeter(_ text: String) -> some View {
    Text("\(text.utf8.count) / \(veilToolTextByteLimit / 1_024) KiB")
        .font(.caption2.monospacedDigit())
        .foregroundColor(VeilTheme.tertiaryText)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel("输入大小 \(text.utf8.count) 字节，上限 \(veilToolTextByteLimit) 字节")
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
        content
            .background(
                VeilInstrumentPlate(
                    shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    emphasized: false
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: max(2, cornerRadius - 2), style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
                    .padding(2)
            )
    }
}

extension View {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .background(VeilInstrumentBackground())
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
                .animation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion), value: pressed)
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
            VeilToggleLever(title: "开放给附近已信任设备", isOn: $openToTrustedNearby)
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
        .veilCompactToolSurface(cornerRadius: 16)
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
