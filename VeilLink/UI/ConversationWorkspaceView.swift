import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ConversationWorkspaceView: View {
    let conversationTitle: String
    let snapshot: ConversationWorkspaceSnapshot
    let onJump: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: ConversationWorkspaceKind?
    @State private var query = ""

    private var items: [ConversationWorkspaceItem] {
        ConversationWorkspaceEngine.filteredItems(in: snapshot, kind: selectedKind, query: query)
    }

    var body: some View {
        NavigationView {
            VeilStableScrollView {
                VStack(spacing: 14) {
                    overviewCard
                    filterBar
                    resultsCard
                    privacyCard
                }
            }
            .background(VeilAmbientBackground())
            .navigationTitle("会话工作台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(conversationTitle)
                .font(.system(.title3, design: .rounded).weight(.semibold))
            HStack(spacing: 8) {
                metric("消息", snapshot.messageCount)
                metric("行动", snapshot.count(for: .action))
                metric("问题", snapshot.count(for: .question))
                metric("资料", snapshot.count(for: .link) + snapshot.attachmentCount)
            }
            Text("活跃 \(snapshot.activeDayCount) 天 · 发出 \(snapshot.outgoingCount) · 收到 \(snapshot.incomingCount)")
                .font(.caption).foregroundColor(VeilTheme.secondaryText)
        }
        .veilCard(emphasized: true)
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(VeilTheme.secondaryText)
                TextField("搜索工作台", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }
            .padding(10)
            .background(VeilTheme.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterButton(title: "全部", icon: "square.grid.2x2", kind: nil)
                    ForEach(ConversationWorkspaceKind.allCases, id: \.self) { kind in
                        filterButton(title: kind.title, icon: kind.systemImage, kind: kind)
                    }
                }
            }
        }
        .veilCard()
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(selectedKind?.title ?? "全部线索").font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
                Spacer()
                Text("\(items.count) 项").font(.caption.monospacedDigit()).foregroundColor(VeilTheme.secondaryText)
            }
            .padding(.bottom, 8)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.title2).foregroundColor(VeilTheme.tertiaryText)
                    Text("这个分类暂时没有内容").font(.subheadline).foregroundColor(VeilTheme.secondaryText)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                ForEach(items) { item in
                    Button {
                        onJump(item.messageID)
                        dismiss()
                    } label: {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: item.kind.systemImage)
                                .foregroundColor(VeilTheme.gold).frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold)).foregroundColor(VeilTheme.text).lineLimit(1)
                                Text(item.preview)
                                    .font(.caption).foregroundColor(VeilTheme.secondaryText).lineLimit(3)
                                Text(item.sentAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2.monospacedDigit()).foregroundColor(VeilTheme.tertiaryText)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.left").font(.caption.weight(.bold)).foregroundColor(VeilTheme.tertiaryText)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(VeilPressStyle())
                    .contextMenu {
                        if let value = item.value, item.kind == .link {
                            Button {
                                UIPasteboard.general.setItems(
                                    [[UTType.utf8PlainText.identifier: value]],
                                    options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(5 * 60)]
                                )
                            } label: { Label("复制链接（5 分钟）", systemImage: "doc.on.doc") }
                        }
                    }
                    if item.id != items.last?.id { Divider().background(VeilTheme.hairline) }
                }
            }
        }
        .veilCard()
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill").foregroundColor(VeilTheme.success)
            Text("所有分类均在本机内存中即时完成，不上传正文、不建立新数据库、不改变消息协议；关闭页面后不保留分析结果。")
                .font(.caption).foregroundColor(VeilTheme.secondaryText)
        }
        .veilCard()
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(value)").font(.headline.monospacedDigit()).foregroundColor(VeilTheme.goldBright)
            Text(title).font(.caption2).foregroundColor(VeilTheme.secondaryText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(VeilTheme.subtleFill).clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func filterButton(title: String, icon: String, kind: ConversationWorkspaceKind?) -> some View {
        let selected = selectedKind == kind
        return Button {
            selectedKind = kind
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .foregroundColor(selected ? Color.black.opacity(0.88) : VeilTheme.secondaryText)
                .background(selected ? AnyShapeStyle(VeilTheme.goldGradient) : AnyShapeStyle(VeilTheme.subtleFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
