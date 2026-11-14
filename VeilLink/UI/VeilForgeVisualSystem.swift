import SwiftUI
import Foundation

/// Industrial atmosphere is static, bounded and input-transparent.
struct VeilForgeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [VeilTheme.backgroundLift, VeilTheme.background, VeilTheme.obsidian],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VeilForgeGrid(spacing: 36)
                .stroke(VeilTheme.hairline.opacity(0.35), lineWidth: 0.5)

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [VeilTheme.gold.opacity(0.70), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1.5)
                Spacer(minLength: 0)
                Rectangle().fill(VeilTheme.hairline).frame(height: 1)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct VeilForgeGrid: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rect.height > 0, spacing > 0 else { return path }
        for step in 0...Int(rect.width / spacing) {
            let x = CGFloat(step) * spacing
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        for step in 0...Int(rect.height / spacing) {
            let y = CGFloat(step) * spacing
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}

/// Consistent cut metal, engraved crossbars, orange datum mark.
/// An underlay only: it must never absorb drag/keyboard/pairing gestures.
struct VeilForgePlate: View {
    let emphasized: Bool

    var body: some View {
        let shape = VeilPanelShape(cut: emphasized ? 20 : 14, radius: 2)
        shape
            .fill(
                LinearGradient(
                    colors: [VeilAppearanceController.shared.palette.metalTop.opacity(0.70),
                             VeilTheme.panel,
                             VeilAppearanceController.shared.palette.metalBottom.opacity(0.73)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(shape.stroke(VeilTheme.gold.opacity(emphasized ? 0.55 : 0.24), lineWidth: 1))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(VeilTheme.goldBright)
                        .frame(width: emphasized ? 37 : 23, height: 2)
                    Rectangle()
                        .fill(VeilTheme.paleMetal.opacity(0.38))
                        .frame(width: 12, height: 2)
                }
                .padding(.leading, 12)
                .padding(.top, 1)
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    Circle().fill(VeilTheme.paleMetal.opacity(0.38)).frame(width: 2.5, height: 2.5)
                    Circle().fill(VeilTheme.paleMetal.opacity(0.38)).frame(width: 2.5, height: 2.5)
                }
                .padding(.trailing, 13)
                .padding(.bottom, 8)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
            .allowsHitTesting(false)
    }
}

/// Role-coded modular status, with genuine source values provided by callers.
struct VeilForgeDataRail: View {
    let label: String
    let value: String
    let active: Bool

    var body: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(active ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                .frame(width: 3, height: 10)
            Text(label)
                .foregroundColor(VeilTheme.mutedGold)
                .lineLimit(1)
            Text("//")
                .foregroundColor(VeilTheme.tertiaryText)
            Text(value)
                .foregroundColor(active ? VeilTheme.goldBright : VeilTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

/// Data-bound mechanical actuator; only local to RF/CPU modules.
/// ECLIPSE inspiration: deliberate hard contrast, calibrated ticks, measured state.
struct VeilForgeRotor: View {
    enum Kind {
        case radio
        case compute
        var mark: String {
            switch self {
            case .radio: return "RF"
            case .compute: return "CPU"
            }
        }
        var label: String {
            switch self {
            case .radio: return "射频扫描"
            case .compute: return "计算核心"
            }
        }
    }

    let kind: Kind
    let engaged: Bool
    let working: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var motorMoves: Bool {
        working && engaged && scenePhase == .active && !reduceMotion
            && !lowPowerMode && VeilMotionPolicy.allowsContinuousDecorativeMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = max(1, min(proxy.size.width, proxy.size.height))
            ZStack {
                VeilPanelShape(cut: diameter * 0.11, radius: 2)
                    .fill(VeilTheme.obsidian)
                VeilPanelShape(cut: diameter * 0.11, radius: 2)
                    .stroke(VeilTheme.gold.opacity(engaged ? 0.44 : 0.15), lineWidth: 1)

                ForEach(0..<24, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 6)
                              ? VeilTheme.gold.opacity(engaged ? 0.88 : 0.22)
                              : VeilTheme.paleMetal.opacity(0.25))
                        .frame(width: max(0.8, diameter * 0.013),
                               height: diameter * (index.isMultiple(of: 6) ? 0.09 : 0.045))
                        .offset(y: -diameter * 0.40)
                        .rotationEffect(.degrees(Double(index) * 15))
                }

                Circle()
                    .stroke(VeilTheme.hairline, lineWidth: 1)
                    .frame(width: diameter * 0.70, height: diameter * 0.70)

                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !motorMoves)) { timeline in
                    let angle = VeilForgeMotionCore.rotorAngle(
                        atSeconds: timeline.date.timeIntervalSinceReferenceDate,
                        working: motorMoves
                    )
                    ZStack {
                        Circle()
                            .trim(from: 0.03, to: 0.34)
                            .stroke(VeilTheme.goldBright.opacity(engaged ? 0.92 : 0.19),
                                    style: StrokeStyle(lineWidth: max(1.1, diameter * 0.025)))
                            .rotationEffect(.degrees(angle - 90))
                        Circle()
                            .trim(from: 0.52, to: 0.83)
                            .stroke(VeilTheme.paleMetal.opacity(engaged ? 0.71 : 0.19),
                                    style: StrokeStyle(lineWidth: max(0.8, diameter * 0.014)))
                            .padding(diameter * 0.055)
                            .rotationEffect(.degrees(-angle * 0.5 + 45))
                        Rectangle()
                            .fill(VeilTheme.gold.opacity(engaged ? 0.55 : 0.14))
                            .frame(width: diameter * 0.32, height: 1)
                            .rotationEffect(.degrees(angle * 0.5))
                    }
                    .frame(width: diameter * 0.69, height: diameter * 0.69)
                }

                VeilPanelShape(cut: diameter * 0.027, radius: 2)
                    .fill(VeilTheme.elevated)
                    .frame(width: diameter * 0.38, height: diameter * 0.28)
                    .overlay {
                        VeilPanelShape(cut: diameter * 0.027, radius: 2)
                            .stroke(VeilTheme.gold.opacity(engaged ? 0.64 : 0.20), lineWidth: 1)
                    }
                Text(kind.mark)
                    .font(.system(size: max(8, diameter * 0.125), weight: .black, design: .monospaced))
                    .foregroundColor(engaged ? VeilTheme.goldBright : VeilTheme.tertiaryText)

                Rectangle()
                    .fill(working ? VeilTheme.goldBright : (engaged ? VeilTheme.success : VeilTheme.tertiaryText))
                    .frame(width: diameter * 0.11, height: 2)
                    .offset(x: diameter * 0.33, y: diameter * 0.34)
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.label)：\(working ? "工作中" : (engaged ? "就绪" : "待机"))")
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

struct VeilForgeHealthGauge: View {
    let healthScore: Int

    private var count: Int { VeilForgeMotionCore.healthBars(healthScore) }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<VeilForgeMotionCore.healthBarCount, id: \.self) { index in
                Rectangle()
                    .fill(index < count ? VeilTheme.goldBright : VeilTheme.hairline)
                    .frame(width: 2.8, height: CGFloat(5 + (index % 4) * 2))
                    .scaleEffect(x: 1, y: index < count ? 1 : 0.42, anchor: .bottom)
                    // A bounded, short ratchet sequence on ACTUAL health change.
                    // No independent timer and no simulated link speed.
                    .animation(
                        VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion)?
                            .delay(Double(index) * 0.018),
                        value: count
                    )
            }
        }
        .frame(height: 12, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


/// Header blueprint follows ECLIPSE's recognizable visual grammar:
/// an explicit machine identity, readable state and bright active datum.
struct VeilForgeModuleHeader: View {
    let serial: String
    let title: String
    let state: String
    let active: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Rectangle()
                .fill(active ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(serial)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.75)
                    .foregroundColor(VeilTheme.mutedGold)
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(VeilTheme.text)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 5) {
                    Rectangle()
                        .fill(active ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                        .frame(width: 5, height: 5)
                    Text(state)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(active ? VeilTheme.goldBright : VeilTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text("LOCAL // LIVE STATE")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 3)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

/// A small, static instrument face for the actual theme chooser.
/// Unlike a decorative animated preview, it costs no idle frames.
struct VeilForgeThemePreview: View {
    var body: some View {
        ZStack {
            VeilPanelShape(cut: 8, radius: 1)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.14))
            VeilPanelShape(cut: 8, radius: 1)
                .stroke(Color(red: 0.55, green: 0.27, blue: 0.16), lineWidth: 0.8)

            Circle()
                .trim(from: 0.04, to: 0.72)
                .stroke(Color(red: 0.98, green: 0.38, blue: 0.11),
                        style: StrokeStyle(lineWidth: 2.3, lineCap: .butt))
                .frame(width: 27, height: 27)
                .rotationEffect(.degrees(-45))

            Text("F")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.92))

            Rectangle()
                .fill(Color(red: 1.0, green: 0.48, blue: 0.15))
                .frame(width: 10, height: 2)
                .offset(x: 11, y: 15)
        }
        .frame(width: 42, height: 42)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Selected-theme specification is informational, not fake telemetry.
/// It helps users tell a full theme from a superficial color filter.
struct VeilForgeThemeSpecification: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(VeilTheme.goldBright)
                    .frame(width: 4, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FORGE // SYSTEM 06")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.goldBright)
                    Text("工业控制台 · 动态来自真实状态")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(VeilTheme.text)
                }
            }

            HStack(spacing: 6) {
                chip("RF", "RADIO")
                chip("CPU", "RUNTIME")
                chip("BLE", "LINK")
            }

            Text("静态金属结构 · 橙色状态标识 · 滚动优先 · 后台停止驱动")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(VeilForgePlate(emphasized: true))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private func chip(_ a: String, _ b: String) -> some View {
        HStack(spacing: 4) {
            Text(a)
                .foregroundColor(VeilTheme.goldBright)
            Text(b)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .frame(height: 22)
        .background(VeilTheme.subtleFillStrong)
        .clipShape(VeilPanelShape(cut: 5, radius: 1))
    }
}


/// A CPU aperture is a different actuator family from the RF stepper rotor.
/// Opening shutters mean the actual local runtime is loading or generating;
/// the instrument makes no claim about synthetic CPU load percentages.
struct VeilForgeComputeShutter: View {
    let engaged: Bool
    let working: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = max(1, min(proxy.size.width, proxy.size.height))
            ZStack {
                VeilPanelShape(cut: size * 0.10, radius: 2)
                    .fill(VeilTheme.obsidian)
                VeilPanelShape(cut: size * 0.10, radius: 2)
                    .stroke(VeilTheme.gold.opacity(engaged ? 0.55 : 0.18), lineWidth: 1)

                // Stator rails remain fixed; the jaws slide sideways.
                ForEach([-1.0, 1.0], id: \.self) { direction in
                    Rectangle()
                        .fill(VeilTheme.paleMetal.opacity(0.22))
                        .frame(width: size * 0.68, height: 1)
                        .offset(y: direction * size * 0.31)
                }

                Rectangle()
                    .fill(working ? VeilTheme.goldBright : VeilTheme.hairline)
                    .frame(width: size * 0.075, height: size * 0.40)
                    .opacity(engaged ? 1 : 0.20)

                HStack(spacing: size * 0.06) {
                    shutterLeaf(size: size)
                        .offset(x: working ? -size * 0.16 : 0)
                    shutterLeaf(size: size)
                        .offset(x: working ? size * 0.16 : 0)
                }
                .frame(width: size * 0.65)

                Text("CPU")
                    .font(.system(size: max(8, size * 0.14), weight: .heavy, design: .monospaced))
                    .foregroundColor(engaged ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                    .padding(.horizontal, 2)
                    .background(VeilTheme.obsidian.opacity(0.92))
            }
            .animation(
                VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion),
                value: working
            )
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本地计算模块：\(working ? "运行中" : (engaged ? "就绪" : "未运行"))")
    }

    private func shutterLeaf(size: CGFloat) -> some View {
        VeilPanelShape(cut: size * 0.04, radius: 1)
            .fill(VeilTheme.panelSoft)
            .frame(width: size * 0.25, height: size * 0.50)
            .overlay {
                VeilPanelShape(cut: size * 0.04, radius: 1)
                    .stroke(VeilTheme.paleMetal.opacity(0.50), lineWidth: 0.7)
            }
    }
}

