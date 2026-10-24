import SwiftUI

/// iOS 15-compatible standalone lab: user-entered, anonymized JSON only.
/// No diagnostic privilege or network operation is executed by this view.
struct VeilRareLabView: View {
    @State private var search = ""
    @State private var selection = 1
    @State private var input = VeilRareLab.sample(for: 1)
    @State private var result = ""
    @State private var errors = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var matches: [VeilRareTool] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return VeilRareLab.catalog }
        return VeilRareLab.catalog.filter { $0.title.localizedCaseInsensitiveContains(query)
            || $0.category.localizedCaseInsensitiveContains(query)
            || $0.detail.localizedCaseInsensitiveContains(query)
            || "\($0.id)" == query }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("RARE LAB · OFFLINE FORENSICS")
                        .font(.caption.monospaced().weight(.bold))
                    Text("40 项稀有运算器").font(.title2.bold())
                    Text("本地手动输入脱敏 JSON，立即分析。不会读取密钥、扫描其他设备或变更实际通信行为。")
                        .font(.footnote).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                TextField("搜索 40 项能力", text: $search)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("rareLab.search")

                ForEach(["无线与 Mesh", "传输与恢复", "身份与隐私", "触控与取证"], id: \.self) { category in
                    let group = matches.filter { $0.category == category }
                    if !group.isEmpty {
                        Text(category).font(.headline).padding(.top, 7)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                            ForEach(group) { tool in
                                Button {
                                    selection = tool.id
                                    input = VeilRareLab.sample(for: tool.id)
                                    result = ""; errors = ""
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(String(format: "%02d · %@", tool.id, tool.title))
                                            .font(.subheadline.weight(.semibold))
                                            .multilineTextAlignment(.leading)
                                        Text(tool.detail).font(.caption2)
                                            .foregroundColor(.secondary).lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                    .padding(9)
                                    .background(RoundedRectangle(cornerRadius: 11)
                                        .fill(selection == tool.id ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("rareLab.tool.\(tool.id)")
                            }
                        }
                    }
                }
                Divider().padding(.vertical, 4)
                if let active = VeilRareLab.catalog.first(where: { $0.id == selection }) {
                    Text("#\(selection) · \(active.title)").font(.headline)
                    Text(active.detail).font(.footnote).foregroundColor(.secondary)
                }
                Text("输入区仅接受匿名示例。请勿输入实际聊天内容、身份密钥、真实二维码或私人信息。")
                    .font(.caption2).foregroundColor(.orange)
                TextEditor(text: $input)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 125)
                    .padding(5)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.35)))
                    .accessibilityIdentifier("rareLab.input")
                HStack {
                    Button("运行本地分析") {
                        do { result = try VeilRareLab.run(id: selection, json: input); errors = "" }
                        catch { errors = error.localizedDescription; result = "" }
                    }.buttonStyle(.borderedProminent)
                    Button("恢复示例") { input = VeilRareLab.sample(for: selection); result = ""; errors = "" }
                        .buttonStyle(.bordered)
                }
                if !errors.isEmpty { Text(errors).font(.footnote).foregroundColor(.red) }
                if !result.isEmpty {
                    Text(result).font(.subheadline.monospaced())
                        .textSelection(.enabled).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
                        .accessibilityIdentifier("rareLab.output")
                }
                Text("计算结果是有限样本的离线启发式分析，不等于真实 BLE 链路、身份校验或触控失效的最终判定。")
                    .font(.caption2).foregroundColor(.secondary).padding(.bottom, 20)
            }.padding(16)
        }
        .navigationTitle("稀有能力实验室")
        .navigationBarTitleDisplayMode(.inline)
    }
}