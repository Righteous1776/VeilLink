import SwiftUI

struct ArcadeVisualGameDescriptor: Identifiable {
    let id: String
    let title: String
    let tagline: String
    let motif: ArcadeVisualMotif
    var difficulty: ArcadeVisualDifficulty = .normal
    var playerLabel: String = "单人"
    var progress: Double = 0
    var isLocked = false
    var isLive = true
}

enum ArcadeVisualDifficulty: Int, CaseIterable {
    case relaxed = 1
    case normal = 2
    case intense = 3

    var label: String {
        switch self {
        case .relaxed: return "轻松"
        case .normal: return "标准"
        case .intense: return "高能"
        }
    }
}
/// Reusable launch card for the realtime game shelf. The artwork and live
/// activity strip are both code-drawn and scale down to a 320-point viewport.
struct ArcadeVisualGameCard: View {
    let game: ArcadeVisualGameDescriptor
    var actionTitle = "开始"
    let onLaunch: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = width < ArcadeVisualMetrics.compactBreakpoint
            let palette = ArcadeVisualPalette.palette(for: game.motif)

            Button(action: onLaunch) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: ArcadeVisualMetrics.cardCornerRadius(width: width), style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.shadow.opacity(0.96), Color(red: 0.035, green: 0.045, blue: 0.085)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .fill(palette.atmosphereGradient)
                        .frame(width: compact ? 150 : 190, height: compact ? 150 : 190)
                        .offset(x: width * 0.34, y: -22)
                        .allowsHitTesting(false)

                    HStack(spacing: compact ? 11 : 15) {
                        ArcadeVisualIcon(
                            motif: game.motif,
                            animated: game.isLive,
                            accessibilityLabel: "\(game.title)图标"
                        )
                        .frame(width: compact ? 72 : 88, height: compact ? 72 : 88)

                        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
                            HStack(spacing: 6) {
                                Text(game.title)
                                    .font(.system(compact ? .headline : .title3, design: .rounded).weight(.heavy))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.76)

                                if game.isLive {
                                    ArcadeVisualLivePip(color: palette.highlight)
                                }
                            }

                            Text(game.tagline)
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.70))
                                .lineLimit(compact ? 1 : 2)

                            HStack(spacing: 7) {
                                ArcadeVisualCapsule(text: game.playerLabel, color: palette.primary)
                                ArcadeVisualCapsule(text: game.difficulty.label, color: palette.secondary)
                            }

                            HStack(spacing: 8) {
                                ArcadeVisualProgressBar(progress: game.progress, color: palette.highlight)
                                Text(game.isLocked ? "未解锁" : actionTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(game.isLocked ? Color.white.opacity(0.45) : palette.highlight)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, ArcadeVisualMetrics.horizontalPadding(width: width))
                    .padding(.bottom, 14)

                    ArcadeVisualActivityStrip(
                        palette: palette,
                        active: game.isLive && !game.isLocked,
                        reduceMotion: reduceMotion
                    )
                    .frame(height: 3)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: ArcadeVisualMetrics.cardCornerRadius(width: width), style: .continuous)
                        .stroke(palette.primary.opacity(game.isLocked ? 0.20 : 0.52), lineWidth: 1)
                )
                .opacity(game.isLocked ? 0.62 : 1)
                .contentShape(RoundedRectangle(cornerRadius: ArcadeVisualMetrics.cardCornerRadius(width: width), style: .continuous))
            }
            .buttonStyle(ArcadeVisualCardButtonStyle())
            .disabled(game.isLocked)
        }
        .frame(minHeight: 146, idealHeight: 168, maxHeight: 168)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.title)，\(game.tagline)")
        .accessibilityValue(game.isLocked ? "尚未解锁" : "进度百分之\(Int(max(0, min(1, game.progress)) * 100))")
        .accessibilityHint(game.isLocked ? "完成前置关卡后解锁" : "轻点\(actionTitle)")
    }
}

private struct ArcadeVisualCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !VeilMotionPolicy.usesReducedMotion(reduceMotion) ? 0.975 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion), value: configuration.isPressed)
    }
}

private struct ArcadeVisualCapsule: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(Color.white.opacity(0.86))
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .background(color.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.42), lineWidth: 0.75))
    }
}

private struct ArcadeVisualProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, progress))))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

private struct ArcadeVisualLivePip: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18)).frame(width: expanded ? 18 : 10, height: expanded ? 18 : 10)
            Circle().fill(color).frame(width: 6, height: 6)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            guard !VeilMotionPolicy.usesReducedMotion(reduceMotion),
                  VeilMotionPolicy.allowsContinuousDecorativeMotion else { return }
            withAnimation(.easeOut(duration: 0.85).repeatForever(autoreverses: false)) { expanded = true }
        }
        .accessibilityLabel("实时渲染")
    }
}

