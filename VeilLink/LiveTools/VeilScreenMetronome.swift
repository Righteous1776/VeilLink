import Combine
import SwiftUI
import UIKit

@MainActor
final class VeilMetronomeController: ObservableObject {
    @Published var bpm: Double = 120
    @Published var beatsPerBar = 4
    @Published var hapticsEnabled = true
    @Published private(set) var state: VeilLiveToolState = .idle
    @Published private(set) var beatIndex = 0
    @Published private(set) var startedAt: Date?

    private var beatTimer: Timer?
    private var tapDates: [Date] = []

    var tempoName: String {
        switch bpm {
        case ..<60: return "Largo"
        case ..<76: return "Adagio"
        case ..<108: return "Andante"
        case ..<120: return "Moderato"
        case ..<168: return "Allegro"
        default: return "Presto"
        }
    }

    func toggle() { state.isRunning ? stop() : start() }

    func start() {
        stop(resetState: false)
        bpm = max(30, min(240, bpm.rounded()))
        beatIndex = 0
        startedAt = Date()
        state = .running
        emitBeat()
        scheduleNextBeat()
    }

    func stop() { stop(resetState: true) }

    func updateTempo(_ value: Double) {
        bpm = max(30, min(240, value.rounded()))
        if state.isRunning { start() }
    }

    func registerTap(at date: Date = Date()) {
        tapDates = tapDates.filter { date.timeIntervalSince($0) < 3 }
        tapDates.append(date)
        guard tapDates.count >= 2 else { return }
        let intervals = zip(tapDates.dropFirst(), tapDates).map { newer, older in
            newer.timeIntervalSince(older)
        }.filter { $0 > 0.2 && $0 < 2 }
        guard !intervals.isEmpty else { return }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        updateTempo(60 / average)
        if tapDates.count > 6 { tapDates.removeFirst(tapDates.count - 6) }
    }

    func visualProgress(at date: Date) -> Double {
        guard state.isRunning, let startedAt else { return 0 }
        return max(0, date.timeIntervalSince(startedAt)) / VeilLiveToolMath.metronomeInterval(bpm: bpm)
    }

    private func stop(resetState: Bool) {
        beatTimer?.invalidate()
        beatTimer = nil
        startedAt = nil
        beatIndex = 0
        if resetState, state.isRunning { state = .idle }
    }

