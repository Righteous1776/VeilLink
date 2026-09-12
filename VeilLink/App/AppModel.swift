import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var selectedConversation: ConversationSummary?
    @Published var selectedSection: SidebarSection = .chats
    @Published var exportedBackupURL: URL?
    @Published var alertMessage: String?
    @Published private(set) var messagesRevision = 0
    @Published private(set) var activeConversationID: String?
    @Published private(set) var performanceRevision = 0
    @Published var autoSaveReceivedImages: Bool {
        didSet { UserDefaults.standard.set(autoSaveReceivedImages, forKey: Self.autoSaveReceivedImagesKey) }
    }
    private var messageRefreshTask: Task<Void, Never>?
    private var pendingConversationRefresh = false
    private static let autoSaveReceivedImagesKey = "media.autoSaveReceivedImages"

    let keychain: KeychainStore
    let database: DatabaseStore
    let identity: IdentityManager
    let appLock: AppLockController
    let ownerMode: OwnerModeController
    let bluetooth: BLETransport
    let sessions: SessionCoordinator
    let backups: BackupManager
    let haptics: HapticEngine
    let performanceOverrides: PerformanceOverrideController

    var totalUnreadCount: Int {
        conversations.reduce(0) { partial, conversation in
            min(999, partial + conversation.unreadCount)
        }
    }

    init() throws {
        autoSaveReceivedImages = UserDefaults.standard.bool(forKey: Self.autoSaveReceivedImagesKey)
        let keychain = KeychainStore()
        self.keychain = keychain
        database = try DatabaseStore(keychain: keychain)
        identity = IdentityManager(keychain: keychain)
        for profile in identity.profiles { try? database.upsertProfile(profile) }
        if identity.profiles.count == 1, let onlyIdentity = identity.profiles.first {
            try? database.adoptLegacyUnscopedRows(localIdentityID: onlyIdentity.id)
        }
        appLock = AppLockController(keychain: keychain)
        ownerMode = OwnerModeController()
        performanceOverrides = PerformanceOverrideController()
        bluetooth = BLETransport()
        sessions = SessionCoordinator(identity: identity, database: database)
        backups = BackupManager(database: database, identity: identity)
        haptics = HapticEngine()
        performanceOverrides.onChange = { [weak self] in
            self?.applyPerformanceOverrideChange()
        }

        bluetooth.onDiscovered = { [weak sessions] id, rssi in
            sessions?.discovered(transportID: id, rssi: rssi)
        }
        bluetooth.onConnected = { [weak sessions] id in
            sessions?.connected(transportID: id)
        }
        bluetooth.onDisconnected = { [weak sessions] id in
            sessions?.disconnected(transportID: id)
        }
        bluetooth.onReceive = { [weak sessions] id, data in sessions?.receive(transportID: id, data: data) }
        sessions.transportSend = { [weak bluetooth] id, data, priority in
            bluetooth?.send(data, to: id, priority: priority) ?? .temporarilyUnavailable
        }
        sessions.transportDisconnect = { [weak bluetooth] id in bluetooth?.disconnect(id) }
        sessions.onMessagesChanged = { [weak self] refreshConversations in
            self?.scheduleMessageRefresh(refreshConversations: refreshConversations)
        }
        sessions.onInboundMessageReceived = { [weak self] in
            self?.haptics.receive()
        }
        sessions.onDeliveryConfirmed = { [weak self] in
            self?.haptics.resolved()
        }
        sessions.onInboundAttachmentCompleted = { [weak self] messageID in
            guard let self, self.autoSaveReceivedImages else { return }
            Task { @MainActor [weak self] in await self?.autoSaveReceivedImage(messageID: messageID) }
        }
        reloadConversations()
    }

    private func applyPerformanceOverrideChange() {
        messageRefreshTask?.cancel()
        pendingConversationRefresh = false
        database.clearTransientCaches()
        sessions.clearTransientCaches()
        ImagePreviewCache.shared.removeAll()
        ImagePreviewCache.shared.reconfigureForCurrentProfile()
        performanceRevision &+= 1
    }

    private func scheduleMessageRefresh(refreshConversations: Bool) {
        pendingConversationRefresh = pendingConversationRefresh || refreshConversations
        messageRefreshTask?.cancel()
        messageRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: VeilDevicePerformance.current.messageRefreshDebounceNanoseconds)
            guard !Task.isCancelled, let self else { return }
            let shouldRefreshConversations = self.pendingConversationRefresh
            self.pendingConversationRefresh = false

            if shouldRefreshConversations {
                if let activeConversationID = self.activeConversationID {
                    try? self.database.markConversationRead(conversationID: activeConversationID)
                }
                self.reloadConversations()
            }
            self.messagesRevision &+= 1
        }
    }

    func handleMemoryPressure() {
        database.clearTransientCaches()
        sessions.clearTransientCaches()
        ImagePreviewCache.shared.removeAll()
    }

    func trimCachesForBackgroundIfNeeded() {
        guard VeilDevicePerformance.current.aggressiveBackgroundCacheTrim else { return }
        handleMemoryPressure()
    }

    func start() {
        guard identity.activeIdentity != nil else { return }
        _ = try? database.cleanupStaleInboundAttachments()
        bluetooth.start()
    }

    func createInitialProfile(name: String, password: String, pin: String) -> Bool {
        do {
            let profile = try identity.createProfile(displayName: name, password: password)
            try database.upsertProfile(profile)
            guard appLock.configure(pin: pin) else {
                alertMessage = appLock.errorMessage
                return false
            }
            start()
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func createAdditionalProfile(name: String, password: String) -> Bool {
        let wasRunning = bluetooth.isRunning
        bluetooth.stop()
        do {
            let profile = try identity.createProfile(displayName: name, password: password)
            try database.upsertProfile(profile)
            sessions.resetForIdentityChange()
            selectedConversation = nil
            activeConversationID = nil
            reloadConversations()
            if wasRunning { bluetooth.start() }
            return true
        } catch {
            if wasRunning { bluetooth.start() }
            alertMessage = error.localizedDescription
            return false
        }
    }

    func switchIdentity(to id: String, password: String) -> Bool {
        guard identity.activeIdentity?.id != id else { return true }
        let wasRunning = bluetooth.isRunning
        bluetooth.stop()
        guard identity.switchProfile(to: id, password: password) else {
            if wasRunning { bluetooth.start() }
            alertMessage = "身份密码不正确。"
            return false
        }
        if let active = identity.activeIdentity { try? database.upsertProfile(active) }
        sessions.resetForIdentityChange()
        selectedConversation = nil
        activeConversationID = nil
        reloadConversations()
        if wasRunning { bluetooth.start() }
        return true
    }

    func renameContact(peerIdentityID: String, displayName: String) -> Bool {
        guard let localIdentityID = identity.activeIdentity?.id else { return false }
        do {
            try database.renameContact(localIdentityID: localIdentityID, identityID: peerIdentityID, displayName: displayName)
            reloadConversations()
            messagesRevision &+= 1
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func deleteIdentity(id: String, password: String) -> Bool {
        guard identity.activeIdentity?.id != id else {
            alertMessage = IdentityError.cannotDeleteActiveIdentity.localizedDescription
            return false
        }
        guard identity.verifyPassword(password, for: id) else {
            alertMessage = "身份密码不正确。"
            return false
        }
        do {
            try database.deleteLocalIdentityData(localIdentityID: id)
            _ = try identity.deleteProfile(id: id, password: password)
            for profile in identity.profiles { try? database.upsertProfile(profile) }
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func deleteMessageLocally(messageID: String, conversationID: String) -> Bool {
        do {
            sessions.discardLocalMessage(messageID)
            try database.deleteMessageLocally(messageID: messageID, conversationID: conversationID)
            reloadConversations()
            messagesRevision &+= 1
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func clearConversationLocally(conversationID: String) -> Bool {
        let messageIDs = database.fetchMessageIDs(conversationID: conversationID)
        messageIDs.forEach { sessions.discardLocalMessage($0) }
        do {
            try database.clearConversationLocally(conversationID: conversationID)
            reloadConversations()
            messagesRevision &+= 1
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    private func autoSaveReceivedImage(messageID: String) async {
        guard autoSaveReceivedImages,
              let message = database.fetchMessage(id: messageID),
              !message.isOutgoing,
              let attachment = message.attachment,
              let data = database.loadAttachment(id: attachment.id) else { return }
        do {
            try await PhotoLibrarySaver.save(data: data, mimeType: attachment.mimeType)
        } catch {
            alertMessage = "自动保存收到的图片失败：\(error.localizedDescription)"
        }
    }

    func setTrust(for peerIdentityID: String, blocked: Bool) {
        guard let localIdentityID = identity.activeIdentity?.id else { return }
        do {
            try database.setPeerTrust(localIdentityID: localIdentityID, identityID: peerIdentityID, blocked: blocked)
            sessions.invalidatePeer(peerIdentityID)
            alertMessage = blocked ? "已拉黑该身份。历史记录仍保留。" : "已取消信任。重新通信前需要再次核对六码。"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func reloadConversations() {
        guard let localIdentityID = identity.activeIdentity?.id else {
            conversations = []
            selectedConversation = nil
            activeConversationID = nil
            return
        }
        conversations = database.fetchConversations(localIdentityID: localIdentityID)
        if let selectedID = selectedConversation?.id {
            selectedConversation = conversations.first(where: { $0.id == selectedID })
        }
    }


    func setConversationVisible(_ conversationID: String, visible: Bool) {
        if visible {
            activeConversationID = conversationID
            do {
                try database.markConversationRead(conversationID: conversationID)
                reloadConversations()
            } catch {
                alertMessage = error.localizedDescription
            }
        } else if activeConversationID == conversationID {
            activeConversationID = nil
        }
    }

    func setConversationPinned(_ conversationID: String, pinned: Bool) -> Bool {
        do {
            try database.setConversationPinned(conversationID: conversationID, pinned: pinned)
            reloadConversations()
            haptics.selection()
            return true
        } catch {
            alertMessage = error.localizedDescription
            haptics.error()
            return false
        }
    }

    func markConversationRead(_ conversationID: String) -> Bool {
        do {
            try database.markConversationRead(conversationID: conversationID)
            reloadConversations()
            haptics.selection()
            return true
        } catch {
            alertMessage = error.localizedDescription
            haptics.error()
            return false
        }
    }

    func markConversationUnread(_ conversationID: String) -> Bool {
        do {
            try database.markConversationUnread(conversationID: conversationID)
            reloadConversations()
            haptics.selection()
            return true
        } catch {
            alertMessage = error.localizedDescription
            haptics.error()
            return false
        }
    }

    func exportBackup(password: String) {
        do {
            exportedBackupURL = try backups.exportBackup(password: password)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func restoreBackup(url: URL, password: String) {
        let accessed = url.startAccessingSecurityScopedResource()
        let wasRunning = bluetooth.isRunning
        bluetooth.stop()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
            if wasRunning || identity.activeIdentity != nil { start() }
        }
        do {
            try backups.restoreBackup(from: url, password: password)
            sessions.resetForIdentityChange()
            selectedConversation = nil
            activeConversationID = nil
            reloadConversations()
            alertMessage = "备份已恢复。"
        } catch {
            sessions.resetForIdentityChange()
            alertMessage = error.localizedDescription
        }
    }
}
