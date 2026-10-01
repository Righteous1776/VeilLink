import Combine
import Foundation

enum CollaborativeStressState: String, Codable, CaseIterable, Sendable {
    case idle
    case inviting
    case invitationReceived
    case ready
    case running
    case stopping
    case completed
    case failed
}

enum CollaborativeStressRole: String, Codable, Sendable {
    case coordinator
    case participant
}

struct CollaborativeStressMetrics: Codable, Equatable, Sendable {
    var sentFrames = 0
    var receivedFrames = 0
    var sentBytes = 0
    var receivedBytes = 0
    var temporaryUnavailableCount = 0
    var unsupportedLinkCount = 0
    var droppedFrames = 0
    var bulkTransfersSent = 0
    var bulkTransfersReceived = 0
    var bulkTransfersVerified = 0
    var bulkTransfersFailed = 0
    var gamePacketsSent = 0
    var gamePacketsReceived = 0
    var gamePacketsRejected = 0
    var pingSamples = 0
    var pingLatencyTotalMilliseconds = 0
    var localCompleted = false
    var remoteCompleted = false

    var averagePingMilliseconds: Int? {
        guard pingSamples > 0 else { return nil }
        return pingLatencyTotalMilliseconds / pingSamples
    }
}

struct CollaborativeStressSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let state: CollaborativeStressState
    let role: CollaborativeStressRole?
    let sessionID: String?
    let epoch: UInt64
    let peerIdentityID: String?
    let scenario: CollaborativeStressScenario
    let metrics: CollaborativeStressMetrics
    let stopReason: String?
}

@MainActor
final class CollaborativeStressCoordinator: ObservableObject {
    static let shared = CollaborativeStressCoordinator()

    @Published private(set) var state: CollaborativeStressState = .idle
    @Published private(set) var role: CollaborativeStressRole?
    @Published private(set) var sessionID: String?
    @Published private(set) var epoch: UInt64 = 0
    @Published private(set) var peerIdentityID: String?
    @Published private(set) var pendingInvitation: CollaborativeStressFrame?
    @Published private(set) var pendingInvitationPeerID: String?
    @Published private(set) var metrics = CollaborativeStressMetrics()
    @Published private(set) var lastError: String?
    @Published private(set) var stopReason: String?
    @Published var scenario = CollaborativeStressScenario()

    private weak var model: AppModel?
    private var runTask: Task<Void, Never>?
    private var nextOrdinal: UInt64 = 1
    private var pendingPingStartedAt: [UInt64: TimeInterval] = [:]
    private var bulkReadyTransfers = Set<String>()
    private var gameStates: [String: GomokuState] = [:]
    private var didAttach = false
    private var localCompletionSent = false

    private init() {}

    func attach(model: AppModel) {
        self.model = model
        guard !didAttach else { return }
        didAttach = true
        model.sessions.onCollaborativeStressFrame = { [weak self] frame, peer in
            Task { @MainActor in self?.receive(frame: frame, from: peer) }
        }
        model.sessions.onCollaborativeStressBulkReceipt = { [weak self] receipt, peer in
            Task { @MainActor in self?.receiveBulkReceipt(receipt, from: peer) }
        }
    }

    func invite(peerIdentityID: String) {
        guard let model else { return }
        guard !peerIdentityID.isEmpty, model.sessions.hasSecureSession(for: peerIdentityID) else {
            fail(CollaborativeStressError.noSecurePeer.localizedDescription)
            return
        }
        resetRuntimeState(keepScenario: true)
        self.peerIdentityID = peerIdentityID
        role = .coordinator
        state = .inviting
        sessionID = UUID().uuidString
        epoch = max(1, UInt64((Date().timeIntervalSince1970 * 1_000).rounded()))
        metrics = CollaborativeStressMetrics()
        stopReason = nil
        let frame = makeFrame(
            .invite,
            scenario: scenario.normalized,
            metadata: [
                "channel": "EPHEMERAL_STRESS_ONLY",
                "database": "BYPASS_REAL_CONVERSATION_STORE",
                "code": String((sessionID ?? "------").prefix(6)).uppercased()
            ]
        )
        send(frame)
        log(.info, "stress.collab.invite.sent", ["peer": fingerprint(peerIdentityID)])
    }

