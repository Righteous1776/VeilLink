import SwiftUI

struct VeilEmotionGardenView: View {
    @State private var tone: VeilEmotionTone = .calm
    @State private var selected: VeilEmotionRitual?
    @State private var completedIDs = Set<String>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var path: [VeilEmotionRitual] {
        VeilEmotionGardenEngine.dailyPath(for: tone, date: Date())
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                tonePicker
                note
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("今日三步").font(.headline).foregroundColor(VeilTheme.text)
                        Spacer()
                        Text("完全离线").font(.caption.bold()).foregroundColor(VeilTheme.mutedGold)
                    }
                    ForEach(path) { ritual in ritualCard(ritual) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("自己挑一个").font(.headline).foregroundColor(VeilTheme.text)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                        ForEach(VeilEmotionGardenEngine.rituals(for: tone)) { ritual in
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
            Text("不是诊断、不是打卡压力；只是一组可随时跳过的微小陪伴。")
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

    private func ritualCard(_ ritual: VeilEmotionRitual) -> some View {
        Button { selected = ritual } label: {
            HStack(spacing: 12) {
                Image(systemName: completedIDs.contains(ritual.id) ? "checkmark.circle.fill" : ritual.symbol)
                    .font(.title3)
                    .foregroundColor(completedIDs.contains(ritual.id) ? .green : VeilTheme.gold)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(ritual.kind.title).font(.subheadline.bold()).foregroundColor(VeilTheme.text)
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

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: ritual.symbol)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(VeilTheme.gold)
                Text(ritual.title).font(.title2.bold()).foregroundColor(VeilTheme.text)
                Text(ritual.prompt).font(.body).foregroundColor(VeilTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                Text("建议用时 \(ritual.seconds) 秒。你可以随时跳过。")
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
        }
    }
}
