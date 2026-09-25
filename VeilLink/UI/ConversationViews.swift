import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct ConversationListView: View {
    @ObservedObject var model: AppModel
    let usesNavigationLinks: Bool

    var body: some View {
        Group {
            if model.conversations.isEmpty {
                VStack(spacing: 15) {
                    Spacer()
                    VeilIdentityGlyph(seed: "VeilLink/NoConversation", size: 76, active: false)
                    Text("NO ACTIVE LINK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("还没有对话")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                    HStack(spacing: 8) {
                        Text("LOCAL")
                        VeilLinkTrace(active: false, width: 56)
                        Text("PEER")
                    }
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
                    Text("前往“附近”发现设备并核对六码")
                        .font(.subheadline)
                        .foregroundColor(VeilTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                List(model.conversations) { conversation in
                    if usesNavigationLinks {
                        NavigationLink(destination: ChatView(model: model, conversation: conversation)) {
                            ConversationRow(conversation: conversation, isSelected: false)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                _ = model.setConversationPinned(conversation.id, pinned: !conversation.isPinned)
                            } label: {
                                Label(conversation.isPinned ? "取消置顶" : "置顶", systemImage: conversation.isPinned ? "pin.slash.fill" : "pin.fill")
                            }
                            .tint(VeilTheme.gold)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                if conversation.unreadCount > 0 {
                                    _ = model.markConversationRead(conversation.id)
                                } else {
                                    _ = model.markConversationUnread(conversation.id)
                                }
                            } label: {
                                Label(conversation.unreadCount > 0 ? "标为已读" : "标为未读", systemImage: conversation.unreadCount > 0 ? "envelope.open.fill" : "envelope.badge.fill")
                            }
                            .tint(VeilTheme.panelSoft)
                        }
                        .contextMenu {
                            Button {
                                _ = model.setConversationPinned(conversation.id, pinned: !conversation.isPinned)
                            } label: {
                                Label(conversation.isPinned ? "取消置顶" : "置顶", systemImage: conversation.isPinned ? "pin.slash" : "pin")
                            }
                            Button {
                                if conversation.unreadCount > 0 {
                                    _ = model.markConversationRead(conversation.id)
                                } else {
                                    _ = model.markConversationUnread(conversation.id)
                                }
                            } label: {
                                Label(conversation.unreadCount > 0 ? "标为已读" : "标为未读", systemImage: conversation.unreadCount > 0 ? "envelope.open" : "envelope.badge")
                            }
                        }
                    } else {
                        Button {
                            model.haptics.selection()
                            model.selectedConversation = conversation
                            _ = model.markConversationRead(conversation.id)
                        } label: {
                            ConversationRow(
                                conversation: conversation,
                                isSelected: model.selectedConversation?.id == conversation.id
                            )
                        }
                        .buttonStyle(VeilPressStyle())
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                _ = model.setConversationPinned(conversation.id, pinned: !conversation.isPinned)
                            } label: {
                                Label(conversation.isPinned ? "取消置顶" : "置顶", systemImage: conversation.isPinned ? "pin.slash.fill" : "pin.fill")
                            }
                            .tint(VeilTheme.gold)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                if conversation.unreadCount > 0 {
                                    _ = model.markConversationRead(conversation.id)
                                } else {
                                    _ = model.markConversationUnread(conversation.id)
                                }
                            } label: {
                                Label(conversation.unreadCount > 0 ? "标为已读" : "标为未读", systemImage: conversation.unreadCount > 0 ? "envelope.open.fill" : "envelope.badge.fill")
                            }
                            .tint(VeilTheme.panelSoft)
                        }
                        .contextMenu {
                            Button {
                                _ = model.setConversationPinned(conversation.id, pinned: !conversation.isPinned)
                            } label: {
                                Label(conversation.isPinned ? "取消置顶" : "置顶", systemImage: conversation.isPinned ? "pin.slash" : "pin")
                            }
                            Button {
                                if conversation.unreadCount > 0 {
                                    _ = model.markConversationRead(conversation.id)
                                } else {
                                    _ = model.markConversationUnread(conversation.id)
                                }
                            } label: {
                                Label(conversation.unreadCount > 0 ? "标为已读" : "标为未读", systemImage: conversation.unreadCount > 0 ? "envelope.open" : "envelope.badge")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("对话")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: VeilToolCenterView(model: model)) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(VeilPressStyle())
                .accessibilityLabel("打开工具中心")
            }
        }
        .background(VeilAmbientBackground())
    }
}

