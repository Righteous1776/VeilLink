import SwiftUI
import Foundation

/// Warm soft graphite with a single, low-energy orange light wash.
/// No hard engineering grid, ambient particles, timers, gestures or overlays.
struct VeilForgeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [VeilTheme.backgroundLift, VeilTheme.background, VeilTheme.obsidian],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [VeilTheme.gold.opacity(0.085), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 380
            )
            LinearGradient(
                colors: [Color.white.opacity(0.025), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Shared FORGE R2 soft-card measurements: borrowed from the robot module's
/// charcoal rounded enclosure, never a chamfered steel sheet.
enum VeilForgeSoftDesign {
    static let cardCornerRadius: CGFloat = 20
    static let emphasizedCornerRadius: CGFloat = 24
    static let previewCornerRadius: CGFloat = 13
}

struct VeilForgePlate: View {
    let emphasized: Bool

    var body: some View {
        let radius = emphasized
            ? VeilForgeSoftDesign.emphasizedCornerRadius
            : VeilForgeSoftDesign.cardCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(
                LinearGradient(
                    colors: [
                        VeilAppearanceController.shared.palette.metalTop,
                        VeilTheme.panel,
                        VeilAppearanceController.shared.palette.metalBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(shape.stroke(VeilTheme.hairline, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [VeilTheme.goldBright.opacity(emphasized ? 0.83 : 0.42), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: emphasized ? 55 : 30, height: 2)
                    .padding(.top, 3)
                    .padding(.leading, 21)
            }
            .shadow(
                color: Color.black.opacity(
                    VeilAppearanceController.shared.isDarkAppearance ? 0.25 : 0.10
                ),
                radius: emphasized ? 14 : 9,
                x: 0,
                y: emphasized ? 7 : 4
            )
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
            Capsule()
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
                Circle()
                    .fill(VeilTheme.obsidian)
                Circle()
                    .stroke(VeilTheme.gold.opacity(engaged ? 0.44 : 0.15), lineWidth: 1)

                ForEach(0..<24, id: \.self) { index in
                    Capsule()
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

                RoundedRectangle(cornerRadius: diameter * 0.07, style: .continuous)
                    .fill(VeilTheme.elevated)
                    .frame(width: diameter * 0.38, height: diameter * 0.28)
                    .overlay {
                        RoundedRectangle(cornerRadius: diameter * 0.07, style: .continuous)
                            .stroke(VeilTheme.gold.opacity(engaged ? 0.64 : 0.20), lineWidth: 1)
                    }
                Text(kind.mark)
                    .font(.system(size: max(8, diameter * 0.125), weight: .black, design: .monospaced))
                    .foregroundColor(engaged ? VeilTheme.goldBright : VeilTheme.tertiaryText)

                Circle()
                    .fill(working ? VeilTheme.goldBright : (engaged ? VeilTheme.success : VeilTheme.tertiaryText))
                    .frame(width: diameter * 0.075, height: diameter * 0.075)
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
                Capsule()
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
            Capsule()
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
                    Circle()
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

/// Static, rounded robot-like accent: a preview rather than fake telemetry.
struct VeilForgeThemePreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: VeilForgeSoftDesign.previewCornerRadius,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.22, green: 0.21, blue: 0.23),
                             Color(red: 0.10, green: 0.095, blue: 0.11)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: VeilForgeSoftDesign.previewCornerRadius,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
            }

            Circle()
                .stroke(Color(red: 0.69, green: 0.24, blue: 0.04).opacity(0.65),
                        lineWidth: 1.5)
                .frame(width: 31, height: 31)
            Circle()
                .trim(from: 0.04, to: 0.71)
                .stroke(Color(red: 1.00, green: 0.486, blue: 0.137),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 31, height: 31)
                .rotationEffect(.degrees(-90))

            Text("F")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.95))
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
                    Text("柔和仪器 · 动态只来自真实状态")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(VeilTheme.text)
                }
            }

            HStack(spacing: 6) {
                chip("RF", "RADIO")
                chip("CPU", "RUNTIME")
                chip("BLE", "LINK")
            }

            Text("暖灰黑底 · 明亮橙色 · 圆润仪表 · 手势优先")
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
        .clipShape(Capsule())
    }
}


/// CPU uses the same restrained circular instrument grammar as the
/// ECLIPSE robot and RF dial. No fake gauges or ornamental shutters.
struct VeilForgeComputeShutter: View {
    let engaged: Bool
    let working: Bool

    var body: some View {
        VeilForgeRotor(kind: .compute, engaged: engaged, working: working)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "本地计算模块：\(working ? "运行中" : (engaged ? "就绪" : "未运行"))"
            )
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
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(VeilTheme.obsidian.opacity(0.76))

                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(VeilTheme.gold.opacity(0.23))
                    .frame(width: cellWidth, height: 26)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
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
