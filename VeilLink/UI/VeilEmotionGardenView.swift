import SwiftUI
import Combine

struct VeilEmotionGardenView: View {
    @State private var tone: VeilEmotionTone = .calm
    @State private var context: VeilEmotionContext = .morning
    @State private var query = ""
    @State private var selected: VeilEmotionRitual?
    @State private var completedIDs = Set<String>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var path: [VeilEmotionRitual] {
        VeilEmotionGardenEngine.dailyPath(for: tone, context: context, date: Date())
    }

    private var displayedRituals: [VeilEmotionRitual] {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? VeilEmotionGardenEngine.rituals(for: tone, context: context)
            : VeilEmotionGardenEngine.search(query)
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                tonePicker
                contextPicker
                note
                searchField
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("今日三步").font(.headline).foregroundColor(VeilTheme.text)
                        Spacer()
                        Text("1000 项 · 完全离线").font(.caption.bold()).foregroundColor(VeilTheme.mutedGold)
                    }
                    ForEach(path) { ritual in ritualCard(ritual) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(query.isEmpty ? "自己挑一个" : "全库搜索结果").font(.headline).foregroundColor(VeilTheme.text)
                        Spacer()
                        Text("\(displayedRituals.count)").font(.caption.monospacedDigit()).foregroundColor(VeilTheme.tertiaryText)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                        ForEach(displayedRituals) { ritual in
                            Button { selected = ritual } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(systemName: ritual.symbol).font(.title3).foregroundColor(VeilTheme.gold)
                                    Text(ritual.kind.title).font(.subheadline.bold()).foregroundColor(VeilTheme.text)
                                    Text("\(ritual.seconds) 秒").font(.caption2).foregroundColor(VeilTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                                .padding(12)
                                .veilCompactToolSurface(cornerRadius: 15)
                            }
                            .buttonStyle(VeilPressStyle())
                        }
                    }
                }
                safetyNote
            }
        }
        .padding(.horizontal, 14)
        .background(VeilAmbientBackground())
        .navigationTitle("情绪花园")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { ritual in
            VeilEmotionRitualSheet(
                ritual: ritual,
                completed: completedIDs.contains(ritual.id),
                markCompleted: { completedIDs.insert(ritual.id) }
            )
        }
        .animation(reduceMotion ? nil : VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion), value: tone)
        .animation(reduceMotion ? nil : VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion), value: context)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EMOTION GARDEN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(VeilTheme.mutedGold)
            Text("给现在的你，一点空间。")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundColor(VeilTheme.text)
            Text("1000 种状态 × 互动 × 场景组合。不是诊断，也没有打卡压力。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [VeilTheme.gold.opacity(0.20), VeilTheme.panelSoft.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var tonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你现在更接近哪一种？").font(.headline).foregroundColor(VeilTheme.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VeilEmotionTone.allCases) { value in
                        Button { tone = value } label: {
                            Text(value.title)
                                .font(.caption.bold())
                                .foregroundColor(tone == value ? VeilTheme.panel : VeilTheme.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(tone == value ? VeilTheme.gold : VeilTheme.panelSoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(VeilPressStyle())
                    }
                }
            }
        }
    }

    private var note: some View {
        Text(VeilEmotionGardenEngine.supportiveNote(for: tone))
            .font(.body)
            .foregroundColor(VeilTheme.text)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .veilCompactToolSurface(cornerRadius: 16)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundColor(VeilTheme.tertiaryText)
            TextField("搜索 EV-编号、状态、场景或内容", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(VeilTheme.tertiaryText)
                }
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 44)
        .veilCompactToolSurface(cornerRadius: 14)
    }

    private var contextPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你正在哪个场景？").font(.headline).foregroundColor(VeilTheme.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VeilEmotionContext.allCases) { value in
                        Button { context = value } label: {
                            Text(value.title)
                                .font(.caption.bold())
                                .foregroundColor(context == value ? VeilTheme.panel : VeilTheme.secondaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(context == value ? VeilTheme.gold : VeilTheme.panelSoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(VeilPressStyle())
                    }
                }
            }
        }
    }

    private func ritualCard(_ ritual: VeilEmotionRitual) -> some View {
        Button { selected = ritual } label: {
            HStack(spacing: 12) {
                Image(systemName: completedIDs.contains(ritual.id) ? "checkmark.circle.fill" : ritual.symbol)
                    .font(.title3)
                    .foregroundColor(completedIDs.contains(ritual.id) ? .green : VeilTheme.gold)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(ritual.context.title) · \(ritual.kind.title)").font(.subheadline.bold()).foregroundColor(VeilTheme.text)
                    Text(ritual.prompt).font(.caption).foregroundColor(VeilTheme.secondaryText).lineLimit(2)
                }
                Spacer(minLength: 0)
                Text("\(ritual.seconds)s").font(.caption2.monospacedDigit()).foregroundColor(VeilTheme.tertiaryText)
            }
            .padding(13)
            .veilCompactToolSurface(cornerRadius: 16)
        }
        .buttonStyle(VeilPressStyle())
    }

    private var safetyNote: some View {
        Text("若你正感到可能伤害自己或他人的紧急危险，请优先联系当地急救服务、危机支持资源或可信任的人。")
            .font(.caption2)
            .foregroundColor(VeilTheme.tertiaryText)
            .padding(.vertical, 8)
    }
}

