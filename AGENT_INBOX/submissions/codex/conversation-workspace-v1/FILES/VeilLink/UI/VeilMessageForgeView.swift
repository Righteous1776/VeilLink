import SwiftUI

struct VeilMessageForgeView: View {
    let initialText: String
    let onApply: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var source: String
    @State private var style: VeilMessageForgeStyle = .original

    init(initialText: String, onApply: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onApply = onApply
        _source = State(initialValue: initialText)
    }

    private var output: String { VeilMessageForge.render(source, style: style) }
    private var analysis: VeilMessageForgeAnalysis { VeilMessageForge.analyze(output) }

    var body: some View {
        NavigationView {
            VeilStableScrollView {
                VStack(spacing: 14) {
                    heroCard
                    templatesCard
                    editorCard
                    styleCard
                    safetyCard
                    previewCard
                }
            }
            .background(VeilAmbientBackground())
            .navigationTitle("消息锻造台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("回填") {
                        onApply(output)
                        dismiss()
                    }
                    .disabled(output.isEmpty || !analysis.withinSingleMessageLimit || analysis.findings.contains { $0.severity == .critical })
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("LOCAL COMPOSE", systemImage: "hammer.fill")
                    .font(VeilType.terminalLabel).foregroundColor(VeilTheme.mutedGold)
                Spacer()
                Text(analysis.withinSingleMessageLimit ? "READY" : "OVER LIMIT")
                    .font(VeilType.terminalLabel)
                    .foregroundColor(analysis.withinSingleMessageLimit ? VeilTheme.success : VeilTheme.danger)
            }
            Text("写得更清楚，发得更安全")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("模板、格式、UTF-8 协议预算与敏感内容检查全部在本机完成。")
                .font(.caption).foregroundColor(VeilTheme.secondaryText)
            HStack(spacing: 8) {
                metric("字符", analysis.characters)
                metric("字节", analysis.utf8Bytes)
                metric("行", analysis.lines)
                metric("分段", analysis.segments.count)
            }
        }
        .veilCard(emphasized: true)
    }

    private var templatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("结构模板").font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VeilMessageForgeTemplate.allCases) { template in
                        Button(template.title) {
                            source = template.text
                            style = .original
                        }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                    }
                }
            }
        }
        .veilCard()
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("原始内容").font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
                Spacer()
                if !source.isEmpty { Button("清空", role: .destructive) { source = "" }.font(.caption) }
            }
            TextEditor(text: $source)
                .font(.body)
                .frame(minHeight: 150)
                .padding(8)
                .background(VeilTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .veilCard()
    }

    private var styleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("整理方式").font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
            Picker("整理方式", selection: $style) {
                ForEach(VeilMessageForgeStyle.allCases) { value in Text(value.title).tag(value) }
            }
            .pickerStyle(.segmented)
            Text("所有变化都可在下方预览；不会自动发送。")
                .font(.caption2).foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard()
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("发送前检查", systemImage: analysis.findings.isEmpty ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(VeilType.cardTitle)
                .foregroundColor(analysis.findings.isEmpty ? VeilTheme.success : VeilTheme.gold)
            if analysis.findings.isEmpty {
                Text("没有发现常见的密钥、令牌、密码或联系方式模式。启发式检查不能代替人工确认。")
                    .font(.caption).foregroundColor(VeilTheme.secondaryText)
            } else {
                ForEach(analysis.findings) { finding in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title).font(.subheadline.weight(.semibold))
                        Text(finding.guidance).font(.caption).foregroundColor(VeilTheme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .veilCard()
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("发送预览").font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
                Spacer()
                Text("\(analysis.utf8Bytes)/\(VeilMessageForge.maximumMessageBytes) B")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(analysis.withinSingleMessageLimit ? VeilTheme.secondaryText : VeilTheme.danger)
            }
            Text(output.isEmpty ? "输入内容或选择模板" : output)
                .font(.body)
                .foregroundColor(output.isEmpty ? VeilTheme.tertiaryText : VeilTheme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(VeilTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if analysis.segments.count > 1 {
                Text("当前内容需要拆成 \(analysis.segments.count) 条消息。为避免部分发送，锻造台只提供预览，不会自动连发。")
                    .font(.caption).foregroundColor(VeilTheme.gold)
            }
        }
        .veilCard()
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.subheadline.bold().monospacedDigit())
            Text(title).font(.caption2).foregroundColor(VeilTheme.secondaryText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(VeilTheme.subtleFill).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
