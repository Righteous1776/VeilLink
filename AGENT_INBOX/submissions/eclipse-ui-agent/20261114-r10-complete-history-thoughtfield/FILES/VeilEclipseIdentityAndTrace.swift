import Foundation
import SwiftUI
import Combine

/// Five-in-a-row's own bot identity. No Grok-specific video/GIF asset or
/// strings are borrowed; other game avatars keep their existing behavior.
struct VeilEclipseIdentityCard: View {
    let isThinking: Bool
    let matchFinished: Bool
    let lastCompletedMilliseconds: Int?
    /// Actual engine calculation timestamp, not a fabricated progress indicator.
    let actualSearchStartedAt: Date?
    /// The current controller's actual tier, not an independently configured UI tier.
    let difficultyTitle: String
    let openTrace: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var appearance = VeilAppearanceController.shared

    var body: some View {
        Button(action: openTrace) {
            HStack(spacing: VeilSpacing.md) {
                VeilEclipseAvatar(isThinking: isThinking && !reduceMotion)
                    .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: VeilSpacing.xxs) {
                    Text("ECLIPSE")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(VeilTheme.text)
                    Text(isThinking ? "正在思考" : matchFinished ? "本局结束 · 可查看回放" : "等待落子")
                        .font(.caption)
                        .foregroundColor(isThinking ? VeilTheme.goldBright : VeilTheme.secondaryText)
                    Text("VeilLink Native Intelligence")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: VeilSpacing.sm) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                    Text(VeilEclipseTierPresentation.shortName(difficultyTitle))
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                    if isThinking, let started = actualSearchStartedAt {
                        TimelineView(.periodic(from: .now, by: 0.1)) { clock in
                            Text(String(format: "%.1fs", max(0, clock.date.timeIntervalSince(started))))
                                .font(.caption2.monospacedDigit())
                        }
                    } else if let ms = lastCompletedMilliseconds, ms >= 0 {
                        Text("\(ms)ms")
                            .font(.caption2.monospacedDigit())
                            .lineLimit(1)
                    }
                }
                .foregroundColor(VeilTheme.tertiaryText)
            }
            // Outer .veilCard() is authoritative: the *existing* VeilCardModifier
            // owns cut corners, instrument plates, Apple Soft and Islet materials.
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ECLIPSE，\(VeilEclipseTierPresentation.shortName(difficultyTitle))，\(isThinking ? "正在计算" : matchFinished ? "本局已结束" : "等待对局")，查看分析状态")
        .accessibilityHint("对局期间不显示推荐落点；完成后可以回放已发生的棋步")
        .accessibilityIdentifier("game.eclipse.identity")
    }
}

/// The avatar borrows NO Grok media but inherits the current VeilLink palette.
/// It intentionally uses the same circular icon footprint as the existing
/// in-app bot card instead of adding an unrelated cyberpunk/blue-metal brand.
private struct VeilEclipseAvatar: View {
    let isThinking: Bool
    @ObservedObject private var appearance = VeilAppearanceController.shared

