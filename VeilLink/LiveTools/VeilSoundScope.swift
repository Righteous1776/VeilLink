import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class VeilSoundScopeController: ObservableObject {
    @Published private(set) var state: VeilLiveToolState = .idle
    @Published private(set) var reading: VeilSoundReading = .silence
    @Published private(set) var waveform: [Double] = Array(repeating: 0, count: 64)

    private let engine = AVAudioEngine()
    private let updateThrottle = VeilSoundScopeThrottle(minimumInterval: 1.0 / 15.0)
    private var tapInstalled = false
    private var generation: UInt64 = 0
    private var previousAudioConfiguration: VeilAudioSessionConfiguration?
    private var changedAudioConfiguration = false

    var authorizationLabel: String {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return "麦克风权限：已允许"
        case .denied: return "麦克风权限：已关闭"
        case .undetermined: return "麦克风权限：尚未询问"
        @unknown default: return "麦克风权限：未知"
        }
    }

    func toggle() {
        state.isRunning ? stop() : requestAndStart()
    }

    func requestAndStart() {
        guard !state.isRunning else { return }
        generation &+= 1
        let requestedGeneration = generation
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            startCapture()
        case .denied:
            state = .denied("麦克风权限已关闭，可前往系统设置重新允许。")
        case .undetermined:
            state = .requestingPermission
            session.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self, self.generation == requestedGeneration else { return }
                    if granted { self.startCapture() }
                    else { self.state = .denied("没有麦克风权限，声级与波形不会启动。") }
                }
            }
        @unknown default:
            state = .failed("无法读取系统麦克风权限状态。")
        }
    }

    func stop() {
        generation &+= 1
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        restoreAudioConfigurationIfOwned()
        reading = .silence
        waveform = Array(repeating: 0, count: waveform.count)
        if state.isRunning || state == .requestingPermission { state = .idle }
    }

    private func startCapture() {
        let captureGeneration = generation
        do {
            let session = AVAudioSession.sharedInstance()
            previousAudioConfiguration = VeilAudioSessionConfiguration(session: session)
            let inputCapable = session.category == .record || session.category == .playAndRecord || session.category == .multiRoute
            changedAudioConfiguration = !inputCapable
            if changedAudioConfiguration {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
                try session.setPreferredIOBufferDuration(0.02)
            }
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw VeilSoundScopeError.noInput
            }
            let updateThrottle = updateThrottle
            input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
                guard updateThrottle.shouldPublish() else { return }
                guard let channel = buffer.floatChannelData?.pointee else { return }
                let frameCount = Int(buffer.frameLength)
                guard frameCount > 0 else { return }
                let samples = Array(UnsafeBufferPointer(start: channel, count: frameCount))
                var squareSum = 0.0
                var peak = 0.0
                for sample in samples {
                    let value = abs(Double(sample))
                    squareSum += value * value
                    peak = max(peak, value)
                }
                let rms = sqrt(squareSum / Double(frameCount))
                let reading = VeilLiveToolMath.soundReading(rms: rms, peak: peak)
                let waveform = VeilLiveToolMath.downsample(samples, count: 64)
                Task { @MainActor [weak self] in
                    guard let self, self.generation == captureGeneration, self.state.isRunning else { return }
                    self.reading = reading
                    self.waveform = waveform
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            state = .running
        } catch {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            engine.stop()
            restoreAudioConfigurationIfOwned()
            state = .failed("音频输入启动失败：\(error.localizedDescription)")
        }
    }

    private func restoreAudioConfigurationIfOwned() {
        defer {
            previousAudioConfiguration = nil
            changedAudioConfiguration = false
        }
        guard changedAudioConfiguration, let previousAudioConfiguration else { return }
        let session = AVAudioSession.sharedInstance()
        // If another recorder changed the process-wide session after us, it owns
        // the new configuration and must not be disturbed by this diagnostic.
        guard session.category == .playAndRecord, session.mode == .measurement else { return }
        try? session.setCategory(
            previousAudioConfiguration.category,
            mode: previousAudioConfiguration.mode,
            options: previousAudioConfiguration.options
        )
        try? session.setPreferredIOBufferDuration(previousAudioConfiguration.ioBufferDuration)
    }
}

