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
                    if matches("手电筒信标 手电筒 信标 闪光灯 sos flashlight beacon") {
                        toolLink("手电筒信标", detail: "常亮 · 脉冲 · SOS", icon: "flashlight.on.fill", destination: VeilBeaconView())
                    }
                    if matches("双轴水平仪 水平仪 陀螺仪 重力 找平 level gyro") {
                        toolLink("双轴水平仪", detail: "实时横滚与俯仰 · 校零", icon: "level.fill", destination: VeilSpiritLevelView())
                    }
                    if matches("声级与波形 声级 波形 麦克风 音频 sound scope") {
                        toolLink("声级与波形", detail: "本机麦克风实时采样", icon: "waveform", destination: VeilSoundScopeView())
                    }
                    if matches("屏幕节拍器 节拍器 bpm 节拍 触感 metronome") {
                        toolLink("屏幕节拍器", detail: "30–240 BPM · TAP 测速", icon: "metronome.fill", destination: VeilScreenMetronomeView())
                    }
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
                    if matches("json 格式化 校验 压缩 pretty minify") {
                        toolLink("JSON 工坊", detail: "校验 · 整理 · 压缩", icon: "curlybraces", destination: VeilJSONToolView())
                    }
                    if matches("base64 编码 解码 utf8") {
                        toolLink("Base64", detail: "UTF-8 本地编解码", icon: "textformat.abc", destination: VeilTextCodecToolView(kind: .base64))
                    }
                    if matches("url uri 百分号 percent 编码 解码") {
                        toolLink("URL 编码", detail: "RFC 3986 百分号转码", icon: "link", destination: VeilTextCodecToolView(kind: .urlPercent))
                    }
                    if matches("时间戳 timestamp unix iso8601 日期 时间") {
                        toolLink("时间戳", detail: "Unix ↔ ISO 8601 UTC", icon: "clock.arrow.2.circlepath", destination: VeilTimestampToolView())
                    }
                    if matches("uuid guid 唯一 标识符 批量") {
                        toolLink("UUID 批量", detail: "本地生成 · 一键复制", icon: "barcode", destination: VeilUUIDToolView())
                    }
                    if matches("文本 清理 去重 排序 空行 trim clean") {
                        toolLink("文本清理", detail: "修剪 · 去重 · 排序", icon: "text.alignleft", destination: VeilTextCleanerToolView())
                    }
                    if matches("颜色 color hex rgb 转换 色块") {
                        toolLink("颜色实验室", detail: "HEX ↔ RGB · 色块预览", icon: "paintpalette.fill", destination: VeilColorLabToolView())
                    }
                    if matches("随机 决策 抽签 骰子 硬币 random dice") {
                        toolLink("随机决策", detail: "抽签 · 硬币 · 多面骰", icon: "die.face.5.fill", destination: VeilRandomDecisionToolView())
                    }
                    if matches("摩斯 morse 电码 编码 解码 sos") {
                        toolLink("摩斯电码", detail: "A–Z / 0–9 双向转换", icon: "waveform.path", destination: VeilMorseToolView())
                    }
                }
                .animation(VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion), value: query)
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
                        VeilToolClipboard.copy(generated)
                        copied = true
                    }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                    .disabled(generated.isEmpty)
                }
                privacyNote("密码仅在本机内存中生成；复制内容仅留在本设备，并会在 5 分钟后过期。")
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
            VStack(spacing: 16) {
                TextEditor(text: boundedToolText($text))
                    .font(.body)
                    .frame(minHeight: 170)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                toolInputMeter(text)
                let metrics = VeilLocalToolEngine.detailedTextMetrics(text)
                HStack(spacing: 8) {
                    metric("字符", "\(metrics.characters)")
                    metric("词数", "\(metrics.words)")
                    metric("行", "\(metrics.lines)")
                }
                HStack(spacing: 8) {
                    metric("UTF-8", "\(metrics.utf8Bytes) B")
                    metric("标量", "\(metrics.unicodeScalars)")
                    metric("ASCII", "\(metrics.asciiRatioPermille / 10)%")
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("SHA-256").font(.caption.bold()).foregroundColor(VeilTheme.mutedGold)
                    Text(VeilLocalToolEngine.sha256(text))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("复制指纹") { VeilToolClipboard.copy(VeilLocalToolEngine.sha256(text)) }
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
                    Button("复制原文") { VeilToolClipboard.copy(text) }
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
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                TextEditor(text: boundedToolText($input))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                toolInputMeter(input)
                HStack(spacing: 9) {
                    Button("整理") { transform(pretty: true) }.buttonStyle(VeilGamePrimaryButtonStyle())
                    Button("压缩") { transform(pretty: false) }.buttonStyle(VeilGameSecondaryButtonStyle())
                    Button("复制") { VeilToolClipboard.copy(output) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                        .disabled(output.isEmpty)
                }
                if let errorText {
                    Label(errorText, systemImage: "xmark.octagon.fill")
                        .font(.caption).foregroundColor(VeilTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !output.isEmpty {
                    Label("JSON 有效 · 键名已稳定排序", systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundColor(VeilTheme.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let structure = try? VeilLocalToolEngine.jsonStructureMetrics(input), !input.isEmpty {
                    HStack(spacing: 8) {
                        metric("节点", "\(structure.totalNodes)")
                        metric("键", "\(structure.keyCount)")
                        metric("深度", "\(structure.maxDepth)")
                    }
                }
                if !output.isEmpty {
                    Text(output)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .veilCompactToolSurface(cornerRadius: 12)
                }
                privacyNote("JSON 仅在本机解析；错误提示不会包含或记录你的输入内容。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("JSON 工坊")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in
            output = ""
            errorText = nil
        }
    }

    private func transform(pretty: Bool) {
        do {
            output = try (pretty ? VeilLocalToolEngine.prettyJSON(input) : VeilLocalToolEngine.minifiedJSON(input))
            errorText = nil
        } catch {
            output = ""
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
    @State private var errorText: String?
    @State private var encodingMetrics: VeilEncodingMetrics?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(kind.detail).font(.caption).foregroundColor(VeilTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: boundedToolText($input))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 140)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                toolInputMeter(input)
                HStack(spacing: 9) {
                    Button("编码") { encode() }.buttonStyle(VeilGamePrimaryButtonStyle())
                    Button("解码") { decode() }.buttonStyle(VeilGameSecondaryButtonStyle())
                    Button("复制") { VeilToolClipboard.copy(output) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                        .disabled(output.isEmpty)
                }
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(VeilTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let encodingMetrics {
                    HStack(spacing: 8) {
                        metric("输入", "\(encodingMetrics.inputBytes) B")
                        metric("输出", "\(encodingMetrics.outputBytes) B")
                        metric("变化", "\(encodingMetrics.expansionPercent)%")
                    }
                }
                Text(output.isEmpty ? "结果会显示在这里" : output)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .padding(12)
                    .veilCompactToolSurface(cornerRadius: 12)
                privacyNote("编解码完全离线。Base64 不是加密，请勿把它当成机密保护。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in
            output = ""
            errorText = nil
            encodingMetrics = nil
        }
    }

    private func encode() {
        output = kind == .base64
            ? VeilLocalToolEngine.base64EncodeUTF8(input)
            : VeilLocalToolEngine.urlPercentEncode(input)
        encodingMetrics = kind == .base64
            ? VeilLocalToolEngine.base64EncodingMetrics(input)
            : VeilLocalToolEngine.urlPercentEncodingMetrics(input)
        errorText = nil
    }

    private func decode() {
        do {
            output = try (kind == .base64
                ? VeilLocalToolEngine.base64DecodeUTF8(input)
                : VeilLocalToolEngine.urlPercentDecode(input))
            encodingMetrics = nil
            errorText = nil
        } catch {
            output = ""
            encodingMetrics = nil
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("UNIX → UTC").font(.caption.bold()).foregroundColor(VeilTheme.mutedGold)
                    TextField(usesMilliseconds ? "毫秒，例如 1700000000123" : "秒，例如 1700000000", text: $timestamp)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                    Toggle("输入为毫秒", isOn: $usesMilliseconds).tint(VeilTheme.gold)
                    Button("转换为 ISO 8601") { timestampToISO() }.buttonStyle(VeilGamePrimaryButtonStyle())
                }
                .veilCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("UTC → UNIX").font(.caption.bold()).foregroundColor(VeilTheme.mutedGold)
                    TextField("2023-11-14T22:13:20.123Z", text: $iso8601)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                    Button("转换为时间戳") { isoToTimestamp() }.buttonStyle(VeilGameSecondaryButtonStyle())
                }
                .veilCard()
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(VeilTheme.danger)
                }
                if !result.isEmpty {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .veilCompactToolSurface(cornerRadius: 12)
                }
                HStack(spacing: 9) {
                    Button("填入当前时间") {
                        let now = Date().timeIntervalSince1970
                        timestamp = usesMilliseconds ? String(Int64((now * 1_000).rounded())) : String(Int64(now))
                        timestampToISO()
                    }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                    Button("复制结果") { VeilToolClipboard.copy(result) }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                    .disabled(result.isEmpty)
                }
                privacyNote("使用 UTC 进行转换；不读取日历、定位或网络时间。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
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
                HStack(spacing: 10) {
                    Text("数量").font(.caption.weight(.semibold))
                    Slider(value: $count, in: 1...20, step: 1).tint(VeilTheme.gold)
                    Text("\(Int(count))").font(.caption.monospacedDigit()).frame(width: 28)
                }
                .veilCard()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(12)
                .veilCompactToolSurface(cornerRadius: 14)
                HStack(spacing: 10) {
                    Button("重新生成") { generate() }.buttonStyle(VeilGamePrimaryButtonStyle())
                    Button("复制全部") { VeilToolClipboard.copy(values.joined(separator: "\n")) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                        .disabled(values.isEmpty)
                }
                privacyNote("使用系统 UUID 生成器，不读取设备标识，不把结果关联到 VeilLink 身份。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
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
                TextEditor(text: boundedToolText($input))
                    .frame(minHeight: 140)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                toolInputMeter(input)
                VStack(spacing: 9) {
                    Toggle("修剪每行首尾空白", isOn: $options.trimsLines)
                    Toggle("连续空行压成一行", isOn: $options.collapsesBlankLines)
                    Toggle("删除重复行", isOn: $options.removesDuplicateLines)
                    Toggle("按字符顺序排序", isOn: $options.sortsLines)
                }
                .tint(VeilTheme.gold)
                .veilCard()
                HStack(spacing: 9) {
                    Button("清理") { output = VeilLocalToolEngine.cleanText(input, options: options) }
                        .buttonStyle(VeilGamePrimaryButtonStyle())
                    Button("复制") { VeilToolClipboard.copy(output) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                        .disabled(output.isEmpty)
                }
                Text(output.isEmpty ? "清理结果会显示在这里" : output)
                    .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                    .padding(12)
                    .veilCompactToolSurface(cornerRadius: 12)
                privacyNote("文本只在当前页面内处理；排序采用稳定、可复现的字符顺序。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: Double(preview.red) / 255, green: Double(preview.green) / 255, blue: Double(preview.blue) / 255))
                    .frame(height: 150)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .accessibilityLabel("颜色预览 \(hex)")
                VStack(spacing: 10) {
                    TextField("#RRGGBB", text: $hex)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        colorField("R", text: $red)
                        colorField("G", text: $green)
                        colorField("B", text: $blue)
                    }
                }
                .veilCard()
                HStack(spacing: 9) {
                    Button("HEX → RGB") { fromHex() }.buttonStyle(VeilGamePrimaryButtonStyle())
                    Button("RGB → HEX") { fromRGB() }.buttonStyle(VeilGameSecondaryButtonStyle())
                }
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(VeilTheme.danger)
                }
                if let contrast = try? VeilLocalToolEngine.colorContrast(rgb: preview) {
                    HStack(spacing: 8) {
                        metric("黑字对比", String(format: "%.1f:1", contrast.contrastWithBlack))
                        metric("白字对比", String(format: "%.1f:1", contrast.contrastWithWhite))
                        metric("建议前景", contrast.preferredForeground == .black ? "黑色" : "白色")
                    }
                    Label(
                        contrast.meetsAANormalText ? "推荐前景符合 WCAG AA 正文标准" : "仅建议用于大字号或装饰内容",
                        systemImage: contrast.meetsAANormalText ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(contrast.meetsAANormalText ? VeilTheme.success : VeilTheme.warning)
                }
                Button("复制 \(lastValidatedHex)") { VeilToolClipboard.copy(lastValidatedHex) }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                    .disabled(!isValidatedColor)
                privacyNote("颜色转换不读取照片或屏幕内容；复制内容仅留在本设备，并会在 5 分钟后过期。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("颜色实验室")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorField(_ title: String, text: Binding<String>) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption2.bold()).foregroundColor(VeilTheme.tertiaryText)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
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
            red = String(value.red); green = String(value.green); blue = String(value.blue)
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
            guard let r = Int(red), let g = Int(green), let b = Int(blue) else { throw VeilLocalToolError.rgbOutOfRange }
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
                Text(result)
                    .font(.title3.bold())
                    .foregroundColor(VeilTheme.goldBright)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .veilCard(emphasized: true)
                TextEditor(text: boundedToolText($choices))
                    .frame(minHeight: 120)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                toolInputMeter(choices)
                HStack(spacing: 9) {
                    Button("抽一个") { pick() }.buttonStyle(VeilGamePrimaryButtonStyle())
                    Button("抛硬币") { coin() }.buttonStyle(VeilGameSecondaryButtonStyle())
                }
                HStack(spacing: 9) {
                    TextField("面数", text: $diceSides).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    TextField("数量", text: $diceCount).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Button("掷骰") { roll() }.buttonStyle(VeilGameSecondaryButtonStyle())
                }
                if let errorText {
                    Text(errorText).font(.caption).foregroundColor(VeilTheme.danger)
                }
                privacyNote("使用系统安全随机源；结果不联网、不上报，也不会替你承担决定的后果。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("随机决策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var parsedChoices: [String] {
        choices.split(whereSeparator: { $0.isNewline }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func pick() {
        do { result = try VeilLocalToolEngine.randomChoice(from: parsedChoices); errorText = nil }
        catch { errorText = (error as? LocalizedError)?.errorDescription }
    }

    private func coin() {
        do { result = try VeilLocalToolEngine.randomChoice(from: ["正面", "反面"]); errorText = nil }
        catch { errorText = (error as? LocalizedError)?.errorDescription }
    }

    private func roll() {
        do {
            guard let sides = Int(diceSides), let count = Int(diceCount) else { throw VeilLocalToolError.invalidDice }
            let values = try VeilLocalToolEngine.rollDice(sides: sides, count: count)
            result = values.map(String.init).joined(separator: " + ") + " = \(values.reduce(0, +))"
            errorText = nil
        } catch { errorText = (error as? LocalizedError)?.errorDescription }
    }
}

struct VeilMorseToolView: View {
    @State private var input = ""
    @State private var output = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                TextEditor(text: boundedToolText($input))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 130)
                    .padding(8)
                    .veilCompactToolSurface(cornerRadius: 14)
                toolInputMeter(input)
                HStack(spacing: 9) {
                    Button("编码") { output = VeilLocalToolEngine.morseEncode(input) }.buttonStyle(VeilGamePrimaryButtonStyle())
                    Button("解码") { output = VeilLocalToolEngine.morseDecode(input) }.buttonStyle(VeilGameSecondaryButtonStyle())
                    Button("复制") { VeilToolClipboard.copy(output) }
                        .buttonStyle(VeilGameSecondaryButtonStyle()).disabled(output.isEmpty)
                }
                Text(output.isEmpty ? "... --- ..." : output)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.goldBright)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .padding(12)
                    .veilCompactToolSurface(cornerRadius: 12)
                privacyNote("支持 A–Z 与 0–9；词间使用 /。不支持的字符显示为 ?，转换完全离线。")
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("摩斯电码")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _ in output = "" }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        let budget = VeilSkeuomorphicPerformance.currentBudget(
            for: .toolPanel,
            reduceMotionRequested: reduceMotion
        )
        if budget.allowsBackdropMaterial {
            content
                .background(.ultraThinMaterial)
                .background(VeilTheme.elevated.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 0.8))
                .shadow(
                    color: Color.black.opacity(budget.outerShadowLayers > 0 ? 0.14 : 0),
                    radius: CGFloat(budget.maxShadowRadius),
                    y: budget.outerShadowLayers > 0 ? 2 : 0
                )
        } else {
            content
                .background(VeilTheme.elevated.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))
                .shadow(
                    color: Color.black.opacity(budget.outerShadowLayers > 0 ? 0.10 : 0),
                    radius: CGFloat(budget.maxShadowRadius),
                    y: budget.outerShadowLayers > 0 ? 1 : 0
                )
        }
    }
}

extension View {
    func veilCompactToolSurface(cornerRadius: CGFloat) -> some View {
        modifier(VeilCompactToolSurface(cornerRadius: cornerRadius))
    }
}

struct VeilWalkieTalkieView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var radio: VeilWalkieTalkieAudioController
    @State private var openToTrustedNearby = true
    @State private var selectedPeerIDs = Set<String>()
    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) {
        self.model = model
        _radio = ObservedObject(wrappedValue: model.walkieTalkie)
    }

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
        .onDisappear {
            if radio.state == .transmitting || radio.state == .preparing {
                radio.endTransmit()
            }
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
                Text("G.711 µ-law · 8 kHz · 40 ms")
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
