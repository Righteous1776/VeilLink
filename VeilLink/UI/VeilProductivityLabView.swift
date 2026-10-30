import SwiftUI
import UIKit

struct VeilProductivityLabView: View {
    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRODUCTIVITY LAB")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("协作效率实验室")
                        .font(.title2.bold())
                        .foregroundColor(VeilTheme.text)
                    Text("所有计算均在本机完成；不会自动发送、导入或修改聊天。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                labLink("变量消息模板", detail: "复用常用消息，并在发送前检查漏填项", icon: "text.badge.checkmark", destination: VeilTemplateWorkbenchView())
                labLink("文本差异", detail: "逐行比较两个版本，清晰标出新增与删除", icon: "arrow.left.arrow.right", destination: VeilTextDiffView())
                labLink("三方合并", detail: "基线、本机、对端的保守合并与冲突提示", icon: "arrow.triangle.merge", destination: VeilThreeWayMergeView())
                labLink("跨时区规划", detail: "按参与者工作时间推荐共同可用时段", icon: "globe", destination: VeilTimeZonePlannerView())
                labLink("导入预检", detail: "导入前检查文件名、重复项、类型和总大小", icon: "tray.and.arrow.down.fill", destination: VeilImportPreflightView())
            }
        }
        .padding(.horizontal, 14)
        .background(VeilAmbientBackground())
        .navigationTitle("效率实验室")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labLink<Destination: View>(_ title: String, detail: String, icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(VeilTheme.gold)
                    .frame(width: 42, height: 42)
                    .background(VeilTheme.gold.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundColor(VeilTheme.text)
                    Text(detail).font(.caption).foregroundColor(VeilTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(VeilTheme.tertiaryText)
            }
            .padding(14)
            .veilCompactToolSurface(cornerRadius: 16)
        }
        .buttonStyle(VeilPressStyle())
    }
}

private struct VeilTemplateWorkbenchView: View {
    @State private var template = "你好 {{称呼}}，文件 {{文件名}} 已准备好。"
    @State private var values: [String: String] = [:]
    @State private var result = ""
    @State private var error = ""

    private var variables: [String] {
        (try? VeilProductivityEngine.analyzeTemplate(template).variables) ?? []
    }