/// Reuse the existing physical odometer as a genuine observed-peer counter.
/// It advances only when discovery results change, never on a display timer.
struct VeilForgePeerCounter: View {
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            Text("DISCOVERED")
                .foregroundColor(VeilTheme.mutedGold)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
            VeilOdometerNumber(value: max(0, count))
                .fixedSize(horizontal: true, vertical: false)
            Text("PEERS")
                .foregroundColor(VeilTheme.secondaryText)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("已发现设备 \(max(0, count)) 台")
    }
}

/// Three-position sliding carriage maps the REAL LAN routing state.
/// Idle → TCP present → secure LAN peer available. This is not a transfer
/// progress bar and does not imply that the radio has a given throughput.
struct VeilForgeRouteRail: View {
    let connectedPeers: Int
    let securePeers: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stage: Int {
        VeilForgeMotionCore.routeStage(
            connectedPeers: connectedPeers,
            securePeers: securePeers
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = max(1, proxy.size.width / 3)
            ZStack(alignment: .leading) {
                VeilPanelShape(cut: 6, radius: 1)
                    .fill(VeilTheme.obsidian.opacity(0.76))

                Rectangle()
                    .fill(VeilTheme.gold.opacity(0.23))
                    .frame(width: cellWidth, height: 26)
                    .overlay {
                        Rectangle()
                            .stroke(VeilTheme.goldBright.opacity(0.70), lineWidth: 1)
                    }
                    .offset(x: CGFloat(stage) * cellWidth)

                HStack(spacing: 0) {
                    label("IDLE", number: 0)
                    label("TCP", number: 1)
                    label("SECURE", number: 2)
                }
            }
            .frame(height: 26)
            .clipped()
            .animation(
                VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion),
                value: stage
            )
        }
        .frame(height: 26)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage == 2 ? "已建立安全局域网连接" :
                            stage == 1 ? "已建立 TCP 连接" : "局域网数据链路待机")
    }

    private func label(_ value: String, number: Int) -> some View {
        Text(value)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.2)
            .foregroundColor(stage == number ? VeilTheme.goldBright : VeilTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
    }
}
