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
    private var messageRefreshTask: Task<Void, Never>?

    let keychain: KeychainStore
    let database: DatabaseStore
    let identity: IdentityManager
    let appLock: AppLockController
    let ownerMode: OwnerModeController
    let bluetooth: BLETransport
    let sessions: SessionCoordinator
    let backups: BackupManager

    init() throws {
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
        bluetooth = BLETransport()
        sessions = SessionCoordinator(identity: identity, database: database)
        backups = BackupManager(database: database, identity: identity)

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
        sessions.transportSend = { [weak bluetooth] id, data in bluetooth?.send(data, to: id) ?? .temporarilyUnavailable }
        sessions.transportDisconnect = { [weak bluetooth] id in bluetooth?.disconnect(id) }
        sessions.onMessagesChanged = { [weak self] in
            self?.scheduleMessageRefresh()
        }
        reloadConversations()
    }


    private func scheduleMessageRefresh() {
        messageRefreshTask?.cancel()
        messageRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 75_000_000)
            guard !Task.isCancelled, let self else { return }
            self.reloadConversations()
            self.messagesRevision &+= 1
        }
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
        reloadConversations()
        if wasRunning { bluetooth.start() }
        return true
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
            return
        }
        conversations = database.fetchConversations(localIdentityID: localIdentityID)
        if let selectedID = selectedConversation?.id {
            selectedConversation = conversations.first(where: { $0.id == selectedID })
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
            reloadConversations()
            alertMessage = "备份已恢复。"
        } catch {
            sessions.resetForIdentityChange()
            alertMessage = error.localizedDescription
        }
    }
}