    func acceptPendingInvitation() {
        guard let invitation = pendingInvitation,
              let peer = pendingInvitationPeerID,
              let model,
              model.sessions.hasSecureSession(for: peer) else {
            fail(CollaborativeStressError.noSecurePeer.localizedDescription)
            return
        }
        resetRuntimeState(keepScenario: true)
        sessionID = invitation.sessionID
        epoch = invitation.epoch
        scenario = (invitation.scenario ?? CollaborativeStressScenario()).normalized
        peerIdentityID = peer
        role = .participant
        state = .ready
        metrics = CollaborativeStressMetrics()
        pendingInvitation = nil
        pendingInvitationPeerID = nil
        send(makeFrame(.accept, metadata: ["code": String(invitation.sessionID.prefix(6)).uppercased()]))
        log(.info, "stress.collab.invite.accepted", ["peer": fingerprint(peer)])
    }

    func declinePendingInvitation() {
        guard let invitation = pendingInvitation, let peer = pendingInvitationPeerID else { return }
        sessionID = invitation.sessionID
        epoch = invitation.epoch
        peerIdentityID = peer
        role = .participant
        send(makeFrame(.decline))
        pendingInvitation = nil
        pendingInvitationPeerID = nil
        resetRuntimeState(keepScenario: true)
        log(.info, "stress.collab.invite.declined", ["peer": fingerprint(peer)])
    }

    func stop(reason: String = "user_stop") {
        guard state != .idle else { return }
        stopReason = reason
        if state == .running || state == .ready || state == .inviting {
            send(makeFrame(.stop, metadata: ["reason": reason]))
        }
        state = .stopping
        runTask?.cancel()
        runTask = nil
        completeIfPossible(force: true)
    }

    func handleSceneActive(_ active: Bool) {
        guard !active, state == .running || state == .ready || state == .inviting else { return }
        stop(reason: "app_left_foreground")
    }

    func noteMemoryWarning() {
        guard state == .running else { return }
        log(.warning, "stress.collab.memory_warning", [:])
        stop(reason: "memory_warning")
    }

