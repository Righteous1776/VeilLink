import Foundation
import Combine
import VeilopolyNet
import VeilopolyUI

/// Product-layer P5 hookup only. SessionCoordinator authenticates/decrypts the
/// sender and owns all transport, replay-window, key and database behavior.
@MainActor
final class VeilopolyMultiplayerBridge: ObservableObject {
    @Published private(set) var gameModel: GameSessionModel?
    @Published private(set) var incomingInvitation: VeilopolyRoomConfiguration?
    @Published private(set) var outgoingInvitation: VeilopolyRoomConfiguration?
    @Published private(set) var status = "两名真人 + 两名 AI · 使用现有加密链路"
    @Published private(set) var lastError: String?
    @Published var isGamePresented = false
    private let sessions: SessionCoordinator
    private let localIdentity: @MainActor () -> String?
    private let fixedResumeURL: URL?
    private var resumeURL: URL {
        fixedResumeURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Veilopoly", isDirectory: true)
            .appendingPathComponent(VeilopolyRoomResumeRecord.filename(for: boundLocalIdentity ?? localIdentity() ?? ""))
    }
    private var assembler = VeilopolyControlAssembler()
    private struct Outbound { let peer: String; let packet: VeilopolyRoomPacket }
    private var outgoing: [Outbound] = []
    private var senderTask: Task<Void, Never>?
    private var senderGeneration = UUID()
    private var monitorTask: Task<Void, Never>?
    private var configuration: VeilopolyRoomConfiguration?
    private var boundLocalIdentity: String?
    private var lastHeard = Date.distantPast
    private var lastInviteSent = Date.distantPast
    private var lastSyncSent = Date.distantPast
    private var invitationBegan = Date.distantPast
    private var waitingForHostAcceptance = false
    private var peerLeft = false
    private var foreground = true

    init(sessions: SessionCoordinator, localIdentity: @escaping @MainActor () -> String?, resumeURL: URL? = nil) {
        self.sessions = sessions
        self.localIdentity = localIdentity
        self.fixedResumeURL = resumeURL
    }

    func invite(_ conversation: ConversationSummary) {
        guard gameModel == nil, incomingInvitation == nil, outgoingInvitation == nil,
              let local = localIdentity(), local != conversation.peerIdentityID else { return }
        guard sessions.hasSecureSession(for: conversation.peerIdentityID) else {
            _ = sessions.recoverSecureSession(for: conversation.peerIdentityID)
            lastError = "对手加密链路尚未就绪，请先完成配对或重连后再邀请。"
            return
        }
        let config = VeilopolyRoomConfiguration(roomID: UUID().uuidString, seed: VeilopolyNewGameSeed.fresh(),
            hostIdentityID: local, guestIdentityID: conversation.peerIdentityID)
        outgoingInvitation = config; boundLocalIdentity = local
        lastError = nil
        invitationBegan = Date(); lastInviteSent = Date()
        status = "邀请已发出，等待对方明确接受（120 秒有效）"
        enqueue(.init(roomID: config.roomID, kind: .invite, configuration: config), to: config.guestIdentityID)
        startMonitoring()
    }

    func acceptInvitation() {
        guard let config = incomingInvitation, config.guestIdentityID == localIdentity(),
              Date().timeIntervalSince(invitationBegan) <= 120 else { return }
        do {
            try createGame(config)
            incomingInvitation = nil; waitingForHostAcceptance = true
            enqueue(.init(roomID: config.roomID, kind: .accept), to: config.hostIdentityID)
            isGamePresented = true
        } catch { lastError = "无法创建联机对局，原存档未清除。" }
    }

    func declineInvitation() {
        if let config = incomingInvitation {
            enqueue(.init(roomID: config.roomID, kind: .decline), to: config.hostIdentityID)
        }
        incomingInvitation = nil
    }