    var body: some View {
        ZStack {
            Circle()
                .fill(VeilTheme.obsidian)
            Circle()
                .strokeBorder(VeilTheme.hairline, lineWidth: 1)
            Circle()
                .trim(from: 0.05, to: 0.79)
                .stroke(VeilTheme.gold.opacity(appearance.isPlainline ? 0.42 : 0.68),
                        style: StrokeStyle(lineWidth: appearance.isPlainline ? 1 : 1.7,
                                           lineCap: .round))
                .padding(7)
                .rotationEffect(.degrees(-35))
            // Theme-aware mask/eyes: Veil Original gold, Instrument amber,
            // Apple Soft adaptive light/dark, Islet aurora, Plainline hairline.
            HStack(spacing: 12) {
                Capsule().fill(VeilTheme.text)
                Capsule().fill(VeilTheme.text)
            }
            .frame(width: 34, height: isThinking ? 6 : 10)
            .offset(y: -1)
            if appearance.isInstrument {
                VeilIndicatorLamp(active: isThinking, color: VeilTheme.gold)
                    .offset(x: 21, y: 24)
            }
        }
        .shadow(color: appearance.isPlainline ? .clear : VeilTheme.gold.opacity(0.07),
                radius: 6, y: 2)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Abstract eye-candy only: NOT a heatmap, PV tree or candidate-coordinate map.
/// Animation is deliberately independent of the board and search values.
private struct EclipseAbstractThoughtField: View {
    let isThinking: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0,
                                    paused: !isThinking || reduceMotion)) { timeline in
                let tick = isThinking ? timeline.date.timeIntervalSinceReferenceDate : 0
                Canvas(opaque: false) { ctx, size in
                    let points: [(CGFloat,CGFloat)] = [
                        (0.11,0.52), (0.29,0.22), (0.28,0.79), (0.48,0.51),
                        (0.68,0.23), (0.70,0.77), (0.90,0.40), (0.92,0.72)
                    ]
                    let edges = [(0,1), (0,2), (1,3), (2,3), (3,4), (3,5), (4,6), (5,7)]
                    for (a,b) in edges {
                        var line = Path()
                        line.move(to: CGPoint(x: points[a].0 * size.width, y: points[a].1 * size.height))
                        line.addLine(to: CGPoint(x: points[b].0 * size.width, y: points[b].1 * size.height))
                        ctx.stroke(line, with: .color(VeilTheme.secondaryText.opacity(0.33)), lineWidth: 1)
                    }
                    for (i,p) in points.enumerated() {
                        let wave = 0.54 + 0.46 * sin(tick * 2.4 + Double(i) * 0.76)
                        let alpha = isThinking && !reduceMotion ? wave : 0.53
                        let r: CGFloat = i == 3 ? 5 : 3
                        let circle = Path(ellipseIn: CGRect(x: p.0 * size.width-r,
                            y: p.1 * size.height-r, width: 2*r, height: 2*r))
                        ctx.fill(circle, with: .color(VeilTheme.gold.opacity(alpha)))
                    }
                }
            }
            .frame(height: 82)
            .accessibilityHidden(true)
            Text("抽象计算动画 · 不对应真实棋盘坐标或候选走法")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .veilCard()
    }
}

struct VeilEclipseTraceSheet: View {
    let isThinking: Bool
    let matchFinished: Bool
    let lastCompletedMilliseconds: Int?
    let committedMoves: [VeilEclipseTracePolicy.PlacedMove]
    let difficultyTitle: String
    let searchModeTitle: String
    /// Only accepts coordinate-free, pre-redacted metrics. R5 integration will
    /// sanitize engine traces BEFORE sending anything to this view.
    /// Main currently passes nil and never fabricates depth/node totals.
    let liveMetrics: VeilEclipseTracePolicy.LiveMetrics?
    /// Loads a bounded page; returns nil on storage failure. Never reads chess
    /// advice/analyses; only validated already committed game records.
    let archivedMatchPage: (Int, Int) -> VeilGomokuMatchArchive.Page?

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var appearance = VeilAppearanceController.shared
    @State private var replayPly = 0
    @State private var playing = false
    @State private var savedMatches: [VeilGomokuMatchArchive.Match] = []
    @State private var selectedMatchID: String?
    @State private var nextOffset: Int? = 0
    @State private var knownMatchCount = 0
    @State private var unreadableCount = 0

    private var replayFrames: [VeilEclipseTracePolicy.ReplayFrame] {
        let stored = savedMatches.first { $0.id == selectedMatchID }
        return VeilEclipseTracePolicy.replayFrames(
            stored?.placedMoves ?? committedMoves,
            matchFinished: matchFinished,
            separateReadOnlyPanel: true
        )
    }

