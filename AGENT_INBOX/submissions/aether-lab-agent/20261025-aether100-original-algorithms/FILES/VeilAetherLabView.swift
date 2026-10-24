import SwiftUI

/// Offline-only lab: every result is from explicitly entered or synthetic JSON.
/// Never label this as a live device scanner, cryptographic audit or mesh controller.
struct VeilAetherLabView: View {
    @State private var query = ""
    @State private var selected = 201
    @State private var json = VeilAetherEngine.exampleJSON
    @State private var report: VeilAetherReport?
    @State private var errorText = ""
    @State private var onlyResults = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var choices: [VeilAetherFeature] {
        let filter = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return VeilAetherEngine.catalog.filter { filter.isEmpty || $0.title.localizedCaseInsensitiveContains(filter)
            || $0.domain.localizedCaseInsensitiveContains(filter) || String($0.number).contains(filter) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("AETHER LAB / 100 EXPERIMENTS")
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundColor(.secondary)
                    Text("百项离线稀有计算实验室").font(.title2.bold())
                    Text("仅对手动输入的去标识化 JSON 运算。不会读取数据库、私钥、聊天内容或真实设备日志。")
                        .font(.footnote).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.secondary.opacity(0.10)))

                TextField("按编号、功能或分组检索", text: $query)
                    .textInputAutocapitalization(.never).disableAutocorrection(true)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
                    .accessibilityIdentifier("aether.search")

                if !onlyResults {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("选择实验").font(.headline)
                        ForEach(choices) { item in
                            Button {
                                selected = item.number
                                report = nil
                                errorText = ""
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(String(format: "%03d", item.number)).font(.caption.monospacedDigit())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.subheadline.weight(.semibold))
                                        Text(item.domain).font(.caption2).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selected == item.number { Image(systemName: "checkmark.circle.fill") }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8).padding(.horizontal, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(RoundedRectangle(cornerRadius: 10).fill(selected == item.number ? Color.accentColor.opacity(0.13) : Color.secondary.opacity(0.05)))
                            .accessibilityIdentifier("aether.feature.\(item.number)")
                        }
                    }
                }

                Toggle("收起功能目录", isOn: $onlyResults)
                Text("输入 JSON（≤32 KiB）").font(.headline)
                TextEditor(text: $json)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 165)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))
                    .accessibilityIdentifier("aether.json")
                HStack {
                    Button("恢复样本") {
                        json = VeilAetherEngine.exampleJSON
                        report = nil
                        errorText = ""
                    }.buttonStyle(.bordered)
                    Spacer()
                    Button("运行选中功能") { evaluate() }
                        .buttonStyle(.borderedProminent)
                        .disabled(json.utf8.count > 32768)
                        .accessibilityIdentifier("aether.run")
                }
                if !errorText.isEmpty {
                    Text(errorText).foregroundColor(.red).font(.footnote)
                        .accessibilityIdentifier("aether.error")
                }
                if let report {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(report.featureID) · \(report.title)").font(.headline)
                        Text(report.output).font(.body.monospaced())
                            .textSelection(.enabled)
                        Text(report.note).font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.10)))
                    .accessibilityIdentifier("aether.result")
                }
                Text("实验性质：本地人工样本 · 原创算法候选 · 不代表 100 项真实蓝牙/游戏服务已上线。")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(14)
        }
        .navigationTitle("AetherLab 100")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func evaluate() {
        do {
            report = try VeilAetherEngine.run(selected, json: json)
            errorText = ""
        } catch {
            report = nil
            errorText = error.localizedDescription
        }
    }
}