    private func scheduleNextBeat() {
        let interval = VeilLiveToolMath.metronomeInterval(bpm: bpm)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state.isRunning else { return }
                self.beatIndex = (self.beatIndex + 1) % max(1, self.beatsPerBar)
                self.emitBeat()
                self.scheduleNextBeat()
            }
        }
        timer.tolerance = min(0.006, interval * 0.012)
        RunLoop.main.add(timer, forMode: .common)
        beatTimer = timer
    }

    private func emitBeat() {
        guard hapticsEnabled else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle = beatIndex == 0 ? .heavy : .light
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct VeilScreenMetronomeView: View {
    @StateObject private var controller = VeilMetronomeController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("FRAME-SYNC VISUAL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(VeilTheme.mutedGold)
                            Text("屏幕节拍器")
                                .font(.title2.bold())
                                .foregroundColor(VeilTheme.text)
                        }
                        Spacer()
                        VeilLiveStateBadge(state: controller.state)
                    }

                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !controller.state.isRunning || reduceMotion)) { context in
                        VeilMetronomeDial(
                            progress: controller.visualProgress(at: context.date),
                            beatIndex: controller.beatIndex,
                            beatsPerBar: controller.beatsPerBar,
                            active: controller.state.isRunning
                        )
                    }
                    .frame(height: 260)

                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(Int(controller.bpm))")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(VeilTheme.goldBright)
                        Text("BPM")
                            .font(.caption.bold())
                            .foregroundColor(VeilTheme.secondaryText)
                        Spacer()
                        Text(controller.tempoName)
                            .font(.headline.italic())
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                }
                .veilCard(emphasized: true)

                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        tempoButton(systemImage: "minus", delta: -1)
                        Slider(value: Binding(
                            get: { controller.bpm },
                            set: { controller.bpm = $0 }
                        ), in: 30...240, step: 1) { editing in
                            if !editing { controller.updateTempo(controller.bpm) }
                        }
                        .tint(VeilTheme.gold)
                        tempoButton(systemImage: "plus", delta: 1)
                    }

                    HStack {
                        Text("每小节")
                            .font(.caption)
                            .foregroundColor(VeilTheme.secondaryText)
                        Picker("每小节拍数", selection: $controller.beatsPerBar) {
                            ForEach(2...8, id: \.self) { Text("\($0) 拍").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(VeilTheme.goldBright)
                        Spacer()
                        Toggle("触感", isOn: $controller.hapticsEnabled)
                            .font(.caption)
                            .tint(VeilTheme.gold)
                            .fixedSize()
                    }
                }
                .veilCard()

                HStack(spacing: 10) {
                    Button("TAP 测速") { controller.registerTap() }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                    if controller.state.isRunning {
                        Button("停止") { controller.stop() }
                            .buttonStyle(VeilGameSecondaryButtonStyle())
                    } else {
                        Button("开始") { controller.start() }
                            .buttonStyle(VeilGamePrimaryButtonStyle())
                    }
                }

                VeilLiveStatusPanel(
                    state: controller.state,
                    title: "60 FPS 时间驱动指针",
                    detail: "视觉指针按绝对时间计算，不依赖逐帧累加；系统卡顿后会自动回到正确拍点。全程无需麦克风或网络权限。"
                )
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("屏幕节拍器")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { phase in
            if phase != .active { controller.stop() }
        }
        .onDisappear { controller.stop() }
    }

    private func tempoButton(systemImage: String, delta: Double) -> some View {
        Button {
            controller.updateTempo(controller.bpm + delta)
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(VeilTheme.panelSoft)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundColor(VeilTheme.goldBright)
        .accessibilityLabel(delta > 0 ? "增加速度" : "降低速度")
    }
}

private struct VeilMetronomeDial: View {
    let progress: Double
    let beatIndex: Int
    let beatsPerBar: Int
    let active: Bool

    private var phase: Double { progress.truncatingRemainder(dividingBy: 1) }
    private var armAngle: Double { active ? cos(progress * .pi) * 31 : 0 }
    private var pulse: Double { active ? exp(-phase * 8) : 0 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.25))
            Circle()
                .fill(VeilTheme.gold.opacity(0.06 + pulse * 0.18))
                .frame(width: 190, height: 190)
                .scaleEffect(0.9 + pulse * 0.12)
            ForEach(0..<beatsPerBar, id: \.self) { index in
                Circle()
                    .fill(index == beatIndex && active ? VeilTheme.goldBright : VeilTheme.panelSoft)
                    .frame(width: index == beatIndex && active ? 10 : 7, height: index == beatIndex && active ? 10 : 7)
                    .offset(x: CGFloat(index - (beatsPerBar - 1) / 2) * 20, y: 101)
            }
            VStack(spacing: 0) {
                Capsule()
                    .fill(LinearGradient(colors: [VeilTheme.goldBright, VeilTheme.gold], startPoint: .top, endPoint: .bottom))
                    .frame(width: 7, height: 150)
                    .overlay(alignment: .top) {
                        Circle().fill(Color.white.opacity(0.9)).frame(width: 13, height: 13).offset(y: 20)
                    }
                Circle()
                    .fill(VeilTheme.panel)
                    .overlay(Circle().stroke(VeilTheme.gold, lineWidth: 3))
                    .frame(width: 25, height: 25)
                    .offset(y: -12)
            }
            .offset(y: 23)
            .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: 0.5, y: 0.87))
            .shadow(color: VeilTheme.gold.opacity(0.28), radius: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("实时节拍指针")
        .accessibilityValue(active ? "第 \(beatIndex + 1) 拍，共 \(beatsPerBar) 拍" : "已停止")
    }
}
