import SwiftUI
import UniformTypeIdentifiers

/// Standalone, deliberately separate from irreversible restore UI.
struct VeilBackupPreflightView: View {
    @State private var presentingPicker = false
    @State private var deepCRC = false
    @State private var result: VeilBackupPreflightPolicy.Report?
    @State private var working = false
    @State private var generation = UUID()
    @State private var importError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("备份 ZIP 安全体检")
                    .font(.title3.bold())
                Text("选择备份文件后，只分析 ZIP 目录、清单及可选的 CRC 校验。不要求密码，不解密，不提取至磁盘，不修改现有聊天和密钥。")
                    .font(.footnote).foregroundColor(.secondary)
                Toggle("完整校验全部文件 CRC（可能较慢）", isOn: $deepCRC)
                    .disabled(working)
                Button {
                    presentingPicker = true
                } label: {
                    Label("从文件选择备份 ZIP", systemImage: "doc.zipper")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(working)
                if working { ProgressView("只读检查中…") }
                if let importError {
                    Label(importError, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                if let result {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(result.safetyLabel)
                            .font(.headline)
                            .foregroundColor(result.permittedToRestore ? .green : .red)
                        Text("条目 \(result.entries) · 附件 \(result.attachments)")
                        Text("压缩归档 \(ByteCountFormatter.string(fromByteCount: Int64(result.zipBytes), countStyle: .file))")
                        Text("预计展开 \(ByteCountFormatter.string(fromByteCount: Int64(result.expandedBytes), countStyle: .file))")
                        if let version = result.version { Text("备份版本 v\(version)") }
                        if let created = result.createdAt {
                            Text("备份时间 \(created.formatted(date: .abbreviated, time: .shortened))")
                        }
                        if !result.problems.isEmpty {
                            ForEach(result.problems, id: \.rawValue) { problem in
                                Label(problem.explanation, systemImage: "exclamationmark.triangle")
                                    .font(.footnote).foregroundColor(.red)
                            }
                        }
                        Text("重要：CRC 和结构检查通过并不证明密码、数据库、存储密钥或身份恢复一定成功。")
                            .font(.caption).foregroundColor(.secondary)
                        Button("清除检查结果") {
                            generation = UUID()
                            self.result = nil
                        }.buttonStyle(.bordered)
                    }
                    .textSelection(.enabled)
                }
            }
            .padding(16)
        }
        .navigationTitle("ZIP 备份安全体检")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $presentingPicker,
                      allowedContentTypes: [.item], allowsMultipleSelection: false) { pick in
            guard case .success(let urls) = pick, let selectedURL = urls.first else { return }
            importError = nil
            let token = UUID()
            generation = token
            working = true
            result = nil
            let runDeep = deepCRC
            Task {
                do {
                    let file = try await VeilImportedFileAccess.materializeInBackground(
                        selectedURL,
                        acceptedExtensions: ["zip"]
                    )
                    defer { VeilImportedFileAccess.removeStagedCopy(file) }
                    let inspected = await Task.detached(priority: .userInitiated) {
                        VeilBackupArchiveInspector.inspect(file, verifyAllCRC: runDeep)
                    }.value
                    guard generation == token else { return }
                    result = inspected
                    working = false
                } catch {
                    guard generation == token else { return }
                    importError = error.localizedDescription
                    working = false
                }
            }
        }
        .onDisappear {
            // Outstanding work is read-only; discard its results if the page closes.
            generation = UUID()
            result = nil
            working = false
        }
    }
}
