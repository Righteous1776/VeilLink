import SwiftUI
import Combine

struct VeilEmotionGardenView: View {
    @State private var tone: VeilEmotionTone = .calm
    @State private var context: VeilEmotionContext = .morning
    @State private var selected: VeilEmotionRitual?
    @State private var completedIDs = Set<String>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var path: [VeilEmotionRitual] {
        VeilEmotionGardenEngine.dailyPath(for: tone, context: context, date: Date())
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                tonePicker
                contextPicker
                note
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("今日三步").font(.headline).foregroundColor(VeilTheme.text)
                        Spacer()
                        Text("1000 项 · 完全离线").font(.caption.bold()).foregroundColor(VeilTheme.mutedGold)
                    }
                    ForEach(path) { ritual in ritualCard(ritual) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("自己挑一个").font(.headline).foregroundColor(VeilTheme.text)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                        ForEach(VeilEmotionGardenEngine.rituals(for: tone, context: context)) { ritual in
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
    @State private var remainingSeconds: Int
    @State private var isRunning = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(ritual: VeilEmotionRitual, completed: Bool, markCompleted: @escaping () -> Void) {
        self.ritual = ritual
        self.completed = completed
        self.markCompleted = markCompleted
        _remainingSeconds = State(initialValue: ritual.seconds)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: ritual.symbol)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(VeilTheme.gold)
                Text(ritual.title).font(.title2.bold()).foregroundColor(VeilTheme.text)
                Text(ritual.prompt).font(.body).foregroundColor(VeilTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                countdown
                HStack(spacing: 10) {
                    Button {
                        if remainingSeconds == 0 { remainingSeconds = ritual.seconds }
                        isRunning.toggle()
                    } label: {
                        Label(isRunning ? "暂停" : (remainingSeconds == ritual.seconds ? "开始" : "继续"), systemImage: isRunning ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        isRunning = false
                        remainingSeconds = ritual.seconds
                    } label: {
                        Label("重置", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
                Text("建议用时 \(ritual.seconds) 秒。可以暂停、重置或随时跳过。")
                    .font(.caption).foregroundColor(VeilTheme.tertiaryText)
                Spacer()
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
            .background(VeilAmbientBackground())
            .navigationTitle("微小陪伴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .onReceive(ticker) { _ in
                guard isRunning else { return }
                if remainingSeconds > 1 {
                    remainingSeconds -= 1
                } else {
                    remainingSeconds = 0
                    isRunning = false
                }
            }
        }
    }

    private var countdown: some View {
        let progress = ritual.seconds > 0
            ? Double(ritual.seconds - remainingSeconds) / Double(ritual.seconds)
            : 1
        return ZStack {
            Circle().stroke(VeilTheme.panelSoft, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(VeilTheme.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 3) {
                Text("\(remainingSeconds)").font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().foregroundColor(VeilTheme.text)
                Text(remainingSeconds == 0 ? "完成" : "秒").font(.caption).foregroundColor(VeilTheme.secondaryText)
            }
        }
        .frame(width: 112, height: 112)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .linear(duration: 0.25), value: remainingSeconds)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(remainingSeconds == 0 ? "计时完成" : "剩余 \(remainingSeconds) 秒")
    }
}