    func receive(_ event: VeilControlEvent, from authenticatedPeer: String) {
        guard event.topic == VeilopolyControlCodec.topic, let local = localIdentity(),
              event.payload.count <= 1_536 else { return }
        if let boundLocalIdentity, boundLocalIdentity != local { suspendForIdentityChange(); return }
        do {
            let fragment = try JSONDecoder().decode(VeilopolyControlFragment.self, from: event.payload)
            if let config = configuration {
                guard fragment.roomID == config.roomID,
                      authenticatedPeer == peer(for: config, local: local) else { return }
                // Guests submit small commands, never bulk snapshots. Unknown
                // rooms below can only assemble a bounded invitation/control.
                if local == config.hostIdentityID && fragment.count > 64 { return }
            } else if fragment.count > 4 {
                return
            }
            guard let packet = try assembler.ingest(fragment, from: authenticatedPeer,
                now: Date().timeIntervalSince1970) else { return }
            switch packet.kind {
            case .invite:
                guard let config = packet.configuration, config.hostIdentityID == authenticatedPeer,
                      config.guestIdentityID == local, gameModel == nil, outgoingInvitation == nil,
                      incomingInvitation == nil || incomingInvitation?.roomID == config.roomID,
                      Date().timeIntervalSince1970 - event.createdAt <= 120,
                      event.createdAt - Date().timeIntervalSince1970 <= 60 else { return }
                if incomingInvitation?.roomID != config.roomID { invitationBegan = Date() }
                incomingInvitation = config; boundLocalIdentity = local
                status = "收到大富翁邀请；接受后加入同一局，不会覆盖单机存档"
                startMonitoring()
            case .accept:
                if let pending = outgoingInvitation, pending.roomID == packet.roomID,
                   pending.guestIdentityID == authenticatedPeer,
                   Date().timeIntervalSince(invitationBegan) <= 120 {
                    try createGame(pending); outgoingInvitation = nil; isGamePresented = true
                }
                guard configuration?.roomID == packet.roomID,
                      configuration?.guestIdentityID == authenticatedPeer,
                      configuration?.hostIdentityID == local else { return }
                lastHeard = Date(); peerLeft = false
                gameModel?.setNetworkAvailability(false, message: "对方已接受，正在核对两端进度")
                if foreground {
                    gameModel?.sendNetworkStatus()
                    gameModel?.requestNetworkSync()
                }
            case .decline:
                guard outgoingInvitation?.roomID == packet.roomID,
                      outgoingInvitation?.guestIdentityID == authenticatedPeer else { return }
                outgoingInvitation = nil; status = "对方拒绝了邀请"
            default:
                guard let config = configuration, packet.roomID == config.roomID,
                      authenticatedPeer == peer(for: config, local: local) else { return }
                lastHeard = Date()
                guard foreground else {
                    gameModel?.setNetworkAvailability(false, message: "后台暂停，回到前台后重新同步")
                    return
                }
                if authenticatedPeer == config.hostIdentityID { waitingForHostAcceptance = false }
                if packet.kind == .leave { peerLeft = true }
                gameModel?.receiveNetworkPacket(packet, from: authenticatedPeer)
                if gameModel?.networkReady == true { lastError = nil }
                status = gameModel?.networkStatus ?? ""
            }
        } catch { lastError = "收到无效或不兼容的联机数据，已忽略；未更改对局。" }
    }

    private func createGame(_ config: VeilopolyRoomConfiguration, restoring: Bool = false) throws {
        guard let local = localIdentity(), config.isValid, config.seat(for: local) != nil else {
            throw VeilopolyRoomError.invalidConfiguration
        }
        let peer = peer(for: config, local: local)
        let game = try GameSessionModel(multiplayer: config, localIdentityID: local,
            requiresExistingSave: restoring && local == config.hostIdentityID) { [weak self] packet in
            self?.enqueue(packet, to: peer)
        }
        configuration = config; boundLocalIdentity = local; peerLeft = false; gameModel = game
        // The lobby can be backgrounded while constructing/restoring a room.
        // Keep the game reducer's lifecycle gate aligned with the bridge gate.
        game.setNetworkForeground(foreground)
        lastHeard = Date(); lastError = nil
        persistResumeRecord(config, local: local)
        startMonitoring()
    }