private struct ArcadeVisualActivityStrip: View {
    let palette: ArcadeVisualPalette
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        if active && !VeilMotionPolicy.usesReducedMotion(reduceMotion) && VeilMotionPolicy.allowsContinuousDecorativeMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                strip(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            strip(at: 0)
        }
    }

    private func strip(at time: TimeInterval) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let travel = active ? CGFloat(time.truncatingRemainder(dividingBy: 1.4) / 1.4) : 0.5
            ZStack(alignment: .leading) {
                Rectangle().fill(palette.primary.opacity(0.15))
                Capsule()
                    .fill(palette.heroGradient)
                    .frame(width: max(32, width * 0.28))
                    .offset(x: max(0, width - max(32, width * 0.28)) * travel)
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

enum ArcadeVisualLevelState {
    case locked
    case available
    case completed(stars: Int)
    case current

    var isEnabled: Bool {
        if case .locked = self { return false }
        return true
    }
}

struct ArcadeVisualLevel: Identifiable {
    let id: Int
    let title: String
    let state: ArcadeVisualLevelState
}

/// Horizontal world-path selector sized for one-handed use on compact phones.
struct ArcadeVisualLevelMap: View {
    let levels: [ArcadeVisualLevel]
    let motif: ArcadeVisualMotif
    let onSelect: (ArcadeVisualLevel) -> Void

    var body: some View {
        let palette = ArcadeVisualPalette.palette(for: motif)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    if index > 0 {
                        Capsule()
                            .fill(connectionColor(for: level, palette: palette))
                            .frame(width: 34, height: 4)
                            .accessibilityHidden(true)
                    }
                    ArcadeVisualLevelButton(level: level, palette: palette) {
                        onSelect(level)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("关卡选择")
    }

    private func connectionColor(for level: ArcadeVisualLevel, palette: ArcadeVisualPalette) -> Color {
        switch level.state {
        case .locked: return Color.white.opacity(0.10)
        default: return palette.primary.opacity(0.55)
        }
    }
}

private struct ArcadeVisualLevelButton: View {
    let level: ArcadeVisualLevel
    let palette: ArcadeVisualPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(fillColor)
                        .frame(width: 52, height: 52)
                    Circle()
                        .stroke(strokeColor, lineWidth: isCurrent ? 3 : 1)
                        .frame(width: 52, height: 52)
                    stateMark
                }
                Text(level.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(labelColor)
                    .lineLimit(1)
            }
            .frame(width: 66)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!level.state.isEnabled)
        .accessibilityLabel("第\(level.id)关，\(level.title)")
        .accessibilityValue(stateLabel)
    }

    private var isCurrent: Bool {
        if case .current = level.state { return true }
        return false
    }

    private var fillColor: Color {
        switch level.state {
        case .locked: return Color.white.opacity(0.06)
        case .available: return palette.primary.opacity(0.18)
        case .completed: return palette.secondary.opacity(0.30)
        case .current: return palette.primary.opacity(0.46)
        }
    }

    private var strokeColor: Color {
        switch level.state {
        case .locked: return Color.white.opacity(0.12)
        case .available: return palette.primary.opacity(0.70)
        case .completed: return palette.highlight.opacity(0.76)
        case .current: return palette.highlight
        }
    }

    private var labelColor: Color {
        level.state.isEnabled ? Color.white.opacity(0.86) : Color.white.opacity(0.34)
    }

    @ViewBuilder
    private var stateMark: some View {
        switch level.state {
        case .locked:
            Text("—").font(.headline.weight(.black)).foregroundColor(Color.white.opacity(0.30))
        case .available:
            Text("\(level.id)").font(.headline.monospacedDigit().weight(.black)).foregroundColor(palette.highlight)
        case .current:
            Text("▶").font(.headline.weight(.black)).foregroundColor(palette.highlight)
        case .completed(let stars):
            Text(String(repeating: "★", count: max(1, min(3, stars))))
                .font(.system(size: 9, weight: .black))
                .foregroundColor(palette.highlight)
                .minimumScaleFactor(0.7)
        }
    }

    private var stateLabel: String {
        switch level.state {
        case .locked: return "已锁定"
        case .available: return "可挑战"
        case .current: return "当前关卡"
        case .completed(let stars): return "已完成，\(stars)星"
        }
    }
}

struct ArcadeVisualBadge: View {
    let title: String
    let subtitle: String
    let motif: ArcadeVisualMotif
    var earned = true