    func snapshotData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot())
    }

    func snapshot() -> CollaborativeStressSnapshot {
        CollaborativeStressSnapshot(
            generatedAt: Date(),
            state: state,
            role: role,
            sessionID: sessionID,
            epoch: epoch,
            peerIdentityID: peerIdentityID.map(fingerprint),
            scenario: scenario.normalized,
            metrics: metrics,
            stopReason: stopReason
        )
    }

    private func receive(frame: CollaborativeStressFrame, from peer: String) {
        metrics.receivedFrames += 1
        metrics.receivedBytes += estimatedFrameBytes(frame)

        if frame.kind == .invite {
            guard state == .idle || state == .completed || state == .failed else {
                // Busy devices decline rather than allowing two stress sessions to overlap.
                let previousSession = sessionID
                let previousEpoch = epoch
                let previousPeer = peerIdentityID
                sessionID = frame.sessionID
                epoch = frame.epoch
                peerIdentityID = peer
                role = .participant
                send(makeFrame(.decline, metadata: ["reason": "busy"]))
                sessionID = previousSession
                epoch = previousEpoch
                peerIdentityID = previousPeer
                return
            }
            pendingInvitation = frame
            pendingInvitationPeerID = peer
            state = .invitationReceived
            log(.info, "stress.collab.invite.received", ["peer": fingerprint(peer)])
            return
        }

        guard frame.sessionID == sessionID,
              frame.epoch == epoch,
              peer == peerIdentityID else {
            log(.warning, "stress.collab.frame.session_mismatch", ["peer": fingerprint(peer), "kind": frame.kind.rawValue])
            return
        }

        switch frame.kind {
        case .accept:
            guard role == .coordinator, state == .inviting || state == .ready else { return }
            state = .ready
            let start = makeFrame(.start, scenario: scenario.normalized)
            send(start)
            startLocalScenarioIfNeeded()
        case .decline:
            stopReason = frame.metadata["reason"] ?? "remote_decline"
            state = .failed
            runTask?.cancel()
            runTask = nil
        case .start:
            guard role == .participant else { return }
            scenario = (frame.scenario ?? scenario).normalized
            state = .ready
            startLocalScenarioIfNeeded()
        case .stop:
            stopReason = frame.metadata["reason"] ?? "remote_stop"
            runTask?.cancel()
            runTask = nil
            completeIfPossible(force: true)
        case .ping:
            let replyTo = frame.ordinal
            send(makeFrame(.pong, metadata: ["reply_to": String(replyTo)]))
        case .pong:
            if let raw = frame.metadata["reply_to"], let reply = UInt64(raw), let started = pendingPingStartedAt.removeValue(forKey: reply) {
                metrics.pingSamples += 1
                metrics.pingLatencyTotalMilliseconds += max(0, Int((ProcessInfo.processInfo.systemUptime - started) * 1_000))
            }
        case .textBurst:
            break
        case .bulkBegin:
            metrics.bulkTransfersReceived += 1
            if let transferID = frame.transferID, let wireMessageID = frame.wireMessageID {
                let ready = makeFrame(
                    .bulkReady,
                    transferID: transferID,
                    wireMessageID: wireMessageID,
                    success: true,
                    metadata: ["stage": "accumulator_ready"]
                )
                if case .accepted = send(ready) {} else { metrics.droppedFrames += 1 }
            }
        case .bulkReady:
            if let transferID = frame.transferID {
                bulkReadyTransfers.insert(transferID)
            }
        case .bulkReceipt:
            if frame.success == true { metrics.bulkTransfersVerified += 1 } else { metrics.bulkTransfersFailed += 1 }
        case .gameReset:
            if let gameID = frame.metadata["game_session"] {
                gameStates[gameID] = GomokuState()
            }
        case .gamePacket:
            handleGamePacket(frame)
        case .localComplete:
            metrics.remoteCompleted = true
            completeIfPossible(force: false)
        case .invite:
            break
        }
    }

    private func receiveBulkReceipt(_ receipt: CollaborativeStressBulkReceipt, from peer: String) {
        guard receipt.sessionID == sessionID, receipt.epoch == epoch, peer == peerIdentityID else { return }
        metrics.receivedBytes += receipt.byteCount
        if receipt.success { metrics.bulkTransfersVerified += 1 } else { metrics.bulkTransfersFailed += 1 }
        let frame = makeFrame(
            .bulkReceipt,
            payloadKind: receipt.payloadKind,
            transferID: receipt.transferID,
            wireMessageID: receipt.wireMessageID,
            byteCount: receipt.byteCount,
            chunkCount: receipt.chunkCount,
            sha256Hex: receipt.actualSHA256,
            success: receipt.success,
            metadata: ["duration_ms": String(receipt.durationMilliseconds)]
        )
        send(frame)
    }

    private func startLocalScenarioIfNeeded() {
        guard runTask == nil, state == .ready else { return }
        state = .running
        metrics.localCompleted = false
        metrics.remoteCompleted = false
        localCompletionSent = false
        let config = scenario.normalized
        log(.info, "stress.collab.session.begin", scenarioMetadata(config))
        runTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runScenario(config)
        }
    }

    private func runScenario(_ config: CollaborativeStressScenario) async {
        if config.enableText {
            for index in 0..<config.textBurstCount {
                guard !Task.isCancelled else { return }
                let payload = CollaborativeStressPayloadFactory.text(
                    bytes: config.textPayloadBytes,
                    seed: UInt64(index + 1) ^ epoch
                )
                switch send(makeFrame(.textBurst, payloadText: payload, metadata: ["index": String(index)])) {
                case .accepted: break
                case .temporarilyUnavailable, .unsupportedLink: metrics.droppedFrames += 1
                }
                if index % 24 == 0 {
                    let ping = makeFrame(.ping)
                    pendingPingStartedAt[ping.ordinal] = ProcessInfo.processInfo.systemUptime
                    switch send(ping) {
                    case .accepted: break
                    case .temporarilyUnavailable, .unsupportedLink:
                        pendingPingStartedAt.removeValue(forKey: ping.ordinal)
                        metrics.droppedFrames += 1
                    }
                }
                await sleep(config.interFrameDelayMilliseconds)
            }
        }

        if config.enableImages {
            for index in 0..<config.imageTransferCount {
                guard !Task.isCancelled else { return }
                let data = CollaborativeStressPayloadFactory.binary(
                    bytes: config.imagePayloadBytes,
                    seed: 0x494D_4700 ^ UInt64(index) ^ epoch
                )
                await sendBulk(data, kind: .syntheticImage, label: "image-\(index)", delayMilliseconds: config.interFrameDelayMilliseconds)
            }
        }

        if config.enableVoice {
            for index in 0..<config.voiceTransferCount {
                guard !Task.isCancelled else { return }
                let data = CollaborativeStressPayloadFactory.syntheticVoiceWAV(
                    bytes: config.voicePayloadBytes,
                    seed: 0x564F_4943 ^ UInt64(index) ^ epoch
                )
                await sendBulk(data, kind: .synthesizedVoice, label: "voice-\(index)", delayMilliseconds: config.interFrameDelayMilliseconds)
            }
        }

        if config.enableGame {
            await runGameLane(moveCount: config.gameMoveCount, delayMilliseconds: config.interFrameDelayMilliseconds)
        }

        metrics.localCompleted = true
        if !localCompletionSent {
            localCompletionSent = true
            send(makeFrame(.localComplete))
        }
        log(.info, "stress.collab.local_complete", metricsMetadata())
        completeIfPossible(force: false)
    }

    private func runGameLane(moveCount: Int, delayMilliseconds: Int) async {
        guard moveCount > 0 else { return }
        var state = GomokuState()
        var gameID = UUID().uuidString
        if case .accepted = send(makeFrame(.gameReset, metadata: ["game_session": gameID])) {} else { metrics.droppedFrames += 1 }
        var seed = epoch ^ 0x4741_4D45

        for turn in 0..<moveCount {
            guard !Task.isCancelled else { return }
            if state.winner != nil || state.isDraw {
                state = GomokuState()
                gameID = UUID().uuidString
                if case .accepted = send(makeFrame(.gameReset, metadata: ["game_session": gameID])) {} else { metrics.droppedFrames += 1 }
            }
            let actor = state.currentPlayer
            var candidate = Int(seed % UInt64(GomokuState.size * GomokuState.size))
            var probes = 0
            while state.value(at: candidate) != 0, probes < GomokuState.size * GomokuState.size {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                candidate = Int(seed % UInt64(GomokuState.size * GomokuState.size))
                probes += 1
            }
            guard state.apply(index: candidate, actor: actor) else { continue }
            let packet = MiniGamePacket(
                sessionID: gameID,
                game: .gomoku,
                command: .move,
                turn: max(0, state.moveCount - 1),
                move: .gomoku(index: candidate)
            )
            do {
                let wire = try MiniGameCodec.encode(packet)
                switch send(makeFrame(.gamePacket, gameWire: wire, metadata: ["game_session": gameID])) {
                case .accepted: metrics.gamePacketsSent += 1
                case .temporarilyUnavailable, .unsupportedLink: metrics.droppedFrames += 1
                }
            } catch {
                metrics.gamePacketsRejected += 1
            }
            seed = seed &* 2862933555777941757 &+ 3037000493
            await sleep(delayMilliseconds)
        }
    }

    private func handleGamePacket(_ frame: CollaborativeStressFrame) {
        guard let wire = frame.gameWire,
              let packet = MiniGameCodec.decode(wire),
              packet.game == .gomoku,
              packet.command == .move,
              let index = packet.move?.to else {
            metrics.gamePacketsRejected += 1
            return
        }
        var state = gameStates[packet.sessionID] ?? GomokuState()
        let actor = packet.turn.isMultiple(of: 2) ? MiniGamePlayer.host : MiniGamePlayer.guest
        if state.apply(index: index, actor: actor) {
            gameStates[packet.sessionID] = state
            metrics.gamePacketsReceived += 1
        } else {
            metrics.gamePacketsRejected += 1
        }
    }

    private func sendBulk(_ data: Data, kind: CollaborativeStressPayloadKind, label: String, delayMilliseconds: Int) async {
        guard let model, let peer = peerIdentityID, let activeSession = sessionID else { return }
        let transferID = UUID().uuidString
        let wireMessageID = UUID().uuidString
        let chunkCount = max(1, Int(ceil(Double(data.count) / Double(CollaborativeStressCodec.bulkChunkBytes))))
        let digest = CollaborativeStressPayloadFactory.sha256Hex(data)
        let beginFrame = makeFrame(
            .bulkBegin,
            payloadKind: kind,
            transferID: transferID,
            wireMessageID: wireMessageID,
            byteCount: data.count,
            chunkCount: chunkCount,
            sha256Hex: digest,
            metadata: ["label": label]
        )
        // Local BLE acceptance is not enough: chunks must not start until the peer confirms
        // that its in-memory stress accumulator exists. Otherwise a lost manifest followed by a
        // delivered attachmentChunk could fall through toward the production attachment path.
        bulkReadyTransfers.remove(transferID)
        var remoteReady = false
        var manifestAttempts = 0
        while manifestAttempts < 20, !remoteReady {
            guard !Task.isCancelled, self.sessionID == activeSession else { return }
            switch send(beginFrame) {
            case .accepted:
                manifestAttempts += 1
                for _ in 0..<5 {
                    await sleep(max(20, delayMilliseconds))
                    if bulkReadyTransfers.remove(transferID) != nil {
                        remoteReady = true
                        break
                    }
                }
            case .temporarilyUnavailable:
                manifestAttempts += 1
                await sleep(max(20, delayMilliseconds))
            case .unsupportedLink:
                metrics.bulkTransfersFailed += 1
                metrics.droppedFrames += 1
                return
            }
        }
        guard remoteReady else {
            metrics.bulkTransfersFailed += 1
            metrics.droppedFrames += 1
            log(.warning, "stress.collab.bulk.remote_ready_timeout", ["transfer": String(transferID.prefix(8))])
            return
        }
        metrics.bulkTransfersSent += 1

        for index in 0..<chunkCount {
            guard !Task.isCancelled else { return }
            let lower = index * CollaborativeStressCodec.bulkChunkBytes
            let upper = min(lower + CollaborativeStressCodec.bulkChunkBytes, data.count)
            let chunk = Data(data[lower..<upper])
            var attempts = 0
            var accepted = false
            while attempts < 40, !accepted {
                guard self.sessionID == activeSession else { return }
                let result = model.sessions.sendCollaborativeStressBulkChunk(
                    sessionID: activeSession,
                    epoch: epoch,
                    transferID: transferID,
                    wireMessageID: wireMessageID,
                    index: index,
                    total: chunkCount,
                    bytes: chunk,
                    to: peer
                )
                switch result {
                case .accepted:
                    metrics.sentBytes += chunk.count
                    accepted = true
                case .temporarilyUnavailable:
                    metrics.temporaryUnavailableCount += 1
                    attempts += 1
                    await sleep(max(12, delayMilliseconds))
                case .unsupportedLink:
                    metrics.unsupportedLinkCount += 1
                    metrics.bulkTransfersFailed += 1
                    return
                }
            }
            guard accepted else {
                metrics.bulkTransfersFailed += 1
                log(.warning, "stress.collab.bulk.backpressure_exhausted", ["transfer": String(transferID.prefix(8)), "chunk": String(index)])
                return
            }
            await sleep(max(8, delayMilliseconds / 2))
        }
    }

    @discardableResult
    private func send(_ frame: CollaborativeStressFrame) -> TransportSendResult {
        guard let model, let peer = peerIdentityID else { return .temporarilyUnavailable }
        let result = model.sessions.sendCollaborativeStressFrame(frame, to: peer)
        switch result {
        case .accepted:
            metrics.sentFrames += 1
            metrics.sentBytes += estimatedFrameBytes(frame)
        case .temporarilyUnavailable:
            metrics.temporaryUnavailableCount += 1
        case .unsupportedLink:
            metrics.unsupportedLinkCount += 1
        }
        if metrics.sentFrames > 0, metrics.sentFrames % 50 == 0 {
            log(.debug, "stress.collab.progress", metricsMetadata())
        }
        return result
    }

    private func makeFrame(
        _ kind: CollaborativeStressFrameKind,
        scenario: CollaborativeStressScenario? = nil,
        payloadText: String? = nil,
        payloadKind: CollaborativeStressPayloadKind? = nil,
        transferID: String? = nil,
        wireMessageID: String? = nil,
        byteCount: Int? = nil,
        chunkCount: Int? = nil,
        sha256Hex: String? = nil,
        gameWire: String? = nil,
        success: Bool? = nil,
        metadata: [String: String] = [:]
    ) -> CollaborativeStressFrame {
        let frame = CollaborativeStressFrame(
            sessionID: sessionID ?? UUID().uuidString,
            epoch: max(1, epoch),
            ordinal: nextOrdinal,
            kind: kind,
            scenario: scenario,
            payloadText: payloadText,
            payloadKind: payloadKind,
            transferID: transferID,
            wireMessageID: wireMessageID,
            byteCount: byteCount,
            chunkCount: chunkCount,
            sha256Hex: sha256Hex,
            gameWire: gameWire,
            success: success,
            metadata: metadata
        )
        nextOrdinal &+= 1
        return frame
    }

    private func completeIfPossible(force: Bool) {
        guard force || (metrics.localCompleted && metrics.remoteCompleted) else { return }
        state = .completed
        runTask?.cancel()
        runTask = nil
        log(.info, "stress.collab.session.end", metricsMetadata().merging(["reason": stopReason ?? "completed"]) { _, rhs in rhs })
    }

    private func resetRuntimeState(keepScenario: Bool) {
        runTask?.cancel()
        runTask = nil
        role = nil
        sessionID = nil
        epoch = 0
        peerIdentityID = nil
        pendingInvitation = nil
        pendingInvitationPeerID = nil
        metrics = CollaborativeStressMetrics()
        lastError = nil
        stopReason = nil
        nextOrdinal = 1
        pendingPingStartedAt.removeAll()
        bulkReadyTransfers.removeAll()
        gameStates.removeAll()
        localCompletionSent = false
        if !keepScenario { scenario = CollaborativeStressScenario() }
        state = .idle
    }

    private func fail(_ message: String?) {
        lastError = message ?? "协同压力测试失败。"
        stopReason = "error"
        state = .failed
        log(.error, "stress.collab.failed", ["reason": lastError ?? "unknown"])
    }

    private func estimatedFrameBytes(_ frame: CollaborativeStressFrame) -> Int {
        (try? CollaborativeStressCodec.encode(frame).lengthOfBytes(using: .utf8)) ?? 0
    }

    private func scenarioMetadata(_ config: CollaborativeStressScenario) -> [String: String] {
        [
            "session": sessionID ?? "-",
            "epoch": String(epoch),
            "role": role?.rawValue ?? "-",
            "text": String(config.enableText),
            "images": String(config.enableImages),
            "voice": String(config.enableVoice),
            "game": String(config.enableGame),
            "text_count": String(config.textBurstCount),
            "text_bytes": String(config.textPayloadBytes),
            "image_bytes": String(config.imagePayloadBytes),
            "voice_bytes": String(config.voicePayloadBytes),
            "game_moves": String(config.gameMoveCount)
        ]
    }

    private func metricsMetadata() -> [String: String] {
        [
            "session": sessionID ?? "-",
            "epoch": String(epoch),
            "state": state.rawValue,
            "sent_frames": String(metrics.sentFrames),
            "recv_frames": String(metrics.receivedFrames),
            "sent_bytes": String(metrics.sentBytes),
            "recv_bytes": String(metrics.receivedBytes),
            "backpressure": String(metrics.temporaryUnavailableCount),
            "unsupported": String(metrics.unsupportedLinkCount),
            "dropped_frames": String(metrics.droppedFrames),
            "bulk_verified": String(metrics.bulkTransfersVerified),
            "bulk_failed": String(metrics.bulkTransfersFailed),
            "game_sent": String(metrics.gamePacketsSent),
            "game_recv": String(metrics.gamePacketsReceived),
            "game_rejected": String(metrics.gamePacketsRejected),
            "ping_avg_ms": metrics.averagePingMilliseconds.map(String.init) ?? "-"
        ]
    }

    private func fingerprint(_ value: String) -> String {
        String(value.prefix(8)).uppercased()
    }

    private func log(_ level: DiagnosticLogLevel, _ event: String, _ metadata: [String: String]) {
        DiagnosticLogStore.shared.log(level, .stress, event: event, screen: DeepTelemetry.shared.currentScreen, metadata: metadata)
    }

    private func sleep(_ milliseconds: Int) async {
        guard milliseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}
