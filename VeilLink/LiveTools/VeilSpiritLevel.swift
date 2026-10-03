import Combine
import CoreMotion
import SwiftUI

@MainActor
final class VeilSpiritLevelController: ObservableObject {
    @Published private(set) var state: VeilLiveToolState = .idle
    @Published private(set) var roll: Double = 0
    @Published private(set) var pitch: Double = 0
    @Published private(set) var calibrated = false

    private let motion = CMMotionManager()
    private var rollOffset = 0.0
    private var pitchOffset = 0.0

    var maximumDeviation: Double { max(abs(roll), abs(pitch)) }
    var isLevel: Bool { maximumDeviation <= 1 }

    func start() {
        guard !state.isRunning else { return }
        guard motion.isDeviceMotionAvailable else {
            state = .unavailable("此设备没有可用的陀螺仪/重力感应数据。")
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        state = .running
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] sample, error in
            guard let self else { return }
            if let error {
                self.motion.stopDeviceMotionUpdates()
                self.state = .failed("运动传感器读取失败：\(error.localizedDescription)")
                return
            }
            guard let gravity = sample?.gravity else { return }
            let angles = VeilLiveToolMath.levelAngles(
                gravityX: gravity.x,
                gravityY: gravity.y,
                gravityZ: gravity.z
            )
            self.roll = angles.roll - self.rollOffset
            self.pitch = angles.pitch - self.pitchOffset
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        if state.isRunning { state = .idle }
    }

    func calibrate() {
        rollOffset += roll
        pitchOffset += pitch
        roll = 0
        pitch = 0
        calibrated = true
    }

    func clearCalibration() {
        rollOffset = 0
        pitchOffset = 0
        calibrated = false
    }
}

struct VeilSpiritLevelView: View {
    @StateObject private var controller = VeilSpiritLevelController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("60 HZ MOTION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(VeilTheme.mutedGold)
                            Text("双轴水平仪")
                                .font(.title2.bold())
                                .foregroundColor(VeilTheme.text)
                        }
                        Spacer()
                        VeilLiveStateBadge(state: controller.state)
                    }

                    VeilBubbleLevel(
                        roll: controller.roll,
                        pitch: controller.pitch,
                        active: controller.state.isRunning,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: 250, height: 250)

                    HStack(spacing: 10) {
                        angleReadout(title: "横滚 ROLL", value: controller.roll)
                        angleReadout(title: "俯仰 PITCH", value: controller.pitch)
                    }

                    HStack(spacing: 7) {
                        Circle()
                            .fill(controller.isLevel && controller.state.isRunning ? Color.green : VeilTheme.tertiaryText)
                            .frame(width: 8, height: 8)
                        Text(controller.isLevel && controller.state.isRunning ? "已进入 ±1.0° 水平区" : "最大偏差 \(String(format: "%.1f", controller.maximumDeviation))°")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                }
                .veilCard(emphasized: true)

                VeilLiveStatusPanel(
                    state: controller.state,
                    title: controller.calibrated ? "已使用当前表面校零" : "使用系统重力与陀螺仪",
                    detail: "无需任何系统权限，数据只在本机内存中更新。用于日常找平，不替代经过认证的工程测量仪器。"
                )

                HStack(spacing: 10) {
                    Button(controller.calibrated ? "恢复系统零点" : "以当前角度校零") {
                        controller.calibrated ? controller.clearCalibration() : controller.calibrate()
                    }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                    .disabled(!controller.state.isRunning)

                    if controller.state.isRunning {
                        Button("停止") { controller.stop() }
                            .buttonStyle(VeilGameSecondaryButtonStyle())
                    } else {
                        Button("启动实时水平仪") { controller.start() }
                            .buttonStyle(VeilGamePrimaryButtonStyle())
                    }
                }
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("陀螺仪水平仪")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.start() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { controller.start() }
            else { controller.stop() }
        }
        .onDisappear { controller.stop() }
    }

    private func angleReadout(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(VeilTheme.tertiaryText)
            Text(String(format: "%+.1f°", value))
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(abs(value) <= 1 ? .green : VeilTheme.goldBright)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(VeilTheme.panelSoft.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct VeilBubbleLevel: View {
    let roll: Double
    let pitch: Double
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) * 0.37
            let offset = VeilLiveToolMath.clampedBubbleOffset(roll: roll, pitch: pitch, radius: Double(radius))
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [VeilTheme.panelSoft, Color.black.opacity(0.72)], center: .center, startRadius: 2, endRadius: radius * 1.4))
                    .overlay(Circle().stroke(VeilTheme.gold.opacity(0.45), lineWidth: 2))
                ForEach([0.32, 0.62, 0.92], id: \.self) { scale in
                    Circle()
                        .stroke(VeilTheme.gold.opacity(scale == 0.32 ? 0.32 : 0.13), lineWidth: scale == 0.32 ? 1.5 : 0.7)
                        .scaleEffect(scale)
                }
                Rectangle().fill(VeilTheme.gold.opacity(0.18)).frame(width: 1, height: radius * 1.8)
                Rectangle().fill(VeilTheme.gold.opacity(0.18)).frame(width: radius * 1.8, height: 1)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.98), active ? VeilTheme.goldBright : .gray, active ? VeilTheme.gold : .gray.opacity(0.5)],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 34
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                    .shadow(color: (abs(roll) <= 1 && abs(pitch) <= 1 ? Color.green : VeilTheme.gold).opacity(0.45), radius: 12)
                    .offset(x: CGFloat(offset.x), y: CGFloat(offset.y))
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.18, dampingFraction: 0.78), value: roll)
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.18, dampingFraction: 0.78), value: pitch)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("双轴水平气泡")
        .accessibilityValue("横滚 \(String(format: "%.1f", roll)) 度，俯仰 \(String(format: "%.1f", pitch)) 度")
    }
}