    var body: some View {
        VeilLabForm(title: "变量消息模板", note: "使用 {{变量名}}。生成结果只会留在本页，不会自动发送。") {
            VeilLabEditor(title: "模板", text: $template, minimumHeight: 110)
            ForEach(variables, id: \.self) { variable in
                VStack(alignment: .leading, spacing: 5) {
                    Text(variable).font(.caption.bold()).foregroundColor(VeilTheme.secondaryText)
                    TextField("填写 \(variable)", text: Binding(
                        get: { values[variable, default: ""] },
                        set: { values[variable] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
            VeilLabAction(title: "生成预览", icon: "wand.and.stars") { render() }
            VeilLabResult(text: result, error: error)
        }
        .navigationTitle("变量模板")
    }

    private func render() {
        do { result = try VeilProductivityEngine.renderTemplate(template, values: values); error = "" }
        catch { result = ""; self.error = error.localizedDescription }
    }
}

private struct VeilTextDiffView: View {
    @State private var old = "第一行\n旧内容"
    @State private var new = "第一行\n新内容"
    @State private var diff: [VeilDiffLine] = []
    @State private var error = ""

    var body: some View {
        VeilLabForm(title: "文本差异", note: "最多每侧 400 行 / 64 KB，计算有硬上限，不会拖垮老设备。") {
            VeilLabEditor(title: "旧版本", text: $old, minimumHeight: 90)
            VeilLabEditor(title: "新版本", text: $new, minimumHeight: 90)
            VeilLabAction(title: "比较", icon: "arrow.left.arrow.right") { compare() }
            if !error.isEmpty { Text(error).font(.caption).foregroundColor(.red) }
            if !diff.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(diff.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 7) {
                            Text(marker(line.kind)).frame(width: 12)
                            Text(line.text.isEmpty ? " " : line.text).textSelection(.enabled)
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(color(line.kind))
                    }
                }
                .padding(12)
                .veilCompactToolSurface(cornerRadius: 13)
            }
        }
        .navigationTitle("文本差异")
    }

    private func compare() {
        do { diff = try VeilProductivityEngine.diff(old: old, new: new); error = "" }
        catch { diff = []; self.error = error.localizedDescription }
    }
    private func marker(_ kind: VeilDiffKind) -> String { kind == .added ? "+" : (kind == .removed ? "−" : " ") }
    private func color(_ kind: VeilDiffKind) -> Color { kind == .added ? .green : (kind == .removed ? .red : VeilTheme.secondaryText) }
}

private struct VeilThreeWayMergeView: View {
    @State private var base = "共同基线"
    @State private var local = "共同基线"
    @State private var remote = "对端修改"
    @State private var result = ""
    @State private var error = ""

    var body: some View {
        VeilLabForm(title: "三方合并", note: "仅在一侧改动时自动合并；两侧均改变时保留双方并明确标记冲突。") {
            VeilLabEditor(title: "基线", text: $base, minimumHeight: 70)
            VeilLabEditor(title: "本机", text: $local, minimumHeight: 70)
            VeilLabEditor(title: "对端", text: $remote, minimumHeight: 70)
            VeilLabAction(title: "安全合并", icon: "arrow.triangle.merge") {
                do { let merged = try VeilProductivityEngine.threeWayMerge(base: base, local: local, remote: remote); result = merged.text; error = merged.hasConflict ? "检测到双边冲突，请人工选择后再发送。" : "" }
                catch { result = ""; self.error = error.localizedDescription }
            }
            VeilLabResult(text: result, error: error)
        }
        .navigationTitle("三方合并")
    }
}

private struct VeilTimeZonePlannerView: View {
    @State private var zoneText = "上海|Asia/Shanghai|9|18\n纽约|America/New_York|9|18"
    @State private var start = Date()
    @State private var slots: [VeilMeetingSlot] = []
    @State private var error = ""

    var body: some View {
        VeilLabForm(title: "跨时区规划", note: "每行格式：名称|IANA 时区|开始小时|结束小时。自动按夏令时换算。") {
            VeilLabEditor(title: "参与者", text: $zoneText, minimumHeight: 110)
            DatePicker("从此时间开始", selection: $start)
                .foregroundColor(VeilTheme.text)
            VeilLabAction(title: "推荐时段", icon: "clock.badge.checkmark") { calculate() }
            if !error.isEmpty { Text(error).font(.caption).foregroundColor(.red) }
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                VStack(alignment: .leading, spacing: 5) {
                    Text("舒适度 \(slot.comfortableParticipantCount)/\(slot.totalParticipantCount)").font(.subheadline.bold()).foregroundColor(VeilTheme.gold)
                    ForEach(slot.localTimes, id: \.self) { Text($0).font(.caption).foregroundColor(VeilTheme.secondaryText) }
                }
                .padding(12)
                .veilCompactToolSurface(cornerRadius: 13)
            }
        }
        .navigationTitle("跨时区规划")
    }

    private func calculate() {
        let rows = zoneText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let participants = rows.compactMap { line -> VeilTimeZoneParticipant? in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 4, let begin = Int(parts[2]), let end = Int(parts[3]), (0...23).contains(begin), (1...24).contains(end), begin < end else { return nil }
            return VeilTimeZoneParticipant(label: parts[0], timeZoneIdentifier: parts[1], preferredStartHour: begin, preferredEndHour: end)
        }
        guard participants.count == rows.count else {
            slots = []
            error = "存在格式或工作时间无效的参与者行"
            return
        }
        do { slots = try VeilProductivityEngine.meetingSlots(from: start, participants: participants); error = "" }
        catch { slots = []; self.error = error.localizedDescription }
    }
}

private struct VeilImportPreflightView: View {
    @State private var itemText = "photo.jpg|2048000\nnotes.txt|1024"
    @State private var extensions = "jpg,png,txt,pdf"
    @State private var result: VeilImportPreflight?
    @State private var error = ""

    var body: some View {
        VeilLabForm(title: "导入预检", note: "每行格式：文件名|字节数。这里只做风险检查，不会读取或导入文件。") {
            VeilLabEditor(title: "清单", text: $itemText, minimumHeight: 110)
            VStack(alignment: .leading, spacing: 5) {
                Text("允许扩展名（逗号分隔）").font(.caption.bold()).foregroundColor(VeilTheme.secondaryText)
                TextField("留空表示不限", text: $extensions).textFieldStyle(.roundedBorder)
            }
            VeilLabAction(title: "执行预检", icon: "checkmark.shield") { inspect() }
            if !error.isEmpty { Text(error).font(.caption).foregroundColor(.red) }
            if let result {
                VStack(alignment: .leading, spacing: 7) {
                    Label(result.canImport ? "预检通过" : "需要处理", systemImage: result.canImport ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.headline).foregroundColor(result.canImport ? .green : .orange)
                    Text("\(result.itemCount) 项 · \(ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file))")
                        .font(.caption).foregroundColor(VeilTheme.secondaryText)
                    ForEach(Array(result.issues.enumerated()), id: \.offset) { _, issue in
                        Text("• \(issue.itemName.map { "\($0)：" } ?? "")\(issue.message)")
                            .font(.caption).foregroundColor(issue.severity == .blocking ? .red : .orange)
                    }
                }
                .padding(12)
                .veilCompactToolSurface(cornerRadius: 13)
            }
        }
        .navigationTitle("导入预检")
    }

    private func inspect() {
        let rows = itemText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let items = rows.compactMap { line -> VeilImportItem? in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2, let bytes = Int64(parts[1]) else { return nil }
            return VeilImportItem(name: parts[0], byteCount: bytes)
        }
        guard items.count == rows.count else {
            result = nil
            error = "存在格式或字节数无效的清单行"
            return
        }
        let allowed = Set(extensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
        do { result = try VeilProductivityEngine.importPreflight(items: items, allowedExtensions: allowed); error = "" }
        catch { result = nil; self.error = error.localizedDescription }
    }
}

private struct VeilLabForm<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder let content: Content

    init(title: String, note: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.title2.bold()).foregroundColor(VeilTheme.text)
                Text(note).font(.caption).foregroundColor(VeilTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                content
            }
        }
        .padding(.horizontal, 14)
        .background(VeilAmbientBackground())
    }
}

private struct VeilLabEditor: View {
    let title: String
    @Binding var text: String
    let minimumHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.bold()).foregroundColor(VeilTheme.secondaryText)
            TextEditor(text: $text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(VeilTheme.text)
                .frame(minHeight: minimumHeight)
                .padding(8)
                .veilCompactToolSurface(cornerRadius: 12)
        }
    }
}

private struct VeilLabAction: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(VeilTheme.gold.opacity(0.16))
                .foregroundColor(VeilTheme.goldBright)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(VeilPressStyle())
    }
}

private struct VeilLabResult: View {
    let text: String
    let error: String

    var body: some View {
        if !error.isEmpty { Text(error).font(.caption).foregroundColor(.red) }
        if !text.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                Text(text).font(.system(size: 13, design: .monospaced)).foregroundColor(VeilTheme.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Button("复制") { UIPasteboard.general.string = text }
                    .font(.caption.bold()).foregroundColor(VeilTheme.gold)
            }
            .padding(12)
            .veilCompactToolSurface(cornerRadius: 13)
        }
    }
}