    private func loadArchivePage() {
        guard matchFinished, let offset = nextOffset else { return }
        guard let page = archivedMatchPage(offset, 25) else { nextOffset = nil; return }
        let existingIDs = Set(savedMatches.map(\.id))
        savedMatches += page.matches.filter { !existingIDs.contains($0.id) }
        knownMatchCount = page.totalFiles
        unreadableCount += page.invalidFiles
        nextOffset = page.nextOffset
    }


    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label(matchFinished ? "赛后只读回放" : "对局中 · 无落点提示",
                              systemImage: matchFinished ? "lock.shield" : "eye.slash")
                            .foregroundColor(VeilTheme.goldBright)
                            .font(.caption.weight(.semibold))
                        Spacer()
                    }
                    EclipseAbstractThoughtField(isThinking: isThinking)
                    VStack(alignment: .leading, spacing: VeilSpacing.xxs) {
                        HStack(spacing: VeilSpacing.sm) {
                            Text("当前棋力档位")
                                .foregroundColor(VeilTheme.secondaryText)
                            Spacer(minLength: 4)
                            Text(VeilEclipseTierPresentation.shortName(difficultyTitle))
                                .foregroundColor(VeilTheme.text)
                            Text("· " + searchModeTitle)
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                        .font(.caption)
                        if VeilEclipseTierPresentation.hasSearchBudgetMultiplier(difficultyTitle) {
                            Text(VeilEclipseTierPresentation.multiplierDisclosure)
                                .font(.caption2)
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                    }
                    .veilCard()
                    VStack(alignment: .leading, spacing: VeilSpacing.sm) {
                        HStack(spacing: VeilSpacing.sm) {
                            metric("完成深度", liveMetrics?.completedDepth.map { "D\($0)" } ?? "—")
                            metric("搜索节点", liveMetrics?.visitedNodes.map(String.init) ?? "—")
                            metric("上步耗时", lastCompletedMilliseconds.map { "\($0)ms" } ?? "—")
                        }
                        Text(liveMetrics == nil
                             ? "当前版本尚无实时深度/节点流；数值不会伪造。"
                             : "真实引擎指标 · 抽象图不代表搜索路径")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    .veilCard()
                    if matchFinished {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text("历次对局 · \(knownMatchCount) 份")
                                    .font(.headline)
                                    .foregroundColor(VeilTheme.text)
                                Spacer()
                                if selectedMatchID != nil {
                                    Button("返回本局") {
                                        selectedMatchID = nil
                                        replayPly = max(0, replayFrames.count - 1)
                                        playing = false
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(VeilTheme.goldBright)
                                }
                            }
                            ForEach(savedMatches) { saved in
                                Button {
                                    guard saved.isReplayable else { return }
                                    selectedMatchID = saved.id
                                    playing = false
                                    replayPly = saved.moves.count
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(VeilTheme.gold)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(saved.status.title + " · \(saved.moves.count) 手")
                                                .font(.caption.weight(.semibold))
                                            Text(saved.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(VeilTheme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: selectedMatchID == saved.id ? "checkmark.circle.fill" : "chevron.right")
                                            .foregroundColor(VeilTheme.goldBright)
                                    }
                                    .foregroundColor(VeilTheme.text)
                                    .padding(8)
                                    .background(VeilTheme.subtleFill, in: RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                                .disabled(!saved.isReplayable)
                            }
                            if nextOffset != nil {
                                Button("加载更多历史对局") { loadArchivePage() }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(VeilTheme.goldBright)
                            }
                            if unreadableCount > 0 {
                                Text("另有 \(unreadableCount) 份棋谱校验失败，原始文件已保留。")
                                    .font(.caption2)
                                    .foregroundColor(VeilTheme.danger)
                            }
                        }
                        .veilCard()
                    }
                    if matchFinished && replayFrames.count > 1 {
                        Divider()
                        Text("完整棋局 · 已发生落子")
                            .font(.headline)
                        Text("以下是存档中真实发生的棋步，不显示未落下的候选点、预测走法或风险提示。")
                            .font(.caption)
                            .foregroundColor(VeilTheme.secondaryText)
                        EclipseCommittedBoard(frame: replayFrames[min(replayPly, replayFrames.count-1)])
                            .aspectRatio(1, contentMode: .fit)
                            .veilCard()
                            .accessibilityLabel("已完成棋局，第 \(replayPly) 手，独立只读棋盘")
                        HStack {
                            Text("第 \(replayPly) / \(replayFrames.count - 1) 手")
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            Button(playing ? "暂停" : "逐步播放") { playing.toggle() }
                                .buttonStyle(.bordered)
                        }
                        Slider(value: Binding(
                            get: { Double(replayPly) },
                            set: { replayPly = Int($0); playing = false }
                        ), in: 0...Double(replayFrames.count - 1), step: 1)
                        HStack {
                            Button("上一步") { playing = false; replayPly = max(0, replayPly-1) }
                                .disabled(replayPly == 0)
                            Spacer()
                            Button("下一步") {
                                playing = false
                                replayPly = min(replayFrames.count-1, replayPly+1)
                            }
                                .disabled(replayPly == replayFrames.count-1)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text(matchFinished ? "本局的已验证走子记录暂不可用。"
                             : "为保证公平，对局进行时不会显示棋盘推演、推荐点、对方威胁位置或主变路线。赛后才能查看实际棋步。")
                            .font(.subheadline)
                            .foregroundColor(VeilTheme.secondaryText)
                            .padding(.vertical, 12)
                    }
                }
                .frame(maxWidth: 520)
                .padding(18)
            }
            .background(VeilAmbientBackground())
            .navigationTitle("ECLIPSE // TRACE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .onAppear {
            replayPly = replayFrames.count > 1 ? replayFrames.count - 1 : 0
            playing = false
            if matchFinished && savedMatches.isEmpty { loadArchivePage() }
        }
        .onDisappear { playing = false }
        .onReceive(Timer.publish(every: 0.85, on: .main, in: .common).autoconnect()) { _ in
            guard playing, matchFinished, replayFrames.count > 1 else { return }
            if replayPly >= replayFrames.count - 1 { playing = false }
            else { replayPly += 1 }
        }
        .accessibilityIdentifier("game.eclipse.trace")
    }

    private func metric(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(.caption2).foregroundColor(VeilTheme.secondaryText)
            Text(value).font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(VeilTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VeilSpacing.sm)
        .background(VeilTheme.subtleFill, in: VeilPanelShape(cut: 12, radius: 7))
    }
}

/// A separate read-only board. Never overlays the interactive GomokuBoardView.
private struct EclipseCommittedBoard: View {
    let frame: VeilEclipseTracePolicy.ReplayFrame

    var body: some View {
        Canvas(opaque: false) { ctx, size in
            let side = min(size.width, size.height)
            let margin = side * 0.055
            let spacing = (side - margin * 2) / 14
            let background = CGRect(x: 0, y: 0, width: side, height: side)
            // Same established board surface used by GomokuBoardView in
            // VeilLink/UI/MiniGameViews.swift (not an invented light wood skin).
            ctx.fill(Path(roundedRect: background, cornerRadius: 9),
                     with: .color(Color(red: 0.42, green: 0.29, blue: 0.15).opacity(0.46)))
            for step in 0..<15 {
                let x = margin + CGFloat(step) * spacing
                var vertical = Path()
                vertical.move(to: CGPoint(x: x, y: margin))
                vertical.addLine(to: CGPoint(x: x, y: side-margin))
                ctx.stroke(vertical, with: .color(Color.white.opacity(0.27)), lineWidth: 0.65)
                var horizontal = Path()
                horizontal.move(to: CGPoint(x: margin, y: x))
                horizontal.addLine(to: CGPoint(x: side-margin, y: x))
                ctx.stroke(horizontal, with: .color(Color.white.opacity(0.27)), lineWidth: 0.65)
            }
            for star in [48, 56, 112, 168, 176] {
                let x = margin + CGFloat(star % 15) * spacing
                let y = margin + CGFloat(star / 15) * spacing
                ctx.fill(Path(ellipseIn: CGRect(x: x-2.1, y: y-2.1,
                                              width: 4.2, height: 4.2)),
                         with: .color(Color.white.opacity(0.42)))
            }
            for (i, stone) in frame.cells.enumerated() where stone != 0 {
                let x = margin + CGFloat(i % 15) * spacing
                let y = margin + CGFloat(i / 15) * spacing
                let diameter = spacing * 0.82
                let circle = Path(ellipseIn: CGRect(x: x-diameter/2, y: y-diameter/2,
                                                   width: diameter, height: diameter))
                ctx.fill(circle, with: .color(stone == 1
                    ? Color.black.opacity(0.96) : Color.white.opacity(0.96)))
                if frame.lastCommittedIndex == i {
                    let ring = Path(ellipseIn: CGRect(x: x-diameter*0.37, y: y-diameter*0.37,
                                                     width: diameter*0.74, height: diameter*0.74))
                    ctx.stroke(ring, with: .color(VeilTheme.gold), lineWidth: 1.7)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