private struct VeilEmotionRitualSheet: View {
    let ritual: VeilEmotionRitual
    let completed: Bool
    let markCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completedSteps = Set<Int>()
    @StateObject private var clock: VeilEmotionRitualClock

    init(ritual: VeilEmotionRitual, completed: Bool, markCompleted: @escaping () -> Void) {
        self.ritual = ritual
        self.completed = completed
        self.markCompleted = markCompleted
        _clock = StateObject(wrappedValue: VeilEmotionRitualClock(duration: ritual.seconds))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                Image(systemName: ritual.symbol)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(VeilTheme.gold)
                Text(ritual.title).font(.title2.bold()).foregroundColor(VeilTheme.text)
                Text(ritual.prompt).font(.body).foregroundColor(VeilTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(ritual.steps.enumerated()), id: \.offset) { index, step in
                        Button {
                            if completedSteps.contains(index) { completedSteps.remove(index) }
                            else { completedSteps.insert(index) }
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: completedSteps.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(completedSteps.contains(index) ? .green : VeilTheme.tertiaryText)
                                Text(step).font(.subheadline).foregroundColor(VeilTheme.text).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .veilCompactToolSurface(cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                countdown
                HStack(spacing: 10) {
                    Button {
                        clock.toggle()
                    } label: {
                        Label(clock.isRunning ? "暂停" : (clock.remainingSeconds == ritual.seconds ? "开始" : "继续"), systemImage: clock.isRunning ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        clock.reset()
                    } label: {
                        Label("重置", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
                Text("建议用时 \(ritual.seconds) 秒。可以暂停、重置或随时跳过。")
                    .font(.caption).foregroundColor(VeilTheme.tertiaryText)
                if completedSteps.count == ritual.steps.count || clock.remainingSeconds == 0 {
                    Text(ritual.completionNote)
                        .font(.subheadline)
                        .foregroundColor(VeilTheme.goldBright)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .veilCompactToolSurface(cornerRadius: 13)
                }
                Button {
                    markCompleted()
                    dismiss()
                } label: {
                    Label(completed ? "已完成" : "完成这一小步", systemImage: completed ? "checkmark.circle.fill" : "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(VeilTheme.gold.opacity(0.18))
                        .foregroundColor(VeilTheme.goldBright)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(VeilPressStyle())
                }
                .padding(22)
            }
            .background(VeilAmbientBackground())
            .navigationTitle("微小陪伴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .onDisappear { clock.pause() }
        }
    }

    private var countdown: some View {
        let progress = ritual.seconds > 0
            ? Double(ritual.seconds - clock.remainingSeconds) / Double(ritual.seconds)
            : 1
        return ZStack {
            Circle().stroke(VeilTheme.panelSoft, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(VeilTheme.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 3) {
                Text("\(clock.remainingSeconds)").font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().foregroundColor(VeilTheme.text)
                Text(clock.remainingSeconds == 0 ? "完成" : "秒").font(.caption).foregroundColor(VeilTheme.secondaryText)
            }
        }
        .frame(width: 112, height: 112)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .linear(duration: 0.25), value: clock.remainingSeconds)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clock.remainingSeconds == 0 ? "计时完成" : "剩余 \(clock.remainingSeconds) 秒")
    }
}

private final class VeilEmotionRitualClock: ObservableObject {
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isRunning = false

    private let duration: Int
    private var deadline: Date?
    private var timer: Timer?

    init(duration: Int) {
        self.duration = max(1, duration)
        remainingSeconds = max(1, duration)
    }

    func toggle() {
        if isRunning { pause() }
        else { start() }
    }

    func pause() {
        updateRemaining()
        stopTimer()
    }

    func reset() {
        stopTimer()
        remainingSeconds = duration
    }

    private func start() {
        if remainingSeconds == 0 { remainingSeconds = duration }
        deadline = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        let next = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        next.tolerance = 0.15
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func tick() {
        updateRemaining()
        if remainingSeconds == 0 { stopTimer() }
    }

    private func updateRemaining() {
        guard let deadline else { return }
        remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        deadline = nil
        isRunning = false
    }

    deinit { timer?.invalidate() }
}