private struct VeilAudioSessionConfiguration {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
    let ioBufferDuration: TimeInterval

    init(session: AVAudioSession) {
        category = session.category
        mode = session.mode
        options = session.categoryOptions
        ioBufferDuration = session.preferredIOBufferDuration
    }
}

private final class VeilSoundScopeThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private let minimumInterval: TimeInterval
    private var lastPublishTime: TimeInterval = 0

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    func shouldPublish(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard now - lastPublishTime >= minimumInterval else { return false }
        lastPublishTime = now
        return true
    }
}

private enum VeilSoundScopeError: LocalizedError {
    case noInput

    var errorDescription: String? { "此设备当前没有可用的音频输入。" }
}

struct VeilSoundScopeView: View {
    @StateObject private var controller = VeilSoundScopeController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("LIVE INPUT")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(VeilTheme.mutedGold)
                            Text("实时声级")
                                .font(.title2.bold())
                                .foregroundColor(VeilTheme.text)
                        }
                        Spacer()
                        Text(String(format: "%.1f", controller.reading.decibels))
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(levelColor)
                        Text("dBFS")
                            .font(.caption.bold())
                            .foregroundColor(VeilTheme.secondaryText)
                    }

                    VeilWaveformView(samples: controller.waveform, level: controller.reading.normalizedLevel)
                        .frame(height: 150)
                        .animation(reduceMotion ? nil : .linear(duration: 0.04), value: controller.waveform)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(VeilTheme.panelSoft)
                            Capsule()
                                .fill(LinearGradient(colors: [VeilTheme.gold, .orange, .red], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geometry.size.width * controller.reading.normalizedLevel)
                        }
                    }
                    .frame(height: 9)

                    HStack {
                        Text("-80")
                        Spacer()
                        Text("实时峰值 \(String(format: "%.1f", controller.reading.peakDecibels))")
                        Spacer()
                        Text("0 dBFS")
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
                }
                .veilCard(emphasized: true)

                VeilLiveStatusPanel(
                    state: controller.state,
                    title: controller.authorizationLabel,
                    detail: "采样只在内存中形成波形，不录音、不保存、不联网。这里显示的是数字满刻度 dBFS，并非校准后的环境分贝 SPL。"
                )

                if case .denied = controller.state {
                    Button("打开系统设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                }

                if controller.state.isRunning {
                    Button("停止监听") { controller.stop() }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                } else {
                    Button("开始实时监听") { controller.requestAndStart() }
                        .buttonStyle(VeilGamePrimaryButtonStyle())
                }
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("声级与波形")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { phase in
            if phase != .active { controller.stop() }
        }
        .onDisappear { controller.stop() }
    }

    private var levelColor: Color {
        switch controller.reading.normalizedLevel {
        case ..<0.55: return VeilTheme.goldBright
        case ..<0.82: return .orange
        default: return .red
        }
    }
}

private struct VeilWaveformView: View {
    let samples: [Double]
    let level: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                ForEach(1..<4) { index in
                    Path { path in
                        let y = geometry.size.height * CGFloat(index) / 4
                        path.move(to: CGPoint(x: 12, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width - 12, y: y))
                    }
                    .stroke(VeilTheme.gold.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                }
                waveformPath(in: geometry.size)
                    .stroke(
                        LinearGradient(colors: [VeilTheme.gold.opacity(0.45), VeilTheme.goldBright, .orange], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: VeilTheme.gold.opacity(0.2 + level * 0.45), radius: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("实时音频波形")
        .accessibilityValue("声级 \(Int(level * 100)) 百分比")
    }

    private func waveformPath(in size: CGSize) -> Path {
        var path = Path()
        guard samples.count > 1 else { return path }
        let midY = size.height / 2
        let usableHeight = max(1, size.height - 22)
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) / CGFloat(samples.count - 1) * size.width
            let direction: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let y = midY + direction * CGFloat(sample) * usableHeight * 0.5
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}
