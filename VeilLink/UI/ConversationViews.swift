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
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.system(size: 42, weight: .light))
                        .foregroundColor(VeilTheme.gold)
                    Text("还没有对话").font(.headline)
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
                            ConversationRow(conversation: conversation)
                        }
                    } else {
                        Button {
                            model.selectedConversation = conversation
                        } label: {
                            ConversationRow(conversation: conversation)
                        }
                        .listRowBackground(model.selectedConversation?.id == conversation.id ? VeilTheme.gold.opacity(0.12) : Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("对话")
        .background(VeilTheme.background)
    }
}

private struct ConversationRow: View {
    let conversation: ConversationSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(VeilTheme.gold.opacity(0.16))
                .frame(width: 46, height: 46)
                .overlay(Text(String(conversation.title.prefix(1))).foregroundColor(VeilTheme.gold).fontWeight(.bold))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.title).fontWeight(.semibold)
                    Spacer()
                    Text(conversation.updatedAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Text(conversation.lastMessage.isEmpty ? "已建立安全会话" : conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct ChatView: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var showsPhotoPicker = false
    @State private var showsImageFileImporter = false
    @State private var isPreparingImage = false
    @State private var mediaStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                database: model.database,
                                onRetry: message.isOutgoing && message.deliveryState == .failed ? { retry(message) } : nil
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
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

                HStack(alignment: .bottom, spacing: 10) {
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
                            Image(systemName: "photo.badge.plus").font(.title3)
                        }
                    }
                    TextField("加密消息", text: $draft)
                        .textFieldStyle(VeilTextFieldStyle())
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 31))
                            .foregroundColor(draft.isEmpty ? VeilTheme.secondaryText : VeilTheme.gold)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
            }
            .background(VeilTheme.elevated)
        }
        .background(VeilTheme.background)
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("取消信任", role: .destructive) { model.setTrust(for: conversation.peerIdentityID, blocked: false) }
                    Button("拉黑身份", role: .destructive) { model.setTrust(for: conversation.peerIdentityID, blocked: true) }
                } label: {
                    Image(systemName: "shield")
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: model.messagesRevision) { _ in reload() }
        .sheet(isPresented: $showsPhotoPicker) {
            PhotoPicker(
                onPicked: { imported in prepareAndSendImage(imported) },
                onError: { model.alertMessage = $0 }
            )
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
    }

    private func reload() {
        messages = model.database.fetchMessages(conversationID: conversation.id)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try model.sessions.sendMessage(text, to: conversation.peerIdentityID)
            draft = ""
            reload()
        } catch {
            model.alertMessage = error.localizedDescription
        }
    }

    private func retry(_ message: ChatMessage) {
        do {
            try model.sessions.retryMessage(message.id, to: conversation.peerIdentityID)
            reload()
        } catch {
            model.alertMessage = error.localizedDescription
        }
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

private struct MessageBubble: View {
    let message: ChatMessage
    let database: DatabaseStore
    let onRetry: (() -> Void)?

    private var deliveryIcon: String {
        switch message.deliveryState { case .queued: return "clock"; case .sending: return "arrow.up.circle"; case .delivered: return "checkmark.circle.fill"; case .failed: return "exclamationmark.circle.fill" }
    }

    private var deliveryLabel: String {
        switch message.deliveryState { case .queued: return "等待连接或发送"; case .sending: return "已发出，等待对方确认"; case .delivered: return "已送达"; case .failed: return "发送失败" }
    }

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 54) }
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 5) {
                if let attachment = message.attachment {
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
                } else {
                    Text(message.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isOutgoing ? VeilTheme.gold : VeilTheme.panel)
                        .foregroundColor(message.isOutgoing ? .black : VeilTheme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                if message.body == "[图片]", let progress = message.transferProgress, message.isOutgoing, progress < 1 {
                    Text("对方已确认 \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                HStack(spacing: 4) {
                    Text(message.sentAt, style: .time)
                    if message.isOutgoing {
                        Image(systemName: deliveryIcon).accessibilityLabel(deliveryLabel)
                        if message.deliveryState == .failed, let onRetry {
                            Button("重试", action: onRetry)
                                .buttonStyle(.plain)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .font(.caption2)
                .foregroundColor(message.deliveryState == .failed ? VeilTheme.danger : VeilTheme.secondaryText)
                if message.isOutgoing, message.deliveryState == .failed, let reason = message.failureReason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.danger)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 260, alignment: .trailing)
                }
            }
            if !message.isOutgoing { Spacer(minLength: 54) }
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

    private var progress: Double {
        min(max(transferProgress ?? 1, 0), 1)
    }

    var body: some View {
        Group {
            if let image {
                if isOutgoing && (progress < 1 || deliveryState == .failed) {
                    TransferShardView(
                        image: image,
                        shardImages: shardImages,
                        progress: progress,
                        mode: .sending,
                        phase: deliveryState == .failed ? .failed : .active
                    )
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .opacity(revealCompletedImage ? 1 : 0.72)
                        .scaleEffect(revealCompletedImage ? 1 : 0.985)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
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
                    phase: isOutgoing && deliveryState == .failed ? .failed : .active
                )
            }
        }
        .onAppear(perform: loadImage)
        .onChange(of: progress) { _ in
            if image == nil { loadImage() }
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
        let shouldPrepareShards = isOutgoing && (progress < 1 || deliveryState == .failed)
        let store = database
        DispatchQueue.global(qos: .userInitiated).async {
            let decoded: UIImage?
            if let data = store.loadAttachment(id: attachmentID) {
                decoded = UIImage(data: data)
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
            withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                revealCompletedImage = true
            }
            withAnimation(.easeOut(duration: 0.58)) {
                completionPulse = true
            }
        }
    }
}

private struct ImportedImageFile {
    let url: URL
    let shouldDeleteAfterUse: Bool
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
