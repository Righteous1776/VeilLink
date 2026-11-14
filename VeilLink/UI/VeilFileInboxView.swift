import SwiftUI
import UniformTypeIdentifiers

/// One reliable, testable entry point for arbitrary Files-provider documents.
/// Saving here does NOT silently inject models, restore backups, or transmit
/// files to peers. Each of those requires its own validated operation.
struct VeilFileInboxView: View {
    @State private var records: [VeilFileInboxRecord] = []
    @State private var showsImporter = false
    @State private var isImporting = false
    @State private var resultMessage: String?
    @State private var pendingRemoval: VeilFileInboxRecord?
    @State private var sharedURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                Button {
                    showsImporter = true
                } label: {
                    HStack {
                        Label("从「文件」导入", systemImage: "square.and.arrow.down")
                        Spacer()
                        if isImporting { ProgressView() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)

                if records.isEmpty {
                    Label("还没有导入的本机文件副本", systemImage: "tray")
                        .font(.subheadline)
                        .foregroundColor(VeilTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(28)
                        .veilCard()
                } else {
                    ForEach(records) { record in
                        recordCard(record)
                    }
                }
                Text("文件保留在本机应用存储中，不会上传网络或自动执行。ZIP、NPZ 等文件可安全存入，但不等于已恢复备份或载入 AI 权重。单文件上限 512 MiB。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("文件收件箱")
        .navigationBarTitleDisplayMode(.inline)
        .task { refresh() }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .failure(let error):
                resultMessage = error.localizedDescription
            case .success(let urls):
                guard !urls.isEmpty else { return }
                isImporting = true
                Task { @MainActor in
                    defer { isImporting = false }
                    var successes = 0
                    var failures: [String] = []
                    for selected in urls {
                        do {
                            let staged = try await VeilImportedFileAccess.materializeInBackground(
                                selected,
                                maximumBytes: Int(VeilFileInbox.maximumFileBytes)
                            )
                            defer { VeilImportedFileAccess.removeStagedCopy(staged) }
                            _ = try await Task.detached(priority: .userInitiated) {
                                try VeilFileInbox.importStaged(staged)
                            }.value
                            successes += 1
                        } catch {
                            failures.append(error.localizedDescription)
                        }
                    }
                    refresh()
                    let result = "已保存 " + String(successes) + " 份文件到本机。"
                    resultMessage = failures.isEmpty
                        ? result
                        : result + " 失败 " + String(failures.count) + " 份：" +
                            failures.prefix(2).joined(separator: "；")
                }
            }
        }
        .alert("文件收件箱", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("好", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
        .confirmationDialog(
            "只删除 VeilLink 本机副本，不影响 Files 中的原文件。",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除本机副本", role: .destructive) {
                guard let record = pendingRemoval else { return }
                do {
                    try VeilFileInbox.remove(record)
                    refresh()
                } catch {
                    resultMessage = error.localizedDescription
                }
                pendingRemoval = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { sharedURL != nil },
            set: { if !$0 { sharedURL = nil } }
        )) {
            if let sharedURL {
                ShareSheet(items: [sharedURL])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("FILES / IMPORT INBOX", systemImage: "folder.badge.plus")
                .font(.headline)
                .foregroundColor(VeilTheme.goldBright)
            Text("先确认系统文件确实读进来了，再独立处理它的用途。每份文件在保存前后都校验字节数和 SHA-256，原文件保持不变。")
                .font(.subheadline)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .veilCard(emphasized: true)
    }

    private func recordCard(_ record: VeilFileInboxRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(record.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(VeilTheme.text)
                .lineLimit(3)
            HStack {
                Text(record.kind.title)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: record.byteCount, countStyle: .file))
            }
            .font(.caption)
            .foregroundColor(VeilTheme.secondaryText)
            Text("SHA-256  " + String(record.sha256.prefix(24)) + "…")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(VeilTheme.mutedGold)
                .textSelection(.enabled)
            HStack(spacing: 14) {
                Button("重新校验") { verify(record) }
                    .buttonStyle(.bordered)
                Button("分享副本") { share(record) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("删除", role: .destructive) {
                    pendingRemoval = record
                }
                .font(.caption)
            }
        }
        .padding(14)
        .veilCard()
    }

    private func refresh() {
        do {
            records = try VeilFileInbox.list()
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    private func verify(_ record: VeilFileInboxRecord) {
        Task {
            do {
                let matched = try await Task.detached(priority: .userInitiated) {
                    try VeilFileInbox.verify(record)
                }.value
                resultMessage = matched
                    ? "文件副本 SHA-256 校验通过。"
                    : "校验失败：副本内容与导入时不同，请重新导入。"
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }

    private func share(_ record: VeilFileInboxRecord) {
        do {
            sharedURL = try VeilFileInbox.fileURL(for: record)
        } catch {
            resultMessage = error.localizedDescription
        }
    }
}
