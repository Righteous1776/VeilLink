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
    private var a9RefreshTask: Task<Void, Never>?
    private var a9PeriodicTask: Task<Void, Never>?
    private var a9Cancellables = Set<AnyCancellable>()
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
    let a9Health: VeilA9HealthMonitor
    let computeGovernor: VeilA9ComputeGovernor
    let agentControls: AgentControlCenterSettings
    let maleCNS: MaleCNSGraphManager
    let gameIntelligence: AgentGameContextBroker
    let agent: AgentCoordinator

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
        a9Health = VeilA9HealthMonitor()
        let agentProfile = AgentCapabilityProfile.current
        computeGovernor = VeilA9ComputeGovernor(profile: agentProfile)
        agentControls = AgentControlCenterSettings()
        maleCNS = MaleCNSGraphManager(profile: agentProfile, governor: computeGovernor)
        maleCNS.setDeploymentMode(agentControls.gameDecisionMode.graphDeploymentMode)
        gameIntelligence = AgentGameContextBroker(maleCNS: maleCNS, controls: agentControls)
        agent = AgentCoordinator(
            runtime: LocalTextModelRuntimeFactory.make(profile: agentProfile),
            capabilityProfile: agentProfile,
            computeGovernor: computeGovernor
        )
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
        agent.bindIntegration(
            localContextProvider: { [weak self] in self?.makeAgentLocalContext() },
            toolExecutor: { [weak self] text in self?.executeAgentTool(text) }
        )
        agent.setVisualContextEnabled(agentControls.visualContextEnabled)
        configureA9HealthMonitoring()
        reloadConversations()
        refreshA9Health()
        startA9PeriodicSampling()
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

    private func configureA9HealthMonitoring() {
        bluetooth.$linkSnapshots
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        bluetooth.$isRunning
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        agent.$runtimeState
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        agent.$diagnostics
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        a9Health.$decision
            .sink { [weak self] decision in
                Task { @MainActor [weak self] in self?.computeGovernor.update(decision: decision) }
            }
            .store(in: &a9Cancellables)
    }

    private func scheduleA9Refresh() {
        a9RefreshTask?.cancel()
        a9RefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshA9Health()
        }
    }

    func refreshA9Health() {
        let snapshots = Array(bluetooth.linkSnapshots.values)
        let input = VeilA9Input(
            bluetoothRunning: bluetooth.isRunning,
            connectedPeerCount: snapshots.filter(\.isConnected).count,
            trackedPeerCount: snapshots.count,
            recoveringPeerCount: snapshots.filter(\.isRecovering).count,
            weakPeerCount: snapshots.filter { $0.quality == .weak }.count,
            marginalPeerCount: snapshots.filter { $0.quality == .marginal }.count,
            minimumLinkHealth: snapshots.map(\.healthScore).min(),
            maximumReconnectAttempt: snapshots.map(\.reconnectAttempt).max() ?? 0,
            pendingBytes: snapshots.reduce(0) { $0 + $1.pendingBytes },
            controlPendingPackets: snapshots.reduce(0) { $0 + $1.controlPendingPackets },
            maximumStallMilliseconds: Int((snapshots.compactMap(\.stalledFor).max() ?? 0) * 1_000),
            agentUnavailable: agent.runtimeState == .unavailable,
            agentCooling: agent.runtimeState == .cooling,
            agentHasFailure: agent.diagnostics.lastFailure != nil,
            thermalLevel: currentA9ThermalLevel(),
            lowPowerMode: currentA9LowPowerMode(),
            databaseIntegrity: a9Health.databaseIntegrity
        )
        a9Health.evaluate(input)
    }

    func runA9StorageCheck() {
        let result = database.integrityCheck().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        a9Health.setDatabaseIntegrity(result == "ok" ? .ok : .failed)
        refreshA9Health()
    }

    func a9DiagnosticsReport() -> String {
        a9Health.report() + "\n\n" + computeGovernor.report()
    }

    private func currentA9ThermalLevel() -> VeilA9ThermalLevel {
        #if os(iOS)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
        #else
        return .nominal
        #endif
    }

    private func currentA9LowPowerMode() -> Bool {
        #if os(iOS)
        return ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        return false
        #endif
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


    private func startA9PeriodicSampling() {
        guard a9PeriodicTask == nil else { return }
        a9PeriodicTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled, let self else { break }
                self.refreshA9Health()
            }
        }
    }

    func handleForegroundTransition() {
        refreshA9Health()
        startA9PeriodicSampling()
    }

    func handleMemoryPressure() {
        database.clearTransientCaches()
        sessions.clearTransientCaches()
        ImagePreviewCache.shared.removeAll()
        computeGovernor.trimMaleCNSConsumers()
        maleCNS.trim()
        agent.handleMemoryPressure()
    }

    func handleBackgroundTransition() {
        a9PeriodicTask?.cancel()
        a9PeriodicTask = nil
        computeGovernor.trimMaleCNSConsumers()
        if AgentCapabilityProfile.current.unloadOnBackground { maleCNS.unload() } else { maleCNS.trim() }
        agent.handleBackground()
        trimCachesForBackgroundIfNeeded()
    }

    func trimCachesForBackgroundIfNeeded() {
        guard VeilDevicePerformance.current.aggressiveBackgroundCacheTrim else { return }
        database.clearTransientCaches()
        sessions.clearTransientCaches()
        ImagePreviewCache.shared.removeAll()
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
            gameIntelligence.clear()
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
        gameIntelligence.clear()
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
            gameIntelligence.clear()
            selectedConversation = nil
            activeConversationID = nil
            reloadConversations()
            alertMessage = "备份已恢复。"
        } catch {
            sessions.resetForIdentityChange()
            gameIntelligence.clear()
            alertMessage = error.localizedDescription
        }
    }

    func updateAgentGameContext(_ session: MiniGameSessionSnapshot, conversation: ConversationSummary) {
        gameIntelligence.update(
            session: session,
            conversationTitle: conversation.title,
            peerIdentityID: conversation.peerIdentityID
        )
    }

    @discardableResult
    func executeAgentSuggestedGameMove() -> String {
        guard agentControls.allowSuggestedGameMoveExecution else {
            return "AI 控制中心当前禁止执行建议着法。你仍可以查看分析或手动在棋盘操作。"
        }
        guard let action = gameIntelligence.currentSuggestedAction() else {
            return "当前没有足够新鲜、经过合法动作校验的推荐着法；请回到棋局刷新后再试。"
        }
        guard let game = MiniGameKind(rawValue: action.gameID) else {
            return "当前推荐动作的游戏类型无效。"
        }
        let packet = MiniGamePacket(
            sessionID: action.sessionID,
            game: game,
            command: .move,
            turn: action.turn,
            move: action.move
        )
        do {
            try sessions.sendMiniGamePacket(packet, to: action.peerIdentityID)
            gameIntelligence.markSuggestedActionExecuted(action)
            haptics.send()
            return "已执行经过原游戏引擎候选校验的建议着法：\(action.label)。动作仍通过当前 E2EE 游戏消息链路发送。"
        } catch {
            haptics.error()
            return "建议着法未执行：\(error.localizedDescription)"
        }
    }

    private func makeAgentLocalContext() -> AgentLocalContext {
        let snapshots = Array(bluetooth.linkSnapshots.values)
        let selectedContext: AgentConversationContext? = selectedConversation.map { conversation in
            let transportID = sessions.transportID(for: conversation.peerIdentityID)
            let link = transportID.flatMap { bluetooth.linkSnapshots[$0] ?? bluetooth.linkSnapshot(for: $0) }
            return AgentConversationContext(
                title: conversation.title,
                unreadCount: conversation.unreadCount,
                secureSessionReady: sessions.hasSecureSession(for: conversation.peerIdentityID),
                linkHealth: link?.healthScore,
                linkQuality: link?.qualityTitle
            )
        }
        return AgentLocalContext(
            generatedAt: Date(),
            activeIdentityName: identity.activeIdentity?.displayName,
            selectedConversation: selectedContext,
            bluetooth: AgentBluetoothContext(
                running: bluetooth.isRunning,
                trackedPeers: snapshots.count,
                connectedPeers: snapshots.filter(\.isConnected).count,
                recoveringPeers: snapshots.filter(\.isRecovering).count,
                pendingBytes: snapshots.reduce(0) { $0 + $1.pendingBytes },
                weakestHealth: snapshots.map(\.healthScore).min()
            ),
            a9HealthScore: a9Health.decision.healthScore,
            a9Mode: computeGovernor.plan.mode.title,
            databaseIntegrity: a9Health.databaseIntegrity.title,
            maleCNSState: maleCNS.state.displayName,
            game: gameIntelligence.context,
            availableTools: AgentToolRouter.advertisedCommands
        )
    }

    private func executeAgentTool(_ raw: String) -> AgentToolExecution? {
        guard let command = AgentToolRouter.parse(raw) else { return nil }
        switch command {
        case .refreshBLE:
            guard agentControls.localToolMutationsEnabled else {
                return AgentToolExecution(command: "/ble refresh", message: "AI 控制中心已关闭本地工具动作；BLE 状态查询仍可使用。")
            }
            bluetooth.refreshLinks()
            refreshA9Health()
            let connected = bluetooth.linkSnapshots.values.filter(\.isConnected).count
            return AgentToolExecution(
                command: "/ble refresh",
                message: "已在本机刷新 BLE 扫描、广播、已知连接恢复与 RSSI 采样。当前连接 \(connected) 台设备。"
            )
        case .databaseIntegrity:
            guard agentControls.localToolMutationsEnabled else {
                return AgentToolExecution(command: "/db check", message: "AI 控制中心已关闭本地工具动作；没有执行数据库完整性自检。")
            }
            runA9StorageCheck()
            return AgentToolExecution(
                command: "/db check",
                message: "本地 SQLite 完整性检查已执行：\(a9Health.databaseIntegrity.title)。没有读取或回显聊天正文。"
            )
        case .a9Status:
            return AgentToolExecution(
                command: "/a9 status",
                message: "A9：健康度 \(a9Health.decision.healthScore)/100，计算模式 \(computeGovernor.plan.mode.title)，数据库 \(a9Health.databaseIntegrity.title)。"
            )
        case .agentStatus:
            return AgentToolExecution(
                command: "/agent status",
                message: "灵核运行时：\(agent.runtimeManifest?.displayName ?? LocalTextModelRuntimeFactory.backendName)，状态 \(agent.runtimeState.displayName)；MaleCNS：\(maleCNS.state.displayName)。"
            )
        case .gameStatus:
            guard let game = gameIntelligence.context else {
                return AgentToolExecution(command: "/game status", message: "当前没有已接入灵核的活动对局。")
            }
            return AgentToolExecution(
                command: "/game status",
                message: "当前对局：\(game.gameTitle)，第 \(game.turn) 回合，\(game.isLocalTurn ? "轮到你" : "等待对方")，策略模式 \(game.policyMode)。"
            )
        case .executeSuggestedGameMove:
            return AgentToolExecution(command: "/game move", message: executeAgentSuggestedGameMove())
        }
    }

    func setAgentAutoLoadLanguageModel(_ enabled: Bool) {
        agentControls.autoLoadLanguageModel = enabled
        if enabled { agent.activate() }
    }

    func setAgentConversationTextAccessEnabled(_ enabled: Bool) {
        agentControls.conversationTextAccessEnabled = enabled
    }

    func setAgentVisualContextEnabled(_ enabled: Bool) {
        agentControls.visualContextEnabled = enabled
        agent.setVisualContextEnabled(enabled)
    }

    func setAgentLocalToolMutationsEnabled(_ enabled: Bool) {
        agentControls.localToolMutationsEnabled = enabled
    }

    func setAgentSuggestedGameMoveExecutionEnabled(_ enabled: Bool) {
        agentControls.allowSuggestedGameMoveExecution = enabled
    }

    func setAgentGameDecisionMode(_ mode: AgentGameDecisionMode) {
        guard !(mode == .experimentalCore && agent.capabilityProfile.tier == .legacyA10) else {
            alertMessage = "iPhone 7 / A10 档位禁止加载 Core VFLY。"
            return
        }
        agentControls.gameDecisionMode = mode
        maleCNS.setDeploymentMode(mode.graphDeploymentMode)
        maleCNS.prepareFromBundle()
        gameIntelligence.reconfigure()
        haptics.selection()
    }

    func trimAgentMemory() {
        agent.trimRuntimeMemory()
        maleCNS.trim()
        ImagePreviewCache.shared.removeAll()
        refreshA9Health()
    }

    func resetAgentControls() {
        agentControls.resetToSafeDefaults()
        agent.setVisualContextEnabled(agentControls.visualContextEnabled)
        maleCNS.setDeploymentMode(agentControls.gameDecisionMode.graphDeploymentMode)
        maleCNS.prepareFromBundle()
        gameIntelligence.reconfigure()
        haptics.resolved()
    }

    func agentDiagnosticsReport() -> String {
        [
            agent.diagnosticsReport(),
            "",
            "VeilLink AI Control Center",
            "Auto-load LLM: \(agentControls.autoLoadLanguageModel)",
            "Conversation text access: \(agentControls.conversationTextAccessEnabled)",
            "Visual context: \(agentControls.visualContextEnabled)",
            "Local tool mutations: \(agentControls.localToolMutationsEnabled)",
            "Suggested move execution: \(agentControls.allowSuggestedGameMoveExecution)",
            "Game decision mode: \(agentControls.gameDecisionMode.rawValue)",
            "VFLY deployment mode: \(maleCNS.deploymentMode.rawValue)",
            "VFLY state: \(maleCNS.state.displayName)",
            "Privacy: no message plaintext, media, keys, pairing codes or database paths in this report."
        ].joined(separator: "\n")
    }

}