    func restoreIfNeeded() {
        guard gameModel == nil, incomingInvitation == nil, outgoingInvitation == nil,
              let local = localIdentity(), FileManager.default.fileExists(atPath: resumeURL.path) else { return }
        do {
            guard let size = try resumeURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 16_384 else { throw VeilopolyRoomError.invalidConfiguration }
            let bytes = try Data(contentsOf: resumeURL)
            let record = try JSONDecoder().decode(VeilopolyRoomResumeRecord.self, from: bytes)
            guard record.isValid(for: local) else { throw VeilopolyRoomError.invalidConfiguration }
            try createGame(record.configuration, restoring: true)
            waitingForHostAcceptance = local == record.configuration.guestIdentityID
            status = "已恢复本地联机断点，等待同一对手上线核对；不会自行变成房主"
            gameModel?.requestNetworkSync()
        } catch { lastError = "联机房间记录无法恢复，已保留文件；未覆盖单机存档。" }
    }

    private func persistResumeRecord(_ config: VeilopolyRoomConfiguration, local: String) {
        do {
            try FileManager.default.createDirectory(at: resumeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(VeilopolyRoomResumeRecord(configuration: config, localIdentityID: local))
                .write(to: resumeURL, options: .atomic)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: resumeURL.path)
        } catch { lastError = "联机房间索引保存失败，请不要强制退出；对局存档状态另见游戏内提示。" }
    }

    func leaveRoom() {
        let active = configuration ?? outgoingInvitation
        let removeResumeIndex = configuration != nil
        senderTask?.cancel(); senderTask = nil; senderGeneration = UUID(); outgoing = []
        if let active, let local = localIdentity() {
            enqueue(.init(roomID: active.roomID, kind: .leave), to: peer(for: active, local: local))
        }
        gameModel?.flushSave()
        gameModel = nil; configuration = nil; incomingInvitation = nil; outgoingInvitation = nil
        isGamePresented = false; waitingForHostAcceptance = false
        monitorTask?.cancel(); monitorTask = nil
        // Explicit room leave clears only its resume INDEX, never A/B game saves.
        if removeResumeIndex && FileManager.default.fileExists(atPath: resumeURL.path) {
            do { try FileManager.default.removeItem(at: resumeURL) }
            catch { lastError = "房间已退出，但恢复索引未清除；下次打开请核对房间。" }
        }
        status = "已离开房间；原 A/B 对局记录保留"
    }

    func setForeground(_ active: Bool) {
        foreground = active
        // Model.setNetworkForeground owns save/pause and blocks packet commits.
        // A bridge-only flag would leave a room playable in the background.
        gameModel?.setNetworkForeground(active)
        if active {
            lastHeard = Date()
            gameModel?.requestNetworkSync()
        }
    }

    func reconnectAndSync() {
        guard let config = configuration, let local = localIdentity() else { return }
        let peer = peer(for: config, local: local)
        if VeilopolyRoomLinkPolicy.shouldRequestSecureRecovery(
            secureSessionReady: sessions.hasSecureSession(for: peer), userInitiated: true) {
            _ = sessions.recoverSecureSession(for: peer)
        }
        gameModel?.requestNetworkSync()
    }

    private func peer(for config: VeilopolyRoomConfiguration, local: String) -> String {
        local == config.hostIdentityID ? config.guestIdentityID : config.hostIdentityID
    }

    private func enqueue(_ packet: VeilopolyRoomPacket, to peer: String) {
        guard packet.isValid else { return }
        if packet.kind == .resync {
            guard Date().timeIntervalSince(lastSyncSent) >= 3 else { return }
            lastSyncSent = Date()
        }
        if [.status, .snapshot, .resync].contains(packet.kind),
           outgoing.contains(where: { $0.peer == peer && $0.packet.kind == packet.kind }) { return }
        guard outgoing.count < 128 else {
            gameModel?.setNetworkAvailability(false, message: "同步队列已满，已暂停；请重新同步")
            return
        }
        outgoing.append(Outbound(peer: peer, packet: packet))
        guard senderTask == nil else { return }
        let generation = senderGeneration
        senderTask = Task { @MainActor [weak self] in await self?.drain(generation: generation) }
    }

