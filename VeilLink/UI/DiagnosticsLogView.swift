import SwiftUI
import UIKit

struct DiagnosticsLogView: View {
    @ObservedObject var store: DiagnosticLogStore
    @State private var query = ""
    @State private var minimumLevel: DiagnosticLogLevel? = nil
    @State private var category: DiagnosticLogCategory? = nil
    @State private var onlyCurrentScreen = false

    private var filteredEntries: [DiagnosticLogEntry] {
        store.recentEntries.filter { entry in
            let levelMatches = minimumLevel.map { entry.level.rank >= $0.rank } ?? true
            let categoryMatches = category.map { entry.category == $0 } ?? true
            let screenMatches = !onlyCurrentScreen || entry.screen == DeepTelemetry.shared.currentScreen
            let queryMatches: Bool
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                queryMatches = true
            } else {
                let needle = query.lowercased()
                queryMatches = entry.event.lowercased().contains(needle)
                    || entry.message.lowercased().contains(needle)
                    || entry.category.rawValue.lowercased().contains(needle)
                    || (entry.screen?.lowercased().contains(needle) ?? false)
                    || entry.metadata.contains { key, value in
                        key.lowercased().contains(needle) || value.lowercased().contains(needle)
                    }
            }
            return levelMatches && categoryMatches && screenMatches && queryMatches
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label("黑匣子", systemImage: "waveform.path.ecg.rectangle")
                    Spacer()
                    Text("\(store.recentEntries.count) · \(store.diskUsageText)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("当前界面")
                    Spacer()
                    Text(DeepTelemetry.shared.currentScreen)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                }

                Picker("最低级别", selection: $minimumLevel) {
                    Text("全部").tag(Optional<DiagnosticLogLevel>.none)
                    ForEach(DiagnosticLogLevel.allCases) { level in
                        Text(level.title).tag(Optional(level))
                    }
                }

                Picker("模块", selection: $category) {
                    Text("全部").tag(Optional<DiagnosticLogCategory>.none)
                    ForEach(DiagnosticLogCategory.allCases) { value in
                        Text(value.title).tag(Optional(value))
                    }
                }

                Toggle("仅当前界面", isOn: $onlyCurrentScreen)
            } footer: {
                Text("内存显示最近 2,000 条；磁盘约 \(store.retentionText) 环形保留。UI 点击、手势、页面、输入生命周期、BLE、A9、Agent 与系统快照统一按时间序列记录。")
            }

            Section("时间线") {
                if filteredEntries.isEmpty {
                    Text("没有符合条件的日志。")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredEntries.reversed()) { entry in
                        NavigationLink {
                            DiagnosticLogDetailView(entry: entry)
                        } label: {
                            DiagnosticLogRow(entry: entry)
                        }
                    }
                }
            }
        }
        .navigationTitle("Deep Telemetry")
        .searchable(text: $query, prompt: "事件、界面、模块、ID 或状态")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.refreshFromDisk()
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("diagnostics.refresh")
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("重新读取日志")
                .accessibilityIdentifier("diagnostics.refresh")
            }
        }
        .telemetryScreen("owner.telemetry.timeline")
        .onAppear { store.refreshFromDisk() }
    }
}

private struct DiagnosticLogRow: View {
    let entry: DiagnosticLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Text("#\(entry.sequence)")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
                Text(entry.level.title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(levelColor)
                Text(entry.category.title)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(VeilTheme.mutedGold)
                Spacer()
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Text(entry.event)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(VeilTheme.text)

            HStack(spacing: 6) {
                if let screen = entry.screen, !screen.isEmpty {
                    Text(screen)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                        .lineLimit(1)
                }
                if !entry.message.isEmpty {
                    Text(entry.message)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: return VeilTheme.tertiaryText
        case .info: return VeilTheme.success
        case .warning: return VeilTheme.gold
        case .error, .critical: return .red
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

private struct DiagnosticLogDetailView: View {
    let entry: DiagnosticLogEntry
    @State private var copied = false

    var body: some View {
        List {
            Section("事件") {
                detail("序列", String(entry.sequence))
                detail("级别", entry.level.title)
                detail("模块", entry.category.title)
                detail("事件", entry.event)
                detail("界面", entry.screen ?? "-")
                detail("会话", entry.sessionID)
                detail("时间", ISO8601DateFormatter().string(from: entry.timestamp))
                detail("Uptime ms", String(entry.uptimeMilliseconds))
            }

            if !entry.message.isEmpty {
                Section("说明") {
                    Text(entry.message)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if !entry.metadata.isEmpty {
                Section("元数据") {
                    ForEach(entry.metadata.keys.sorted(), id: \.self) { key in
                        detail(key, entry.metadata[key] ?? "")
                    }
                }
            }

            Section {
                Button {
                    UIPasteboard.general.string = serialized
                    copied = true
                    RuntimeDiagnosticsBridge.shared.recordSemanticAction("diagnostics.copy_entry", metadata: ["sequence": String(entry.sequence)])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                } label: {
                    Label(copied ? "已复制" : "复制此条日志", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .accessibilityIdentifier("diagnostics.copy_entry")
            }
        }
        .navigationTitle("日志详情")
        .telemetryScreen("owner.telemetry.detail", metadata: ["sequence": String(entry.sequence)])
    }

    @ViewBuilder
    private func detail(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private var serialized: String {
        var lines = [
            "#\(entry.sequence) [\(entry.level.title)] [\(entry.category.title)] \(entry.event)",
            ISO8601DateFormatter().string(from: entry.timestamp),
            "session=\(entry.sessionID)",
            "screen=\(entry.screen ?? "-")",
            "uptime_ms=\(entry.uptimeMilliseconds)"
        ]
        if !entry.message.isEmpty { lines.append(entry.message) }
        for key in entry.metadata.keys.sorted() {
            lines.append("\(key)=\(entry.metadata[key] ?? "")")
        }
        return lines.joined(separator: "\n")
    }
}

struct DiagnosticsExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