    var body: some View {
        let palette = ArcadeVisualPalette.palette(for: motif)
        HStack(spacing: 10) {
            ZStack {
                hexagon
                    .fill(earned ? palette.heroGradient : LinearGradient(colors: [Color.gray.opacity(0.30), Color.gray.opacity(0.18)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 52)
                ArcadeVisualIcon(motif: motif, animated: false)
                    .frame(width: 31, height: 31)
                    .saturation(earned ? 1 : 0)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold)).foregroundColor(.white)
                Text(subtitle).font(.caption2).foregroundColor(Color.white.opacity(0.60)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.primary.opacity(earned ? 0.34 : 0.12), lineWidth: 1))
        .opacity(earned ? 1 : 0.62)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("徽章，\(title)")
        .accessibilityValue(earned ? "已获得，\(subtitle)" : "尚未获得，\(subtitle)")
    }

    private var hexagon: Path {
        var path = Path()
        path.move(to: CGPoint(x: 24, y: 0))
        path.addLine(to: CGPoint(x: 48, y: 13))
        path.addLine(to: CGPoint(x: 48, y: 39))
        path.addLine(to: CGPoint(x: 24, y: 52))
        path.addLine(to: CGPoint(x: 0, y: 39))
        path.addLine(to: CGPoint(x: 0, y: 13))
        path.closeSubpath()
        return path
    }
}

struct ArcadeVisualReward: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let motif: ArcadeVisualMotif
    var amountText: String? = nil
    var tierText: String = "新奖励"
}

/// Full-screen gift reveal designed to be attached with
/// `arcadeRewardOverlay(reward:isPresented:onCollect:)`.
struct ArcadeRewardOverlay: View {
    let reward: ArcadeVisualReward
    @Binding var isPresented: Bool
    var onCollect: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    private var motionReduced: Bool { VeilMotionPolicy.usesReducedMotion(reduceMotion) }
    private var palette: ArcadeVisualPalette { ArcadeVisualPalette.palette(for: reward.motif) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            ArcadeVisualParticleField(
                motif: reward.motif,
                seed: reward.id.hashValue,
                intensity: 32,
                active: phase >= 1
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(reward.tierText.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(2.4)
                    .foregroundColor(palette.highlight)
                    .opacity(phase >= 2 ? 1 : 0)

                giftStage
                    .frame(width: 230, height: 225)

                VStack(spacing: 7) {
                    Text(reward.title)
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(reward.detail)
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let amountText = reward.amountText {
                        Text(amountText)
                            .font(.headline.monospacedDigit().weight(.heavy))
                            .foregroundColor(palette.highlight)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 34)
                            .background(palette.primary.opacity(0.16), in: Capsule())
                    }
                }
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 12)

                Button {
                    onCollect()
                    isPresented = false
                } label: {
                    Text("收下奖励")
                        .font(.headline.weight(.bold))
                        .foregroundColor(palette.shadow)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(palette.heroGradient, in: Capsule())
                }
                .buttonStyle(ArcadeVisualCardButtonStyle())
                .disabled(phase < 3)
                .opacity(phase >= 3 ? 1 : 0.001)
                .frame(maxWidth: 300)
                .accessibilityHint("关闭奖励画面并返回游戏")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task(id: isPresented) {
            guard isPresented else { return }
            await runReveal()
        }
        .onDisappear { phase = 0 }
    }

    private var giftStage: some View {
        ZStack {
            Circle()
                .fill(palette.atmosphereGradient)
                .frame(width: phase >= 2 ? 224 : 150, height: phase >= 2 ? 224 : 150)

            ArcadeVisualIcon(motif: reward.motif, animated: phase >= 2)
                .frame(width: 112, height: 112)
                .scaleEffect(phase >= 2 ? 1 : 0.2)
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? -49 : 25)

            giftBox
                .offset(y: 52)
        }
        .animation(VeilMotionPolicy.animation(.reveal, reduceMotionRequested: reduceMotion), value: phase)
        .accessibilityHidden(true)
    }

    private var giftBox: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [palette.primary, palette.shadow], startPoint: .top, endPoint: .bottom))
                .frame(width: 136, height: 88)
                .overlay(Rectangle().fill(palette.highlight.opacity(0.88)).frame(width: 22))

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.heroGradient)
                .frame(width: 152, height: 31)
                .overlay(Rectangle().fill(palette.highlight.opacity(0.90)).frame(width: 24))
                .offset(y: -11)
                .offset(x: phase >= 1 ? 23 : 0, y: phase >= 1 ? -43 : -11)
                .rotationEffect(.degrees(phase >= 1 ? 11 : 0))

            HStack(spacing: -3) {
                giftLoop(rotation: -34)
                giftLoop(rotation: 34)
            }
            .offset(y: phase >= 1 ? -82 : -35)
            .offset(x: phase >= 1 ? 24 : 0)
            .rotationEffect(.degrees(phase >= 1 ? 11 : 0))
        }
    }

    private func giftLoop(rotation: Double) -> some View {
        Capsule()
            .stroke(palette.highlight, lineWidth: 8)
            .frame(width: 35, height: 22)
            .rotationEffect(.degrees(rotation))
    }

    @MainActor
    private func runReveal() async {
        phase = 0
        if motionReduced {
            phase = 3
            return
        }

        do { try await Task.sleep(nanoseconds: 180_000_000) } catch { return }
        withAnimation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion)) { phase = 1 }
        do { try await Task.sleep(nanoseconds: 280_000_000) } catch { return }
        withAnimation(VeilMotionPolicy.animation(.reveal, reduceMotionRequested: reduceMotion)) { phase = 2 }
        do { try await Task.sleep(nanoseconds: 260_000_000) } catch { return }
        withAnimation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion)) { phase = 3 }
    }
}