    private func drain(generation: UUID) async {
        defer { if generation == senderGeneration { senderTask = nil } }
        while !outgoing.isEmpty && !Task.isCancelled && generation == senderGeneration {
            let item = outgoing.removeFirst()
            do {
                let fragments = try VeilopolyControlCodec.fragments(item.packet)
                for fragment in fragments {
                    guard !Task.isCancelled, generation == senderGeneration,
                          localIdentity() == boundLocalIdentity else { return }
                    let created = item.packet.kind == .invite ? invitationBegan.timeIntervalSince1970 : Date().timeIntervalSince1970
                    let event = VeilControlEvent(topic: VeilopolyControlCodec.topic,
                        payload: try JSONEncoder().encode(fragment), createdAt: created)
                    // Verify actual nested JSON/base64 budget before touching transport.
                    guard try VeilControlEventCodec.encode(event).count <= 2_048 else {
                        throw VeilopolyRoomError.invalidPacket
                    }
                    var sent = false
                    for _ in 0..<50 {
                        guard foreground, sessions.hasSecureSession(for: item.peer) else {
                            throw VeilopolyRoomError.wrongPeer
                        }
                        switch sessions.sendControlEvent(event, to: item.peer) {
                        case .accepted: sent = true
                        case .unsupportedLink: throw VeilopolyRoomError.invalidPacket
                        case .temporarilyUnavailable: break
                        }
                        if sent { break }
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                    guard sent else { throw VeilopolyRoomError.sequenceGap }
                    try await Task.sleep(nanoseconds: 20_000_000)
                }
            } catch {
                if Task.isCancelled || generation != senderGeneration { return }
                outgoing = [] // Authoritative state is saved; recovery sends a NEW snapshot, not stale moves.
                status = "加密控制通道暂不可用，已暂停；请确认两端支持后重连并同步"
                lastError = status
                gameModel?.setNetworkAvailability(false, message: status)
                return
            }
        }
    }

    private func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                guard let self else { return }
                self.tick()
            }
        }
    }
    private func tick() {
        guard boundLocalIdentity == localIdentity() else { suspendForIdentityChange(); return }
        guard foreground else { return }
        if (incomingInvitation != nil || outgoingInvitation != nil), Date().timeIntervalSince(invitationBegan) > 120 {
            incomingInvitation = nil; outgoingInvitation = nil; status = "邀请已过期，请重新邀请"
        }
        if let invite = outgoingInvitation, Date().timeIntervalSince(lastInviteSent) >= 10 {
            lastInviteSent = Date()
            enqueue(.init(roomID: invite.roomID, kind: .invite, configuration: invite), to: invite.guestIdentityID)
        }
        if gameModel == nil && incomingInvitation == nil && outgoingInvitation == nil {
            monitorTask?.cancel(); monitorTask = nil
            return
        }
        guard let config = configuration, let local = localIdentity(), !peerLeft else { return }
        let peer = peer(for: config, local: local)
        if VeilopolyRoomLinkPolicy.shouldPauseGame(secureSessionReady: sessions.hasSecureSession(for: peer),
            secondsSincePeer: Date().timeIntervalSince(lastHeard)) {
            gameModel?.setNetworkAvailability(false, message: "等待对方重连／同步；不会代替真人操作")
            // recoverSecureSession removes/reseeds the shared security context.
            // Do NOT call it from a game timer: chat may still be healthy.
        }
        if waitingForHostAcceptance {
            enqueue(.init(roomID: config.roomID, kind: .accept), to: config.hostIdentityID)
        }
        gameModel?.sendNetworkStatus()
        // A lost proposal leaves equal hashes but an outstanding client request.
        // Request a definitive snapshot even then; never infer execution from a heartbeat.
        if gameModel?.networkReady == false || gameModel?.awaitingHost == true { gameModel?.requestNetworkSync() }
    }
    private func suspendForIdentityChange() {
        gameModel?.flushSave()
        gameModel?.setNetworkAvailability(false, message: "本机身份已切换，原联机房间暂停")
        senderTask?.cancel(); senderTask = nil; senderGeneration = UUID(); outgoing = []
        monitorTask?.cancel(); monitorTask = nil
        isGamePresented = false
        gameModel = nil; configuration = nil; incomingInvitation = nil; outgoingInvitation = nil
        boundLocalIdentity = nil
    }
}
