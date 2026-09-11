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

    let keychain: KeychainStore
    let database: DatabaseStore
    let identity: IdentityManager
    let appLock: AppLockController
    let ownerMode: OwnerModeController
    let bluetooth: BLETransport
    let sessions: SessionCoordinator
    let backups: BackupManager

    init() {
        let keychain = KeychainStore()
        self.keychain = keychain
        do {
            database = try DatabaseStore(keychain: keychain)
        } catch {
            fatalError("VeilLink database initialization failed: \(error)")
        }
        identity = IdentityManager(keychain: keychain)
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
        bluetooth.onReceive = { [weak sessions] id, data in
            sessions?.receive(transportID: id, data: data)
        }
        sessions.transportSend = { [weak bluetooth] id, data in
            bluetooth?.send(data, to: id)
        }
        sessions.onMessagesChanged = { [weak self] in
            guard let self else { return }
            self.reloadConversations()
            self.messagesRevision += 1
        }
        reloadConversations()
    }

    func start() {
        guard identity.activeIdentity != nil else { return }
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

    func reloadConversations() {
        conversations = database.fetchConversations()
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
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try backups.restoreBackup(from: url, password: password)
            reloadConversations()
            alertMessage = "备份已恢复。"
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
