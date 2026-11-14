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
            VStack(alignment: .leading, spacing: VeilSpacing.sm) {
                HStack(spacing: VeilSpacing.md) {
                VeilEclipseAvatar(isThinking: isThinking && !reduceMotion)
                    .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: VeilSpacing.xxs) {
                    Text("ECLIPSE")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(VeilEclipseChrome.white)
                    Text(isThinking ? "正在思考" : matchFinished ? "本局结束 · 可查看回放" : "等待落子")
                        .font(.caption)
                        .foregroundColor(isThinking ? VeilEclipseChrome.accent : VeilEclipseChrome.silver)
                    Text("VeilLink / LOCAL REASONING SYSTEM")
                        .font(.caption2)
                        .foregroundColor(VeilEclipseChrome.muted)
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
                .foregroundColor(VeilEclipseChrome.muted)
                }
                // The black instrument is contained within existing VeilLink
                // materials. It never receives candidates, PV or threat cells.
                VeilEclipseComputeConsole(
                    isComputing: isThinking,
                    actualSearchStartedAt: actualSearchStartedAt,
                    liveMetrics: nil,
                    compact: true
                )
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
                .strokeBorder(VeilEclipseChrome.line, lineWidth: 1)
            Circle()
                .trim(from: 0.05, to: 0.79)
                .stroke(VeilEclipseChrome.accent.opacity(appearance.isPlainline ? 0.42 : 0.68),
                        style: StrokeStyle(lineWidth: appearance.isPlainline ? 1 : 1.7,
                                           lineCap: .round))
                .padding(7)
                .rotationEffect(.degrees(-35))
            // Theme-aware mask/eyes: Veil Original gold, Instrument amber,
            // Apple Soft adaptive light/dark, Islet aurora, Plainline hairline.
            HStack(spacing: 12) {
                Capsule().fill(VeilEclipseChrome.white)
                Capsule().fill(VeilEclipseChrome.white)
            }
            .frame(width: 34, height: isThinking ? 6 : 10)
            .offset(y: -1)
            if appearance.isInstrument {
                VeilIndicatorLamp(active: isThinking, color: VeilEclipseChrome.accent)
                    .offset(x: 21, y: 24)
            }
        }
        .shadow(color: appearance.isPlainline ? .clear : VeilEclipseChrome.accent.opacity(0.07),
                radius: 6, y: 2)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}


struct VeilEclipseTraceSheet: View {
    let isThinking: Bool
    let matchFinished: Bool
    let lastCompletedMilliseconds: Int?
    let actualSearchStartedAt: Date?
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
                            .foregroundColor(VeilEclipseChrome.accent)
                            .font(.caption.weight(.semibold))
                        Spacer()
                    }
                    VeilEclipseComputeConsole(
                        isComputing: isThinking,
                        actualSearchStartedAt: actualSearchStartedAt,
                        liveMetrics: liveMetrics,
                        compact: false
                    )
                    VStack(alignment: .leading, spacing: VeilSpacing.xxs) {
                        HStack(spacing: VeilSpacing.sm) {
                            Text("当前棋力档位")
                                .foregroundColor(VeilEclipseChrome.silver)
                            Spacer(minLength: 4)
                            Text(VeilEclipseTierPresentation.shortName(difficultyTitle))
                                .foregroundColor(VeilEclipseChrome.white)
                            Text("· " + searchModeTitle)
                                .foregroundColor(VeilEclipseChrome.silver)
                        }
                        .font(.caption)
                        if VeilEclipseTierPresentation.hasSearchBudgetMultiplier(difficultyTitle) {
                            Text(VeilEclipseTierPresentation.multiplierDisclosure)
                                .font(.caption2)
                                .foregroundColor(VeilEclipseChrome.silver)
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
                            .foregroundColor(VeilEclipseChrome.silver)
                    }
                    .veilCard()
                    if matchFinished {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text("历次对局 · \(knownMatchCount) 份")
                                    .font(.headline)
                                    .foregroundColor(VeilEclipseChrome.white)
                                Spacer()
                                if selectedMatchID != nil {
                                    Button("返回本局") {
                                        selectedMatchID = nil
                                        replayPly = max(0, replayFrames.count - 1)
                                        playing = false
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(VeilEclipseChrome.accent)
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
                                            .foregroundColor(VeilEclipseChrome.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(saved.status.title + " · \(saved.moves.count) 手")
                                                .font(.caption.weight(.semibold))
                                            Text(saved.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(VeilEclipseChrome.silver)
                                        }
                                        Spacer()
                                        Image(systemName: selectedMatchID == saved.id ? "checkmark.circle.fill" : "chevron.right")
                                            .foregroundColor(VeilEclipseChrome.accent)
                                    }
                                    .foregroundColor(VeilEclipseChrome.white)
                                    .padding(8)
                                    .background(VeilTheme.subtleFill, in: RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                                .disabled(!saved.isReplayable)
                            }
                            if nextOffset != nil {
                                Button("加载更多历史对局") { loadArchivePage() }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(VeilEclipseChrome.accent)
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
                            .foregroundColor(VeilEclipseChrome.silver)
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
                            .foregroundColor(VeilEclipseChrome.silver)
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
            Text(name).font(.caption2).foregroundColor(VeilEclipseChrome.silver)
            Text(value).font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(VeilEclipseChrome.white)
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
                    ctx.stroke(ring, with: .color(VeilEclipseChrome.accent), lineWidth: 1.7)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