private struct ConversationRow: View {
    let conversation: ConversationSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 13) {
            VeilIdentityGlyph(seed: conversation.peerIdentityID, size: 46, active: isSelected)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(conversation.title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(VeilTheme.text)
                        .lineLimit(1)
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(VeilTheme.mutedGold)
                            .accessibilityLabel("已置顶")
                    }
                    Spacer(minLength: 6)
                    if conversation.unreadCount > 0 {
                        Text(conversation.unreadCount > 99 ? "99+" : "\(conversation.unreadCount)")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.88))
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 18)
                            .background(VeilTheme.goldBright)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(conversation.unreadCount) 条未读")
                    }
                    Text(conversation.updatedAt, style: .time)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilTheme.tertiaryText)
                }

                HStack(spacing: 7) {
                    Text("E2EE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(VeilTheme.mutedGold)
                    VeilLinkTrace(active: isSelected, width: 28)
                    Text(conversation.lastMessage.isEmpty ? "安全会话已建立" : conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            VeilPanelShape(cut: 15, radius: 7)
                .fill(isSelected ? VeilTheme.gold.opacity(0.090) : VeilTheme.elevated.opacity(0.74))
        )
        .overlay(
            VeilPanelShape(cut: 15, radius: 7)
                .stroke(isSelected ? VeilTheme.gold.opacity(0.30) : VeilTheme.hairline, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(isSelected ? VeilTheme.goldBright.opacity(0.72) : VeilTheme.hairline)
                .frame(width: isSelected ? 34 : 14, height: 1)
                .padding(.leading, 11)
        }
        .contentShape(VeilPanelShape(cut: 15, radius: 7))
        .padding(.vertical, 3)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

struct ChatView: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var composerMode: VeilChatComposerMode = .text
    @StateObject private var voiceRecorder = VeilVoiceMessageRecorder()
    @State private var showsPhotoPicker = false
    @State private var showsImageFileImporter = false
    @State private var isPreparingImage = false
    @State private var mediaStatus: String?
    @State private var showsContactDetails = false
    @State private var messagePendingDeletion: ChatMessage?
    @State private var showsClearConversationConfirmation = false
    @State private var transferPendingCancellation: ChatMessage?
    @State private var replyingTo: ChatMessage?
    @State private var showsSearchBar = false
    @State private var searchQuery = ""
    @State private var messageWindowLimit = VeilDevicePerformance.current.messageWindowInitial
    @State private var hasOlderMessages = false
    @State private var messageReloadGeneration = 0
    @State private var isReloadingMessages = false
    @State private var loadedFullHistoryForSearch = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesReducedInteractionMotion: Bool {
        reduceMotion || VeilDevicePerformance.current.transferVisualComplexity != .full
    }

    private var visibleMessages: [ChatMessage] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard showsSearchBar, !query.isEmpty else { return messages }
        return messages.filter { ConversationSearch.matches($0, query: query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsSearchBar {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(VeilTheme.secondaryText)
                    TextField("搜索本地聊天记录", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if !searchQuery.isEmpty {
                        Text("\(visibleMessages.count) 条")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    Button {
                        searchQuery = ""
                        loadedFullHistoryForSearch = false
                        if usesReducedInteractionMotion {
                            showsSearchBar = false
                        } else {
                            withAnimation(.easeIn(duration: 0.16)) { showsSearchBar = false }
                        }
                        reload()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭搜索")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .veilGlass(cornerRadius: 15)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if hasOlderMessages && !showsSearchBar {
                            Button(action: loadOlderMessages) {
                                HStack(spacing: 7) {
                                    if isReloadingMessages { ProgressView().controlSize(.small) }
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("加载更早消息")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(VeilTheme.mutedGold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.035))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isReloadingMessages)
                        }
                        ForEach(visibleMessages) { message in
                            MessageBubble(
                                message: message,
                                database: model.database,
                                onRetry: message.isOutgoing && message.deliveryState == .failed ? { retry(message) } : nil,
                                onPause: canPauseImage(message) ? { pauseImage(message) } : nil,
                                onResume: canResumeImage(message) ? { resumeImage(message) } : nil,
                                onCancel: canCancelImage(message) ? { transferPendingCancellation = message } : nil
                            )
                            .contextMenu {
                                if message.attachment == nil {
                                    Button {
                                        UIPasteboard.general.string = ReplyTextCodec.decode(message.body)?.reply ?? message.body
                                        model.haptics.selection()
                                    } label: {
                                        Label("复制", systemImage: "doc.on.doc")
                                    }
                                }
                                Button {
                                    model.haptics.selection()
                                    if usesReducedInteractionMotion {
                                        replyingTo = message
                                    } else {
                                        withAnimation(.easeOut(duration: 0.18)) { replyingTo = message }
                                    }
                                } label: {
                                    Label("引用回复", systemImage: "arrowshape.turn.up.left")
                                }
                                Button(role: .destructive) { messagePendingDeletion = message } label: {
                                    Label("本地删除", systemImage: "trash")
                                }
                            }
                            .transition(usesReducedInteractionMotion ? .opacity : .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.985)),
                                removal: .opacity
                            ))
                            .id(message.id)
                        }
                        if showsSearchBar, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, visibleMessages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(VeilTheme.secondaryText)
                                Text("没有找到匹配消息")
                                    .font(.subheadline)
                                    .foregroundColor(VeilTheme.secondaryText)
                            }
                            .padding(.vertical, 36)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .animation(usesReducedInteractionMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: messages.count)
                }
                .onChange(of: messages.last?.id) { _ in
                    if !showsSearchBar, let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            VStack(spacing: 0) {
                if let mediaStatus {
                    HStack(spacing: 8) {
                        if isPreparingImage { ProgressView().controlSize(.small) }
                        Image(systemName: isPreparingImage ? "wand.and.stars" : "checkmark.circle.fill")
                            .foregroundColor(VeilTheme.gold)
                        Text(mediaStatus)
                            .font(.caption)
                            .foregroundColor(VeilTheme.secondaryText)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let replyingTo {
                    HStack(spacing: 9) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(VeilTheme.gold)
                            .frame(width: 3, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("引用回复")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(VeilTheme.gold)
                            Text(ReplyTextCodec.quoteSource(for: replyingTo))
                                .font(.caption)
                                .foregroundColor(VeilTheme.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Button {
                            if usesReducedInteractionMotion {
                                self.replyingTo = nil
                            } else {
                                withAnimation(.easeIn(duration: 0.16)) { self.replyingTo = nil }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("取消引用")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(VeilTheme.elevated.opacity(0.92))
                    .clipShape(VeilPanelShape(cut: 10, radius: 6))
                    .overlay(VeilPanelShape(cut: 10, radius: 6).stroke(VeilTheme.gold.opacity(0.18), lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.top, 7)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                HStack(alignment: .bottom, spacing: 9) {
                    if isPreparingImage {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Menu {
                            Button {
                                showsPhotoPicker = true
                            } label: {
                                Label("照片图库", systemImage: "photo.on.rectangle")
                            }
                            Button {
                                showsImageFileImporter = true
                            } label: {
                                Label("从“文件”导入", systemImage: "doc.badge.plus")
                            }
                        } label: {
                            VeilIconDisc(systemName: "plus", size: 36, highlighted: true)
                                .contentShape(Circle())
                        }
                        .accessibilityLabel("添加图片")
                        .accessibilityHint("从照片图库或文件中选择图片")
                    }
                    Button {
                        composerMode = composerMode == .text ? .voice : .text
                        if composerMode == .text { voiceRecorder.cancel() }
                        model.haptics.selection()
                    } label: {
                        VeilIconDisc(systemName: composerMode == .text ? "mic.fill" : "keyboard", size: 36, highlighted: composerMode == .voice)
                    }
                    .buttonStyle(VeilPressStyle())
                    .accessibilityLabel(composerMode == .text ? "切换到语音" : "切换到文字")
                    if composerMode == .voice {
                        VeilHoldToTalkComposer(recorder: voiceRecorder) { recording in
                            sendVoice(recording)
                        }
                    } else {
                        TextField("加密消息", text: $draft)
                            .textFieldStyle(VeilTextFieldStyle())
                        Button(action: send) {
                            ZStack {
                                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Circle().fill(Color.white.opacity(0.05)) }
                                else { Circle().fill(VeilTheme.goldGradient) }
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? VeilTheme.tertiaryText : Color.black.opacity(0.88))
                            }
                            .frame(width: 36, height: 36)
                            .shadow(color: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .clear : VeilTheme.gold.opacity(0.22), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(VeilPressStyle())
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(VeilTheme.elevated.opacity(0.95))
            .overlay(alignment: .top) {
                HStack(spacing: 7) {
                    Rectangle().fill(Color.clear).frame(maxWidth: .infinity, maxHeight: 1)
                    VeilLinkTrace(active: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, width: 72)
                    Rectangle().fill(Color.clear).frame(maxWidth: .infinity, maxHeight: 1)
                }
                .offset(y: -1)
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VeilChatIdentityTitle(
                    title: model.conversations.first(where: { $0.id == conversation.id })?.title ?? conversation.title,
                    peerIdentityID: conversation.peerIdentityID
                )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        if usesReducedInteractionMotion {
                            showsSearchBar = true
                        } else {
                            withAnimation(.easeOut(duration: 0.18)) { showsSearchBar = true }
                        }
                    } label: {
                        Label("搜索聊天", systemImage: "magnifyingglass")
                    }
                    Button { showsContactDetails = true } label: {
                        Label("联系人信息", systemImage: "person.crop.circle")
                    }
                    Button("取消信任", role: .destructive) { model.setTrust(for: conversation.peerIdentityID, blocked: false) }
                    Button("拉黑身份", role: .destructive) { model.setTrust(for: conversation.peerIdentityID, blocked: true) }
                    Divider()
                    Button(role: .destructive) { showsClearConversationConfirmation = true } label: {
                        Label("清空本地聊天记录", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(VeilTheme.gold)
                }
            }
        }
        .onAppear {
            reload()
            model.setConversationVisible(conversation.id, visible: true)
        }
        .onDisappear {
            model.setConversationVisible(conversation.id, visible: false)
        }
        .onChange(of: model.messagesRevision) { _ in reload(loadAll: showsSearchBar && loadedFullHistoryForSearch) }
        .onChange(of: searchQuery) { value in
            let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if showsSearchBar, !query.isEmpty, !loadedFullHistoryForSearch {
                loadedFullHistoryForSearch = true
                reload(loadAll: true)
            }
        }
        .sheet(isPresented: $showsPhotoPicker) {
            PhotoPicker(
                onPicked: { imported in prepareAndSendImage(imported) },
                onError: { model.alertMessage = $0 }
            )
        }
        .sheet(isPresented: $showsContactDetails) {
            ContactDetailsSheet(model: model, conversation: conversation)
        }
        .fileImporter(
            isPresented: $showsImageFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    prepareAndSendImage(ImportedImageFile(url: url, shouldDeleteAfterUse: false))
                }
            case .failure(let error):
                model.alertMessage = error.localizedDescription
            }
        }
        .alert("本地删除消息？", isPresented: Binding(
            get: { messagePendingDeletion != nil },
            set: { if !$0 { messagePendingDeletion = nil } }
        )) {
            Button("取消", role: .cancel) { messagePendingDeletion = nil }
            Button("删除", role: .destructive) {
                if let message = messagePendingDeletion {
                    _ = model.deleteMessageLocally(messageID: message.id, conversationID: conversation.id)
                    model.haptics.warning()
                    reload()
                }
                messagePendingDeletion = nil
            }
        } message: {
            Text("只会删除这台设备上的记录，不会撤回对方已经收到的消息。")
        }
        .alert("清空本地聊天记录？", isPresented: $showsClearConversationConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                _ = model.clearConversationLocally(conversationID: conversation.id)
                model.haptics.warning()
                reload()
            }
        } message: {
            Text("联系人与信任关系会保留，但本机这段对话的消息和附件会被删除。此操作不会影响对方设备。")
        }
        .alert("取消图片发送？", isPresented: Binding(
            get: { transferPendingCancellation != nil },
            set: { if !$0 { transferPendingCancellation = nil } }
        )) {
            Button("继续传输", role: .cancel) { transferPendingCancellation = nil }
            Button("取消发送", role: .destructive) {
                if let message = transferPendingCancellation { cancelImage(message) }
                transferPendingCancellation = nil
            }
        } message: {
            Text("已经发送并被对方确认的分块无法远程撤回；取消只会停止后续发送。")
        }
    }

    private func reload(loadAll: Bool = false, showLoading: Bool = false) {
        messageReloadGeneration &+= 1
        let generation = messageReloadGeneration
        let store = model.database
        let conversationID = conversation.id
        let limit = messageWindowLimit
        if showLoading { isReloadingMessages = true }

        DispatchQueue.global(qos: .userInitiated).async {
            let loadedMessages: [ChatMessage]
            let hasOlder: Bool
            if loadAll {
                loadedMessages = store.fetchMessages(conversationID: conversationID)
                hasOlder = false
            } else {
                let page = store.fetchRecentMessages(conversationID: conversationID, limit: limit)
                loadedMessages = page.messages
                hasOlder = page.hasOlder
            }
            DispatchQueue.main.async {
                guard generation == messageReloadGeneration else { return }
                if messages != loadedMessages { messages = loadedMessages }
                if hasOlderMessages != hasOlder { hasOlderMessages = hasOlder }
                if isReloadingMessages { isReloadingMessages = false }
            }
        }
    }

    private func loadOlderMessages() {
        guard hasOlderMessages, !isReloadingMessages else { return }
        let profile = VeilDevicePerformance.current
        messageWindowLimit = min(profile.messageWindowMaximum, messageWindowLimit + profile.messageWindowIncrement)
        reload(showLoading: true)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let outgoingText: String
        if let replyingTo {
            outgoingText = ReplyTextCodec.encode(quoted: ReplyTextCodec.quoteSource(for: replyingTo), reply: text)
        } else {
            outgoingText = text
        }
        do {
            try model.sessions.sendMessage(outgoingText, to: conversation.peerIdentityID)
            model.haptics.send()
            draft = ""
            replyingTo = nil
            reload()
        } catch {
            model.alertMessage = error.localizedDescription
        }
    }

    private func sendVoice(_ recording: VeilVoiceRecording) {
        do {
            try model.sessions.sendVoice(recording.data, durationSeconds: recording.durationSeconds, mimeType: recording.mimeType, to: conversation.peerIdentityID)
            model.haptics.send()
            reload()
        } catch {
            model.alertMessage = error.localizedDescription
        }
    }

    private func retry(_ message: ChatMessage) {
        do {
            try model.sessions.retryMessage(message.id, to: conversation.peerIdentityID)
            model.haptics.impact()
            reload()
        } catch {
            model.alertMessage = error.localizedDescription
        }
    }

    private func canPauseImage(_ message: ChatMessage) -> Bool {
        message.isOutgoing && message.attachment.map { MediaTransferPolicy.supportsImageMIMEType($0.mimeType) } == true && (message.deliveryState == .queued || message.deliveryState == .sending) && (message.transferProgress ?? 0) < 1
    }

    private func canResumeImage(_ message: ChatMessage) -> Bool {
        message.isOutgoing && message.attachment.map { MediaTransferPolicy.supportsImageMIMEType($0.mimeType) } == true && message.deliveryState == .paused
    }

    private func canCancelImage(_ message: ChatMessage) -> Bool {
        message.isOutgoing && message.attachment.map { MediaTransferPolicy.supportsImageMIMEType($0.mimeType) } == true && (message.deliveryState == .queued || message.deliveryState == .sending || message.deliveryState == .paused) && (message.transferProgress ?? 0) < 1
    }

    private func pauseImage(_ message: ChatMessage) {
        do {
            try model.sessions.pauseImageTransfer(message.id, to: conversation.peerIdentityID)
            model.haptics.selection()
            reload()
        } catch { model.alertMessage = error.localizedDescription }
    }

    private func resumeImage(_ message: ChatMessage) {
        do {
            try model.sessions.resumeImageTransfer(message.id, to: conversation.peerIdentityID)
            model.haptics.impact()
            reload()
        } catch { model.alertMessage = error.localizedDescription }
    }

    private func cancelImage(_ message: ChatMessage) {
        do {
            try model.sessions.cancelImageTransfer(message.id, to: conversation.peerIdentityID)
            model.haptics.warning()
            reload()
        } catch { model.alertMessage = error.localizedDescription }
    }

    private func prepareAndSendImage(_ imported: ImportedImageFile) {
        guard !isPreparingImage else { return }
        isPreparingImage = true
        withAnimation(.easeOut(duration: 0.18)) { mediaStatus = "正在高质量解析与压缩图片…" }

        Task { @MainActor in
            let accessed = imported.shouldDeleteAfterUse ? false : imported.url.startAccessingSecurityScopedResource()
            defer {
                if accessed { imported.url.stopAccessingSecurityScopedResource() }
                if imported.shouldDeleteAfterUse { try? FileManager.default.removeItem(at: imported.url) }
                isPreparingImage = false
            }
            do {
                let prepared = try await ImageTranscoder.prepare(at: imported.url)
                try model.sessions.sendImage(prepared.data, mimeType: prepared.mimeType, to: conversation.peerIdentityID)
                let status = prepared.summary
                withAnimation(.easeOut(duration: 0.18)) { mediaStatus = status }
                reload()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    if mediaStatus == status, !isPreparingImage {
                        withAnimation(.easeIn(duration: 0.18)) { mediaStatus = nil }
                    }
                }
            } catch {
                mediaStatus = nil
                model.alertMessage = error.localizedDescription
            }
        }
    }
}

private struct VeilChatIdentityTitle: View {
    let title: String
    let peerIdentityID: String

    var body: some View {
        HStack(spacing: 9) {
            VeilIdentityGlyph(seed: peerIdentityID, size: 30, active: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(VeilTheme.text)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text("SECURE LINK")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .tracking(0.9)
                        .foregroundColor(VeilTheme.mutedGold)
                    VeilLinkTrace(active: false, width: 26)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let database: DatabaseStore
    let onRetry: (() -> Void)?
    let onPause: (() -> Void)?
    let onResume: (() -> Void)?
    let onCancel: (() -> Void)?

    private var deliveryIcon: String {
        switch message.deliveryState { case .queued: return "clock"; case .sending: return "arrow.up.circle"; case .paused: return "pause.circle.fill"; case .delivered: return "checkmark.circle.fill"; case .cancelled: return "xmark.circle.fill"; case .failed: return "exclamationmark.circle.fill" }
    }

    private var deliveryLabel: String {
        switch message.deliveryState { case .queued: return "等待连接或发送"; case .sending: return "已发出，等待对方确认"; case .paused: return "已暂停"; case .delivered: return "已送达"; case .cancelled: return "已取消发送"; case .failed: return "发送失败" }
    }

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 46) }
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 5) {
                if let attachment = message.attachment, VoiceMessageCodec.isVoiceMIMEType(attachment.mimeType) {
                    VeilVoiceMessageBubble(message: message, attachment: attachment, database: database)
                } else if let attachment = message.attachment {
                    EncryptedImageView(
                        attachment: attachment,
                        database: database,
                        transferProgress: message.transferProgress,
                        isOutgoing: message.isOutgoing,
                        deliveryState: message.deliveryState
                    )
                    .frame(maxWidth: 260, maxHeight: 320)
                } else if message.body == "[图片]", let progress = message.transferProgress {
                    TransferShardView(image: nil, progress: progress, mode: .receiving)
                        .frame(width: 190)
                } else if let reply = ReplyTextCodec.decode(message.body) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(message.isOutgoing ? Color.black.opacity(0.55) : VeilTheme.gold)
                                .frame(width: 3)
                            Text(reply.quote)
                                .font(.caption)
                                .foregroundColor(message.isOutgoing ? Color.black.opacity(0.66) : VeilTheme.secondaryText)
                                .lineLimit(2)
                        }
                        Text(reply.reply)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(MessageBubbleSurface(outgoing: message.isOutgoing))
                    .foregroundColor(message.isOutgoing ? Color.black.opacity(0.90) : VeilTheme.text)
                    .clipShape(VeilPanelShape(cut: 11, radius: 7))
                    .overlay(
                        VeilPanelShape(cut: 11, radius: 7)
                            .stroke(message.isOutgoing ? Color.white.opacity(0.12) : VeilTheme.hairline, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                } else {
                    Text(message.body)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(MessageBubbleSurface(outgoing: message.isOutgoing))
                        .foregroundColor(message.isOutgoing ? Color.black.opacity(0.90) : VeilTheme.text)
                        .clipShape(VeilPanelShape(cut: 11, radius: 7))
                        .overlay(
                            VeilPanelShape(cut: 11, radius: 7)
                                .stroke(message.isOutgoing ? Color.white.opacity(0.12) : VeilTheme.hairline, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                }
                if message.body == "[图片]", let progress = message.transferProgress, message.isOutgoing, progress < 1 {
                    Text("对方已确认 \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                if message.isOutgoing, message.deliveryState == .paused {
                    Text("发送已暂停 · checkpoint 已保留")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.mutedGold)
                } else if message.isOutgoing, message.deliveryState == .cancelled {
                    Text("已取消后续发送")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                if message.isOutgoing, message.attachment != nil, (onPause != nil || onResume != nil || onCancel != nil) {
                    HStack(spacing: 12) {
                        if let onPause {
                            Button(action: onPause) { Label("暂停", systemImage: "pause.fill") }
                        }
                        if let onResume {
                            Button(action: onResume) { Label("继续", systemImage: "play.fill") }
                        }
                        if let onCancel {
                            Button(role: .destructive, action: onCancel) { Label("取消", systemImage: "xmark") }
                        }
                    }
                    .buttonStyle(VeilPressStyle())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(VeilTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.035))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(VeilTheme.hairline, lineWidth: 1))
                }
                HStack(spacing: 4) {
                    Text(message.sentAt, style: .time)
                    if message.isOutgoing {
                        if message.deliveryState == .delivered {
                            VeilResolveMark(resolved: true)
                                .accessibilityLabel(deliveryLabel)
                        } else {
                            Image(systemName: deliveryIcon).accessibilityLabel(deliveryLabel)
                        }
                        if message.deliveryState == .failed, let onRetry {
                            Button("重试", action: onRetry)
                                .buttonStyle(.plain)
                                .font(.caption2.weight(.semibold))
                        }
                    }
                }
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(message.deliveryState == .failed ? VeilTheme.danger : VeilTheme.tertiaryText)
                if message.isOutgoing, message.deliveryState == .failed, let reason = message.failureReason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.danger)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 260, alignment: .trailing)
                }
            }
            if !message.isOutgoing { Spacer(minLength: 46) }
        }
    }
}

private struct MessageBubbleSurface: View {
    let outgoing: Bool

    var body: some View {
        Group {
            if outgoing {
                VeilTheme.goldGradient
            } else {
                VeilTheme.incomingBubbleGradient
            }
        }
    }
}

private struct EncryptedImageView: View {
    let attachment: ChatAttachment
    let database: DatabaseStore
    let transferProgress: Double?
    let isOutgoing: Bool
    let deliveryState: ChatMessage.DeliveryState
    @State private var image: UIImage?
    @State private var shardImages: [UIImage]?
    @State private var isLoading = false
    @State private var revealCompletedImage = false
    @State private var completionPulse = false
    @State private var isSavingToPhotos = false
    @State private var savedToPhotos = false
    @State private var saveErrorMessage: String?
    @State private var showsLargeImage = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesReducedImageMotion: Bool {
        reduceMotion || VeilDevicePerformance.current.transferVisualComplexity != .full
    }

    private var progress: Double {
        min(max(transferProgress ?? 1, 0), 1)
    }

    var body: some View {
        Group {
            if let image {
                if isOutgoing && (progress < 1 || deliveryState == .failed || deliveryState == .cancelled) {
                    TransferShardView(
                        image: image,
                        shardImages: shardImages,
                        progress: progress,
                        mode: .sending,
                        phase: (deliveryState == .failed || deliveryState == .cancelled) ? .failed : .active
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { showsLargeImage = true }
                    .accessibilityHint("轻点查看大图")
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .opacity(revealCompletedImage ? 1 : 0.72)
                        .scaleEffect(revealCompletedImage ? 1 : 0.985)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { showsLargeImage = true }
                        .accessibilityHint("轻点查看大图")
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(VeilTheme.gold.opacity(completionPulse ? 0 : 0.86), lineWidth: completionPulse ? 1 : 3)
                                .scaleEffect(completionPulse ? 1.08 : 1)
                                .opacity(completionPulse ? 0 : 1)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if !isOutgoing, progress >= 1 {
                                Button(action: saveToPhotos) {
                                    Group {
                                        if isSavingToPhotos {
                                            ProgressView().tint(.white)
                                        } else {
                                            Image(systemName: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .background(.black.opacity(0.62), in: Circle())
                                    .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                .disabled(isSavingToPhotos || savedToPhotos)
                                .padding(8)
                                .accessibilityLabel(savedToPhotos ? "已保存到照片" : "保存到照片")
                            }
                        }
                        .contextMenu {
                            if !isOutgoing {
                                Button(savedToPhotos ? "已保存到照片" : "保存到照片", action: saveToPhotos)
                                    .disabled(isSavingToPhotos || savedToPhotos)
                            }
                        }
                        .onAppear(perform: revealCompletedTransfer)
                }
            } else {
                TransferShardView(
                    image: nil,
                    progress: progress,
                    mode: isOutgoing ? .sending : .receiving,
                    phase: isOutgoing && (deliveryState == .failed || deliveryState == .cancelled) ? .failed : .active
                )
            }
        }
        .onAppear(perform: loadImage)
        .onChange(of: progress) { _ in
            if image == nil { loadImage() }
        }
        .fullScreenCover(isPresented: $showsLargeImage) {
            if let image {
                FullScreenImageViewer(
                    attachmentID: attachment.id,
                    database: database,
                    initialImage: image
                )
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .alert("保存失败", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private func loadImage() {
        guard image == nil, !isLoading else { return }
        isLoading = true
        let attachmentID = attachment.id
        let shouldPrepareShards = VeilDevicePerformance.current.shouldPrecomputeTransferShards && isOutgoing && (progress < 1 || deliveryState == .failed)
        let store = database
        let previewCache = ImagePreviewCache.shared
        DispatchQueue.global(qos: .userInitiated).async {
            let decoded: UIImage?
            if let cached = previewCache.image(for: attachmentID) {
                decoded = cached
            } else if let data = store.loadAttachment(id: attachmentID),
                      let preview = ImagePreviewCache.downsample(data: data) {
                previewCache.insert(preview, for: attachmentID)
                decoded = preview
            } else {
                decoded = nil
            }
            let preparedShards = shouldPrepareShards ? decoded.map(TransferShardImageFactory.makeShards(from:)) : nil
            DispatchQueue.main.async {
                image = decoded
                shardImages = preparedShards
                isLoading = false
            }
        }
    }

    private func saveToPhotos() {
        guard !isSavingToPhotos, !savedToPhotos else { return }
        isSavingToPhotos = true
        let attachmentID = attachment.id
        let mimeType = attachment.mimeType
        let store = database
        DispatchQueue.global(qos: .userInitiated).async {
            let data = store.loadAttachment(id: attachmentID)
            DispatchQueue.main.async {
                guard let data else {
                    saveErrorMessage = "无法读取已经校验的本地图片数据。"
                    isSavingToPhotos = false
                    return
                }
                Task { @MainActor in
                    do {
                        try await PhotoLibrarySaver.save(data: data, mimeType: mimeType)
                        savedToPhotos = true
                    } catch {
                        savedToPhotos = false
                        saveErrorMessage = error.localizedDescription
                    }
                    isSavingToPhotos = false
                }
            }
        }
    }

    private func revealCompletedTransfer() {
        guard !revealCompletedImage else { return }
        revealCompletedImage = false
        completionPulse = false
        DispatchQueue.main.async {
            if usesReducedImageMotion {
                revealCompletedImage = true
                completionPulse = true
            } else {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                    revealCompletedImage = true
                }
                withAnimation(.easeOut(duration: 0.58)) {
                    completionPulse = true
                }
            }
        }
    }
}

private struct ImportedImageFile {
    let url: URL
    let shouldDeleteAfterUse: Bool
}

private struct ContactDetailsSheet: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String

    init(model: AppModel, conversation: ConversationSummary) {
        self.model = model
        self.conversation = conversation
        _displayName = State(initialValue: conversation.title)
    }

    var body: some View {
        NavigationView {
            VeilStableScrollView(maxContentWidth: 520, horizontalPadding: 18, verticalPadding: 18) {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        VeilIdentityGlyph(seed: conversation.peerIdentityID, size: 76, active: true)
                        Text("PEER IDENTITY")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundColor(VeilTheme.mutedGold)
                        Text(conversation.title)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                        VeilLinkTrace(active: false, width: 86)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("本地备注")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(VeilTheme.secondaryText)
                        TextField("备注名称", text: $displayName)
                            .textFieldStyle(VeilTextFieldStyle())
                    }
                    .veilCard()

                    VStack(alignment: .leading, spacing: 7) {
                        Text("IDENTITY ID")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundColor(VeilTheme.mutedGold)
                        Text(conversation.peerIdentityID)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(VeilTheme.secondaryText)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .veilCard(emphasized: true)

                    Text("备注名称只保存在当前本地身份中，不会发送给对方，也不会改变对方的密码学身份。")
                        .font(.footnote)
                        .foregroundColor(VeilTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
            }
            .background(VeilAmbientBackground())
            .navigationTitle("联系人信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if model.renameContact(peerIdentityID: conversation.peerIdentityID, displayName: displayName) { dismiss() }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct PhotoPicker: UIViewControllerRepresentable {
    let onPicked: (ImportedImageFile) -> Void
    let onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                picker.dismiss(animated: true)
                return
            }
            let identifiers = provider.registeredTypeIdentifiers
            let preferred = identifiers.first(where: { UTType($0)?.conforms(to: .rawImage) == true })
                ?? identifiers.first(where: { UTType($0)?.conforms(to: .image) == true })
            guard let typeIdentifier = preferred else {
                parent.onError("这个项目不是可识别的图片格式。")
                picker.dismiss(animated: true)
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let url else {
                    DispatchQueue.main.async {
                        self.parent.onError(error?.localizedDescription ?? "无法读取所选图片。")
                        picker.dismiss(animated: true)
                    }
                    return
                }
                do {
                    let type = UTType(typeIdentifier)
                    let ext = type?.preferredFilenameExtension ?? url.pathExtension.nonEmpty ?? "img"
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent("VeilLink-Import-\(UUID().uuidString)")
                        .appendingPathExtension(ext)
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.copyItem(at: url, to: destination)
                    DispatchQueue.main.async {
                        self.parent.onPicked(ImportedImageFile(url: destination, shouldDeleteAfterUse: true))
                        picker.dismiss(animated: true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.onError(error.localizedDescription)
                        picker.dismiss(animated: true)
                    }
                }
            }
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
