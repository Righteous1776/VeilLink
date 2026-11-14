import SwiftUI
import UniformTypeIdentifiers

/// Unified Apple Files entry for all local imports. Feature-specific pickers
/// remain available; only recognized, validated content is dispatched.
struct VeilFileInboxView: View {
    @ObservedObject var model: AppModel

    @State private var records: [VeilFileInboxRecord] = []
    @State private var routes: [UUID: VeilUnifiedImportRoute] = [:]
    @State private var showsImporter = false
    @State private var isImporting = false
    @State private var resultMessage: String?
    @State private var pendingRemoval: VeilFileInboxRecord?
    @State private var pendingBackup: VeilFileInboxRecord?
    @State private var pendingHTML: VeilFileInboxRecord?
    @State private var pendingPreview: VeilFileInboxRecord?
    @State private var pendingTraining: VeilFileInboxRecord?
    @State private var pendingTrainingGame: MiniGameKind?
    @State private var sharedURL: URL?
    @State private var refreshToken = UUID()

    private var trainingAuthorized: Bool {
        model.ownerMode.isAuthorized(for: .developerTraining)
            && model.appLock.isEnabled
            && !model.appLock.isLocked
            && model.developerLearningGate.canImportTraining()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                Button {
                    showsImporter = true
                } label: {
                    HStack {
                        Label("从苹果「文件」选择", systemImage: "square.and.arrow.down")
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
                Text("统一入口会识别 VeilLink 备份、HTML 和专用棋类训练包。恢复备份和替换训练档案必须确认；普通 ZIP、NPZ、PDF 等只保存在本机收件箱，不会被误当成模型或备份自动执行。单文件上限 512 MiB。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("统一文件导入")
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
                    var successful: [(VeilFileInboxRecord, VeilUnifiedImportRoute)] = []
                    var failures: [String] = []
                    for selected in urls {
                        do {
                            // The provider grant stays active only in the staging call.
                            let staged = try await VeilImportedFileAccess.materializeInBackground(
                                selected, maximumBytes: Int(VeilFileInbox.maximumFileBytes)
                            )
                            defer { VeilImportedFileAccess.removeStagedCopy(staged) }
                            let result = try await Task.detached(priority: .userInitiated) {
                                let stored = try VeilFileInbox.importStaged(staged)
                                let localURL = try VeilFileInbox.fileURL(for: stored)
                                let route = VeilUnifiedImportRouter.resolve(stored, at: localURL)
                                return (stored, route)
                            }.value
                            successful.append(result)
                            routes[result.0.id] = result.1
                        } catch {
                            failures.append(selected.lastPathComponent + "：" + error.localizedDescription)
                        }
                    }
                    refresh()
                    let saved = "已保存 " + String(successful.count) + " 份文件。"
                    resultMessage = failures.isEmpty ? saved :
                        saved + " 失败 " + String(failures.count) + " 份：" +
                        failures.prefix(2).joined(separator: "；")
                    // For a single file, open its matching destination immediately.
                    // Multiple files remain categorized in this page for deliberate review.
                    if successful.count == 1, failures.isEmpty {
                        resultMessage = nil
                        dispatch(successful[0].0, route: successful[0].1)
                    }
                }
            }
        }
        .alert("文件导入结果", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("好", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
        .confirmationDialog(
            "仅删除 VeilLink 本机副本，不影响「文件」App 中的原文件。",
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
        .confirmationDialog(
            "导入训练档案将替换对应棋种的当前学习数据；不会修改另一棋种。请先从原训练室导出备份。",
            isPresented: Binding(
                get: { pendingTraining != nil && pendingTrainingGame != nil },
                set: { if !$0 { pendingTraining = nil; pendingTrainingGame = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("确认导入训练档案", role: .destructive) {
                if let record = pendingTraining, let game = pendingTrainingGame {
                    applyTraining(record, game: game)
                }
                pendingTraining = nil
                pendingTrainingGame = nil
            }
            Button("取消", role: .cancel) {
                pendingTraining = nil
                pendingTrainingGame = nil
            }
        }
        .sheet(item: $pendingBackup) { record in
            BackupPasswordSheet(title: "恢复已识别的 VeilLink 备份", actionTitle: "验证并恢复") { password in
                restoreBackup(record, password: password)
            }
        }
        .sheet(item: $pendingHTML) { record in
            NavigationView {
                VeilOfflineHTMLReaderView(
                    initialFileURL: try? VeilFileInbox.fileURL(for: record)
                )
            }
        }
        .sheet(item: $pendingPreview) { record in
            if let file = try? VeilFileInbox.fileURL(for: record) {
                VeilFileInboxPreview(url: file)
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
            Label("UNIFIED FILES IMPORT", systemImage: "folder.badge.plus")
                .font(.headline)
                .foregroundColor(VeilTheme.goldBright)
            Text("一个入口，自动识别文件用途。先将文件安全保存到本机，再分发至支持的功能。原有导入按钮全部保留。")
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
            if let route = routes[record.id] {
                Label(route.destinationTitle, systemImage: routeSymbol(route))
                    .font(.caption)
                    .foregroundColor(VeilTheme.goldBright)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("SHA-256  " + String(record.sha256.prefix(24)) + "…")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(VeilTheme.mutedGold)
                .textSelection(.enabled)
            HStack(spacing: 14) {
                if let route = routes[record.id] {
                    switch route {
                    case .backup:
                        Button("恢复到 VeilLink") { dispatch(record, route: route) }
                            .buttonStyle(.bordered)
                    case .html:
                        Button("打开阅读器") { dispatch(record, route: route) }
                            .buttonStyle(.bordered)
                    case .boardLearning:
                        Button("导入训练档案") { dispatch(record, route: route) }
                            .buttonStyle(.bordered)
                    case .image, .preview:
                        Button("打开预览") { dispatch(record, route: route) }
                            .buttonStyle(.bordered)
                    case .retained:
                        EmptyView()
                    }
                }
                Button("校验") { verify(record) }
                    .buttonStyle(.bordered)
                Button("分享") { share(record) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("删除", role: .destructive) { pendingRemoval = record }
                    .font(.caption)
            }
        }
        .padding(14)
        .veilCard()
    }

    private func routeSymbol(_ route: VeilUnifiedImportRoute) -> String {
        switch route {
        case .backup: return "externaldrive.badge.checkmark"
        case .html: return "doc.richtext"
        case .boardLearning: return "checkerboard.rectangle"
        case .image: return "photo"
        case .preview: return "doc.text.magnifyingglass"
        case .retained: return "tray.full"
        }
    }

    private func refresh() {
        do {
            let all = try VeilFileInbox.list()
            records = all
            let token = UUID()
            refreshToken = token
            Task {
                let resolved = await Task.detached(priority: .utility) {
                    var resolved: [UUID: VeilUnifiedImportRoute] = [:]
                    for record in all {
                        if let url = try? VeilFileInbox.fileURL(for: record) {
                            resolved[record.id] = VeilUnifiedImportRouter.resolve(record, at: url)
                        }
                    }
                    return resolved
                }.value
                if refreshToken == token { routes = resolved }
            }
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    private func dispatch(_ record: VeilFileInboxRecord, route: VeilUnifiedImportRoute) {
        switch route {
        case .backup:
            pendingBackup = record
        case .html:
            pendingHTML = record
        case .boardLearning(let game):
            guard trainingAuthorized else {
                resultMessage = "已保存训练文件，但写入训练库需要先在上帝模式的开发者学习室完成授权，并解锁应用。原训练入口仍可使用。"
                return
            }
            pendingTrainingGame = game
            pendingTraining = record
        case .image, .preview:
            openPreview(record)
        case .retained(let reason):
            resultMessage = reason
        }
    }

    private func openPreview(_ record: VeilFileInboxRecord) {
        Task { @MainActor in
            do {
                let allowed = try await Task.detached(priority: .userInitiated) {
                    try VeilFileInbox.verify(record)
                }.value
                guard allowed else { throw VeilFileInboxError.corruptedCopy }
                pendingPreview = record
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }

    private func restoreBackup(_ record: VeilFileInboxRecord, password: String) {
        Task { @MainActor in
            do {
                let localURL = try await Task.detached(priority: .userInitiated) { () throws -> URL in
                    guard try VeilFileInbox.verify(record) else {
                        throw VeilFileInboxError.corruptedCopy
                    }
                    let url = try VeilFileInbox.fileURL(for: record)
                    guard VeilBackupArchiveInspector.inspect(url, verifyAllCRC: false).permittedToRestore else {
                        throw VeilFileInboxError.invalidRecord
                    }
                    return url
                }.value
                model.restoreBackup(url: localURL, password: password)
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }

    private func applyTraining(_ record: VeilFileInboxRecord, game: MiniGameKind) {
        guard trainingAuthorized else {
            resultMessage = "开发者训练授权已失效；训练库没有被修改。"
            return
        }
        Task { @MainActor in
            do {
                let url = try await Task.detached(priority: .userInitiated) { () throws -> URL in
                    guard try VeilFileInbox.verify(record) else {
                        throw VeilFileInboxError.corruptedCopy
                    }
                    let file = try VeilFileInbox.fileURL(for: record)
                    guard VeilUnifiedImportRouter.boardLearningGame(at: file) == game else {
                        throw VeilFileInboxError.invalidRecord
                    }
                    return file
                }.value
                guard trainingAuthorized else {
                    resultMessage = "开发者训练授权已失效；训练库没有被修改。"
                    return
                }
                let report = try AdaptiveBoardLearningStore.store(for: game).importPackage(from: url)
                resultMessage = "已写入" + game.title + "训练库：" +
                    String(report.completedGames) + " 局，" +
                    String(report.rememberedPositions) + " 个局面。"
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }

    private func verify(_ record: VeilFileInboxRecord) {
        Task {
            do {
                let matched = try await Task.detached(priority: .userInitiated) {
                    try VeilFileInbox.verify(record)
                }.value
                resultMessage = matched
                    ? "本机副本 SHA-256 校验通过。"
                    : "校验失败：文件内容已变化，请重新导入。"
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }

    private func share(_ record: VeilFileInboxRecord) {
        Task { @MainActor in
            do {
                let url = try await Task.detached(priority: .userInitiated) { () throws -> URL in
                    guard try VeilFileInbox.verify(record) else {
                        throw VeilFileInboxError.corruptedCopy
                    }
                    return try VeilFileInbox.fileURL(for: record)
                }.value
                sharedURL = url
            } catch {
                resultMessage = error.localizedDescription
            }
        }
    }
}
