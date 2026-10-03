import AVFoundation
import Combine
import SwiftUI

@MainActor
final class VeilBeaconController: ObservableObject {
    @Published private(set) var state: VeilLiveToolState = .idle
    @Published private(set) var isTorchOn = false
    @Published private(set) var activePattern: VeilBeaconPattern?
    @Published private(set) var remainingSeconds: Int = 0

    private let device: AVCaptureDevice?
    private var segmentTimer: Timer?
    private var safetyTimer: Timer?
    private var countdownTimer: Timer?
    private var segmentIndex = 0
    private var intensity: Float = 0.65
    private let maximumRunSeconds = 180

    init() {
        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        device = camera
        if camera?.hasTorch != true {
            state = .unavailable("此设备没有可用的后置闪光灯。")
        }
    }

    func start(pattern: VeilBeaconPattern, intensity: Double) {
        guard device?.hasTorch == true else {
            state = .unavailable("此设备没有可用的后置闪光灯。")
            return
        }
        stop(resetState: false)
        self.intensity = Float(max(0.1, min(1, intensity)))
        activePattern = pattern
        segmentIndex = 0
        remainingSeconds = maximumRunSeconds
        state = .running
        runCurrentSegment()

        safetyTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(maximumRunSeconds), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        let countdown = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state.isRunning else { return }
                self.remainingSeconds = max(0, self.remainingSeconds - 1)
            }
        }
        countdown.tolerance = 0.1
        RunLoop.main.add(countdown, forMode: .common)
        countdownTimer = countdown
    }

    func updateIntensity(_ value: Double) {
        intensity = Float(max(0.1, min(1, value)))
        if isTorchOn { setTorch(on: true) }
    }

    func stop() { stop(resetState: true) }

    private func stop(resetState: Bool) {
        segmentTimer?.invalidate()
        segmentTimer = nil
        safetyTimer?.invalidate()
        safetyTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        setTorch(on: false)
        activePattern = nil
        remainingSeconds = 0
        if resetState, state.isRunning { state = .idle }
    }

    private func runCurrentSegment() {
        guard state.isRunning, let pattern = activePattern else { return }
        let segments = pattern.segments
        guard !segments.isEmpty else { stop(); return }
        let segment = segments[segmentIndex % segments.count]
        setTorch(on: segment.isOn)
        guard pattern != .steady else { return }
        segmentIndex = (segmentIndex + 1) % segments.count
        let timer = Timer(timeInterval: 0.16 * segment.units, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.runCurrentSegment() }
        }
        timer.tolerance = min(0.018, timer.timeInterval * 0.08)
        RunLoop.main.add(timer, forMode: .common)
        segmentTimer = timer
    }

    private func setTorch(on: Bool) {
        guard let device, device.hasTorch else {
            isTorchOn = false
            return
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on, device.isTorchAvailable {
                try device.setTorchModeOn(level: min(intensity, AVCaptureDevice.maxAvailableTorchLevel))
                isTorchOn = true
            } else {
                device.torchMode = .off
                isTorchOn = false
            }
        } catch {
            segmentTimer?.invalidate()
            segmentTimer = nil
            isTorchOn = false
            state = .failed("闪光灯控制失败：\(error.localizedDescription)")
        }
    }
}

struct VeilBeaconView: View {
    @StateObject private var controller = VeilBeaconController()
    @State private var pattern: VeilBeaconPattern = .pulse
    @State private var intensity = 0.65
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("LOCAL LIGHT SIGNAL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.3)
                                .foregroundColor(VeilTheme.mutedGold)
                            Text("手电筒信标")
                                .font(.title2.bold())
                                .foregroundColor(VeilTheme.text)
                        }
                        Spacer()
                        VeilLiveStateBadge(state: controller.state)
                    }

                    ZStack {
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(VeilTheme.gold.opacity(controller.isTorchOn ? 0.2 : 0.05), lineWidth: 2)
                                .frame(width: CGFloat(98 + index * 34), height: CGFloat(98 + index * 34))
                                .scaleEffect(controller.isTorchOn && !reduceMotion ? 1.05 : 0.94)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: controller.isTorchOn)
                        }
                        Circle()
                            .fill(RadialGradient(colors: [Color.white, controller.isTorchOn ? VeilTheme.goldBright : VeilTheme.panelSoft, Color.black.opacity(0.78)], center: .center, startRadius: 2, endRadius: 70))
                            .frame(width: 112, height: 112)
                            .shadow(color: VeilTheme.gold.opacity(controller.isTorchOn ? 0.8 : 0.08), radius: controller.isTorchOn ? 30 : 6)
                        Image(systemName: controller.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundColor(controller.isTorchOn ? Color.black.opacity(0.72) : VeilTheme.tertiaryText)
                    }
                    .frame(height: 190)

                    if controller.state.isRunning {
                        Text("安全停止倒计时  \(controller.remainingSeconds / 60):\(String(format: "%02d", controller.remainingSeconds % 60))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                }
                .veilCard(emphasized: true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("信号模式")
                        .font(.headline)
                        .foregroundColor(VeilTheme.text)
                    HStack(spacing: 8) {
                        ForEach(VeilBeaconPattern.allCases) { option in
                            Button {
                                pattern = option
                                if controller.state.isRunning {
                                    controller.start(pattern: option, intensity: intensity)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: option.systemImage)
                                        .font(.title3)
                                    Text(option.title).font(.caption.bold())
                                }
                                .foregroundColor(pattern == option ? Color.black : VeilTheme.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 66)
                                .background(pattern == option ? VeilTheme.gold : VeilTheme.panelSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Image(systemName: "sun.min")
                        Slider(value: $intensity, in: 0.1...1) { editing in
                            if !editing { controller.updateIntensity(intensity) }
                        }
                        .tint(VeilTheme.gold)
                        Image(systemName: "sun.max.fill")
                    }
                    .foregroundColor(VeilTheme.secondaryText)
                    .disabled(controller.state.isRunning)
                }
                .veilCard()

                VeilLiveStatusPanel(
                    state: controller.state,
                    title: "无需相机权限，不拍摄图像",
                    detail: "请勿直射眼睛、车辆或航空器。连续运行可能使设备升温，信标会在 3 分钟后自动关闭；退到后台也会立即关闭。"
                )

                if controller.state.isRunning {
                    Button("立即关闭信标") { controller.stop() }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                } else {
                    Button("启动 \(pattern.title) 信标") {
                        controller.start(pattern: pattern, intensity: intensity)
                    }
                    .buttonStyle(VeilGamePrimaryButtonStyle())
                }
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("手电筒信标")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { phase in
            if phase != .active { controller.stop() }
        }
        .onDisappear { controller.stop() }
    }
}
