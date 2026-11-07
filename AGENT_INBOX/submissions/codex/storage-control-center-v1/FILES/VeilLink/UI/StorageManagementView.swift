import SwiftUI

struct StorageManagementView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var diagnostics = DiagnosticLogStore.shared
    private let maintenance: VeilStorageMaintenance

    @State private var snapshot: VeilStorageSnapshot?
    @State private var selected = Set<VeilStorageCategory>()
    @State private var isWorking = false
    @State private var showsConfirmation = false
    @State private var message: String?

    init(model: AppModel, maintenance: VeilStorageMaintenance = VeilStorageMaintenance()) {
        self.model = model
        self.maintenance = maintenance
    }

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 16) {
                summaryCard
                categoriesCard
                if let snapshot, !snapshot.largeItems.isEmpty { largeItemsCard(snapshot.largeItems) }
                protectionCard
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("存储管理")
        .task { await refresh() }
        .refreshable { await refresh() }
        .alert("确认清理所选内容？", isPresented: $showsConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) { Task { await clean() } }
        } message: {
            Text(confirmationText)
        }
        .alert("存储管理", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("空间雷达", systemImage: "internaldrive")
                    .font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
                Spacer()
                if isWorking { ProgressView().tint(VeilTheme.gold) }
            }
            Text(snapshot.map { bytes($0.reclaimableBytes) } ?? "正在扫描…")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("可检查的缓存、下载与导出占用。聊天和密钥不计入可清理空间。")
                .font(.caption).foregroundColor(VeilTheme.secondaryText)
            HStack {
                Button("选择建议项") {
                    selected = Set(VeilStorageCategory.allCases.filter(\.isRecommended))
                }
                .buttonStyle(VeilPressStyle())
                Spacer()
                Button("重新扫描") { Task { await refresh() } }
                    .buttonStyle(VeilPressStyle())
            }
        }
        .veilCard(emphasized: true)
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("分类清理").font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright).padding(.bottom, 8)
            ForEach(displayCategories) { item in
                Button {
                    guard item.category.isDeletable else { return }
                    if selected.contains(item.category) { selected.remove(item.category) }
                    else { selected.insert(item.category) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected.contains(item.category) ? "checkmark.circle.fill" : icon(for: item.category))
                            .foregroundColor(item.category.isDeletable ? VeilTheme.gold : VeilTheme.success)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.category.title).fontWeight(.semibold).foregroundColor(VeilTheme.text)
                            Text(item.detail).font(.caption2).foregroundColor(VeilTheme.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(bytes(item.byteCount)).font(.system(.caption, design: .monospaced).weight(.semibold))
                            Text("\(item.itemCount) 项").font(.caption2).foregroundColor(VeilTheme.tertiaryText)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(VeilPressStyle())
                .disabled(!item.category.isDeletable || isWorking)
                if item.id != displayCategories.last?.id { Divider().background(VeilTheme.hairline) }
            }
            Button(role: .destructive) { showsConfirmation = true } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清理所选内容")
                    Spacer()
                    Text(bytes(selectedBytes)).font(.system(.caption, design: .monospaced))
                }
            }
            .buttonStyle(VeilPressStyle())
            .disabled(selected.isEmpty || isWorking)
            .padding(.top, 12)
        }
        .veilCard()
    }

    private func largeItemsCard(_ items: [VeilStorageLargeItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("大文件雷达", systemImage: "scope")
                .font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName).lineLimit(1)
                        Text(item.category.title).font(.caption2).foregroundColor(VeilTheme.secondaryText)
                    }
                    Spacer()
                    Text(bytes(item.byteCount)).font(.system(.caption, design: .monospaced))
                }
            }
        }
        .veilCard()
    }

    private var protectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("删除边界", systemImage: "lock.shield.fill")
                .font(VeilType.cardTitle).foregroundColor(VeilTheme.success)
            Text("数据库、聊天正文、收发附件、身份私钥、会话密钥和正在传输的数据永不进入清理候选。删除备份与下载必须手动勾选；建议清理不会选择它们。")
                .font(.caption).foregroundColor(VeilTheme.secondaryText)
        }
        .veilCard()
    }

    private var displayCategories: [VeilStorageCategorySnapshot] {
        var values = snapshot?.categories ?? []
        if let index = values.firstIndex(where: { $0.category == .diagnostics }) {
            values[index] = VeilStorageCategorySnapshot(
                category: .diagnostics,
                byteCount: Int64(diagnostics.diskUsageBytes),
                itemCount: diagnostics.exportedFileCount,
                detail: values[index].detail
            )
        }
        return values
    }

    private var selectedBytes: Int64 {
        displayCategories.filter { selected.contains($0.category) }.reduce(0) { $0 + $1.byteCount }
    }

    private var confirmationText: String {
        let names = displayCategories.filter { selected.contains($0.category) }.map { $0.category.title }
        let warning = selected.contains(.backupExports) || selected.contains(.downloads)
            ? "备份或下载删除后不能在 App 内撤销。"
            : "这些内容均可重新生成。"
        return "将清理：\(names.joined(separator: "、"))，预计 \(bytes(selectedBytes))。\(warning)"
    }

    @MainActor
    private func refresh() async {
        guard !isWorking else { return }
        isWorking = true
        diagnostics.refreshFromDisk()
        snapshot = await maintenance.scan()
        isWorking = false
    }

    @MainActor
    private func clean() async {
        guard !isWorking else { return }
        isWorking = true
        let requested = selected
        if requested.contains(.runtimeCache) { model.clearUserRequestedCaches() }
        if requested.contains(.diagnostics) { diagnostics.clear() }
        let result = await maintenance.clean(requested)
        selected.removeAll()
        snapshot = await maintenance.scan()
        isWorking = false
        let removed = bytes(result.removedBytes)
        message = result.failures.isEmpty
            ? "已删除 \(result.removedItems) 项磁盘内容（\(removed)），并完成所选缓存清理。"
            : "已删除 \(result.removedItems) 项；另有 \(result.failures.count) 项失败。请重新扫描后重试。"
    }

    private func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private func icon(for category: VeilStorageCategory) -> String {
        switch category {
        case .runtimeCache: return "bolt.horizontal.circle"
        case .diagnostics: return "waveform.path.ecg"
        case .staleTemporaryExports: return "clock.arrow.circlepath"
        case .downloads: return "arrow.down.circle"
        case .backupExports: return "archivebox"
        case .protectedData: return "lock.shield.fill"
        }
    }
}