struct ArcadeVisualParticleField: View {
    let motif: ArcadeVisualMotif
    var seed: Int = 1
    var intensity: Int = 24
    var active = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if active && !VeilMotionPolicy.usesReducedMotion(reduceMotion) && VeilMotionPolicy.allowsContinuousDecorativeMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                particles(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            particles(at: 0)
                .opacity(active ? 0.42 : 0)
        }
    }

    private func particles(at time: TimeInterval) -> some View {
        Canvas { context, size in
            let palette = ArcadeVisualPalette.palette(for: motif)
            let colors = [palette.highlight, palette.primary, palette.secondary, Color.white]
            let count = max(4, min(64, intensity))

            for index in 0..<count {
                let xSeed = ArcadeVisualSeed.unit(seed, index * 4)
                let ySeed = ArcadeVisualSeed.unit(seed, index * 4 + 1)
                let speed = 0.08 + ArcadeVisualSeed.unit(seed, index * 4 + 2) * 0.13
                let cycle = (time * speed + ySeed).truncatingRemainder(dividingBy: 1)
                let rise = active ? cycle : ySeed
                let sway = sin(time * (0.7 + speed) + Double(index)) * 0.045
                let x = size.width * CGFloat(max(0.02, min(0.98, xSeed + sway)))
                let y = size.height * CGFloat(1.04 - rise * 1.10)
                let radius = CGFloat(1.5 + ArcadeVisualSeed.unit(seed, index * 4 + 3) * 3.6)
                let alpha = 0.26 + (sin(cycle * .pi) * 0.66)
                let color = colors[index % colors.count].opacity(alpha)

                if index.isMultiple(of: 3) {
                    var diamond = Path()
                    diamond.move(to: CGPoint(x: x, y: y - radius * 1.5))
                    diamond.addLine(to: CGPoint(x: x + radius, y: y))
                    diamond.addLine(to: CGPoint(x: x, y: y + radius * 1.5))
                    diamond.addLine(to: CGPoint(x: x - radius, y: y))
                    diamond.closeSubpath()
                    context.fill(diamond, with: .color(color))
                } else {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color)
                    )
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct ArcadeRewardOverlayModifier: ViewModifier {
    let reward: ArcadeVisualReward
    @Binding var isPresented: Bool
    let onCollect: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                ArcadeRewardOverlay(reward: reward, isPresented: $isPresented, onCollect: onCollect)
                    .zIndex(100)
                    .transition(.opacity)
            }
        }
    }
}

extension View {
    func arcadeRewardOverlay(
        reward: ArcadeVisualReward,
        isPresented: Binding<Bool>,
        onCollect: @escaping () -> Void = {}
    ) -> some View {
        modifier(ArcadeRewardOverlayModifier(reward: reward, isPresented: isPresented, onCollect: onCollect))
    }
}

/// Zero-configuration preview target for local integration and visual QA.
struct VeilArcadeRewardDemoView: View {
    @State private var showsReward = true

    private let reward = ArcadeVisualReward(
        id: "demo-starlight-badge",
        title: "星光领航员",
        detail: "连续完成三个实时关卡，新的彗星尾焰已经解锁。",
        motif: .comet,
        amountText: "+ 480 光点",
        tierText: "稀有礼物"
    )

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.032, blue: 0.070).ignoresSafeArea()
            Button("再次打开奖励") { showsReward = true }
                .buttonStyle(.borderedProminent)
                .tint(ArcadeVisualPalette.palette(for: .comet).primary)
        }
        .arcadeRewardOverlay(reward: reward, isPresented: $showsReward)
    }
}
