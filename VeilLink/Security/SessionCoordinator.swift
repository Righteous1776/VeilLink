import Combine
import CryptoKit
import Foundation

private enum WireProtocol {
    static let version = 4
    static let maximumEnvelopeBytes = 96_000
    static let maximumTextBytes = 16_384
    static let maximumImageBytes = MediaTransferPolicy.maximumImageBytes
    static let maximumVoiceBytes = VoiceMessageCodec.maximumBytes
    static let attachmentChunkBytes = 48 * 1_024
    static let maximumDisplayNameBytes = 128
}

private struct WireAcknowledgement: Codable { let messageID: String }

private struct WireChatContent: Codable {
    enum Kind: String, Codable { case text, image, voice }
    let kind: Kind
    let text: String?
    let attachment: Data?
    let mimeType: String?
    let sentAt: Date
    let attachmentByteCount: Int?
    let attachmentSHA256: Data?
    let attachmentChunkCount: Int?
}

private struct HelloPacket: Codable, Equatable {
    let protocolVersion: Int
    let identityID: String
    let displayName: String
    let identityPublicKey: Data
    let agreementPublicKey: Data
    let nonce: Data
    let signature: Data

    var signedPayload: Data {
        var value = Data("VeilLink/Hello/v4|\(protocolVersion)|\(identityID)|\(displayName)|".utf8)
        value.append(identityPublicKey); value.append(agreementPublicKey); value.append(nonce)
        return value
    }
}

private struct SessionContext {
    let transportID: UUID
    let localEphemeral: Curve25519.KeyAgreement.PrivateKey
    let localHello: HelloPacket
    var remoteHello: HelloPacket?
    var keys: SessionKeyMaterial?
    var replayWindow = ReplayWindow()
    var nextSendSequence: UInt64 = 1
}

@MainActor
final class SessionCoordinator: ObservableObject {
    @Published private(set) var nearbyPeers: [NearbyPeer] = []
    @Published var lastError: String?
    @Published private(set) var securityEvents: [String] = []

    var transportSend: ((UUID, Data, BLESendPriority) -> TransportSendResult)?
    var transportDisconnect: ((UUID) -> Void)?
    var onMessagesChanged: ((Bool) -> Void)?
    var onInboundAttachmentCompleted: ((String) -> Void)?
    var onInboundMessageReceived: (() -> Void)?
    var onDeliveryConfirmed: (() -> Void)?
    var onPTTControl: ((VeilPTTIncomingControl) -> Void)?
    var onPTTAudioFrame: ((VeilPTTIncomingAudio) -> Void)?

    private let identity: IdentityManager
    private let database: DatabaseStore
    private var sessions: [UUID: SessionContext] = [:]
    private var peerTransport: [String: UUID] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private struct CachedOutboundAttachment {
        let attachmentID: String
        let data: Data
        let sha256: Data
    }
    private var outboundAttachmentCache: [String: CachedOutboundAttachment] = [:]
    private var outboundAttachmentCacheOrder: [String] = []
    private var outboundAttachmentCacheBytes = 0
    private var maximumOutboundAttachmentCacheBytes: Int { VeilDevicePerformance.current.outboundAttachmentCacheBytes }

    private var packetAbuseLimiter = PacketAbuseLimiter()
    private var retryTask: Task<Void, Never>?
    private var retryTaskGeneration: UInt64 = 0
    private let maintenanceTuning = VeilRuntimeMaintenanceTuning.resolved(performanceLabel: VeilDevicePerformance.current.label)
    private var handshakeTimeoutTasks: [UUID: Task<Void, Never>] = [:]
    private let handshakeRetryScheduleNanoseconds: [UInt64] = [
        1_000_000_000,
        2_000_000_000,
        4_000_000_000,
        6_000_000_000,
        8_000_000_000
    ]

    init(identity: IdentityManager, database: DatabaseStore) {
        self.identity = identity
        self.database = database
    }

    func discovered(transportID: UUID, rssi: Int) {
        pruneNearbyPeers()
        if let index = nearbyPeers.firstIndex(where: { $0.transportID == transportID }) {
            nearbyPeers[index].rssi = rssi; nearbyPeers[index].lastSeen = Date()
        } else {
            nearbyPeers.append(NearbyPeer(id: transportID.uuidString, transportID: transportID, displayName: "未认证设备", rssi: rssi, trustState: .discovered, pairingCode: nil, lastSeen: Date()))
            if nearbyPeers.count > 100 { nearbyPeers.sort { $0.lastSeen > $1.lastSeen }; nearbyPeers = Array(nearbyPeers.prefix(100)) }
        }
    }

    func clearTransientCaches() {
        clearOutboundAttachmentCache()
    }

    func connected(transportID: UUID) {
        guard sessions[transportID] == nil else { return }
        do {
            try sendHello(to: transportID)
            scheduleHandshakeTimeout(for: transportID)
        } catch {
            sessions.removeValue(forKey: transportID)
            lastError = "握手初始化失败：\(error.localizedDescription)"
        }
    }
    func disconnected(transportID: UUID) {
        cancelHandshakeTimeout(for: transportID)
        sessions.removeValue(forKey: transportID)
        packetAbuseLimiter.reset(transportID)
        peerTransport = peerTransport.filter { $0.value != transportID }
        nearbyPeers.removeAll { $0.transportID == transportID }
        if peerTransport.isEmpty {
            clearOutboundAttachmentCache()
            retryTaskGeneration &+= 1
            retryTask?.cancel()
            retryTask = nil
        }
    }

    func resetForIdentityChange() {
        cancelAllHandshakeTimeouts()
        retryTaskGeneration &+= 1
        retryTask?.cancel()
        retryTask = nil
        sessions.removeAll()
        packetAbuseLimiter.resetAll()
        peerTransport.removeAll()
        nearbyPeers.removeAll()
        clearOutboundAttachmentCache()
        lastError = nil
    }

    func invalidatePeer(_ peerIdentityID: String) {
        if let transportID = peerTransport.removeValue(forKey: peerIdentityID) {
            cancelHandshakeTimeout(for: transportID)
            sessions.removeValue(forKey: transportID)
            packetAbuseLimiter.reset(transportID)
            nearbyPeers.removeAll { $0.transportID == transportID || $0.id == peerIdentityID }
            transportDisconnect?(transportID)
        } else {
            nearbyPeers.removeAll { $0.id == peerIdentityID }
        }
    }

    func receive(transportID: UUID, data: Data) {
        guard data.count <= WireProtocol.maximumEnvelopeBytes else {
            handleInvalidPacket(transportID: transportID, reason: "超大数据包")
            return
        }
        do {
            let envelope = try WireCodec.decodeEnvelope(data)
            guard Int(envelope.version) == WireProtocol.version else { throw CryptoEngineError.invalidCiphertext }
            switch envelope.kind {
            case .hello: try handleHello(transportID: transportID, data: envelope.payload)
            case .encryptedMessage: try handleEncryptedMessage(transportID: transportID, data: envelope.payload)
            case .acknowledgement: try handleAcknowledgement(transportID: transportID, data: envelope.payload)
            case .attachmentChunk: try handleAttachmentChunk(transportID: transportID, data: envelope.payload)
            case .attachmentCheckpoint: try handleAttachmentCheckpoint(transportID: transportID, data: envelope.payload)
            case .pttControl: try handlePTTControl(transportID: transportID, data: envelope.payload)
            case .pttAudio: try handlePTTAudio(transportID: transportID, data: envelope.payload)
            }
            packetAbuseLimiter.reset(transportID)
        } catch {
            handleInvalidPacket(transportID: transportID, reason: "无法验证的数据包")
        }
    }

    func confirmPairing(peerID: String) {
        guard let index = nearbyPeers.firstIndex(where: { $0.id == peerID }), let context = sessions[nearbyPeers[index].transportID], let remote = context.remoteHello else { return }
        do {
            let localIdentityID = context.localHello.identityID
            try database.trustPeer(localIdentityID: localIdentityID, identityID: remote.identityID, displayName: remote.displayName, publicKey: remote.identityPublicKey)
            if database.conversationID(localIdentityID: localIdentityID, for: remote.identityID) == nil {
                _ = try database.createConversation(localIdentityID: localIdentityID, peerIdentityID: remote.identityID, title: remote.displayName)
            }
            nearbyPeers[index].trustState = .trusted; nearbyPeers[index].pairingCode = nil
            recordSecurityEvent("已信任 \(remote.displayName) · 身份指纹已固定"); onMessagesChanged?(true); flushOutbound(for: remote.identityID)
        } catch { lastError = error.localizedDescription }
    }

    func rejectPairing(peerID: String) {
        guard let index = nearbyPeers.firstIndex(where: { $0.id == peerID }) else { return }
        let transportID = nearbyPeers[index].transportID
        cancelHandshakeTimeout(for: transportID)
        sessions.removeValue(forKey: transportID)
        peerTransport = peerTransport.filter { $0.value != transportID }
        nearbyPeers[index].trustState = .blocked
        nearbyPeers[index].pairingCode = nil
        transportDisconnect?(transportID)
    }

    func sendMessage(_ text: String, to peerIdentityID: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lengthOfBytes(using: .utf8) <= WireProtocol.maximumTextBytes else { throw NSError(domain: "VeilLink", code: 13, userInfo: [NSLocalizedDescriptionKey: "消息为空或超过 16 KB。"]) }
        try queueContent(WireChatContent(kind: .text, text: trimmed, attachment: nil, mimeType: nil, sentAt: Date(), attachmentByteCount: nil, attachmentSHA256: nil, attachmentChunkCount: nil), preview: ReplyTextCodec.previewText(for: trimmed), to: peerIdentityID)
    }

    func sendImage(_ imageData: Data, mimeType: String, to peerIdentityID: String) throws {
        guard imageData.count <= WireProtocol.maximumImageBytes else { throw NSError(domain: "VeilLink", code: 12, userInfo: [NSLocalizedDescriptionKey: "图片处理后仍超过 3 MB。"] ) }
        guard MediaTransferPolicy.supportsImageMIMEType(mimeType) else { throw NSError(domain: "VeilLink", code: 14, userInfo: [NSLocalizedDescriptionKey: "当前传输层不支持这种图片编码。"] ) }
        try queueContent(WireChatContent(kind: .image, text: nil, attachment: imageData, mimeType: mimeType, sentAt: Date(), attachmentByteCount: nil, attachmentSHA256: nil, attachmentChunkCount: nil), preview: "[图片]", to: peerIdentityID)
    }

    func sendVoice(_ voiceData: Data, durationSeconds: Double, mimeType: String = "audio/mp4", to peerIdentityID: String) throws {
        guard voiceData.count > 0, voiceData.count <= WireProtocol.maximumVoiceBytes,
              durationSeconds >= 0.35, durationSeconds <= VoiceMessageCodec.maximumDurationSeconds,
              VoiceMessageCodec.isVoiceMIMEType(mimeType) else {
            throw NSError(domain: "VeilLink", code: 24, userInfo: [NSLocalizedDescriptionKey: "语音为空、过长或编码不受支持。"])
        }
        let metadata = VoiceMessageCodec.encode(durationSeconds: durationSeconds)
        try queueContent(
            WireChatContent(kind: .voice, text: metadata, attachment: voiceData, mimeType: mimeType, sentAt: Date(), attachmentByteCount: nil, attachmentSHA256: nil, attachmentChunkCount: nil),
            preview: VoiceMessageCodec.preview(durationSeconds: durationSeconds),
            to: peerIdentityID
        )
    }

    func retryMessage(_ messageID: String, to peerIdentityID: String) throws {
        guard let localIdentityID = identity.activeIdentity?.id,
              let message = database.fetchMessage(id: messageID),
              message.isOutgoing,
              message.deliveryState == .failed,
              message.senderIdentityID == localIdentityID,
              database.conversationID(localIdentityID: localIdentityID, for: peerIdentityID) == message.conversationID,
              database.trustedContact(localIdentityID: localIdentityID, identityID: peerIdentityID) != nil else {
            throw NSError(domain: "VeilLink", code: 15, userInfo: [NSLocalizedDescriptionKey: "这条消息当前无法重新发送。"])
        }
        try database.enqueueOutbound(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        if let attachment = message.attachment {
            let chunkCount = max(1, Int(ceil(Double(attachment.byteCount) / Double(WireProtocol.attachmentChunkBytes))))
            try database.configureOutboundAttachment(messageID: messageID, chunkCount: chunkCount)
        }
        try database.restartOutbound(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        try database.updateDelivery(messageID: messageID, state: .queued)
        onMessagesChanged?(false)
        flushOutbound(for: peerIdentityID)
    }

    func pauseImageTransfer(_ messageID: String, to peerIdentityID: String) throws {
        guard let localIdentityID = identity.activeIdentity?.id,
              let message = database.fetchMessage(id: messageID),
              message.isOutgoing, message.attachment != nil,
              message.deliveryState == .queued || message.deliveryState == .sending,
              database.outboundAttachmentState(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID) != nil else {
            throw NSError(domain: "VeilLink", code: 16, userInfo: [NSLocalizedDescriptionKey: "这张图片当前无法暂停。"] )
        }
        try database.pauseOutbound(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        removeCachedOutboundAttachment(messageID: messageID)
        onMessagesChanged?(false)
    }

    func resumeImageTransfer(_ messageID: String, to peerIdentityID: String) throws {
        guard let localIdentityID = identity.activeIdentity?.id,
              let message = database.fetchMessage(id: messageID),
              message.isOutgoing, message.attachment != nil,
              message.deliveryState == .paused,
              database.outboundAttachmentState(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID) != nil else {
            throw NSError(domain: "VeilLink", code: 17, userInfo: [NSLocalizedDescriptionKey: "这张图片当前无法继续发送。"] )
        }
        try database.resumeOutbound(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        onMessagesChanged?(false)
        flushOutbound(for: peerIdentityID)
    }

    func cancelImageTransfer(_ messageID: String, to peerIdentityID: String) throws {
        guard let localIdentityID = identity.activeIdentity?.id,
              let message = database.fetchMessage(id: messageID),
              message.isOutgoing, message.attachment != nil,
              message.deliveryState == .queued || message.deliveryState == .sending || message.deliveryState == .paused else {
            throw NSError(domain: "VeilLink", code: 18, userInfo: [NSLocalizedDescriptionKey: "这张图片当前无法取消。"] )
        }
        try database.cancelOutbound(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        removeCachedOutboundAttachment(messageID: messageID)
        onMessagesChanged?(false)
    }

    func discardLocalMessage(_ messageID: String) {
        removeCachedOutboundAttachment(messageID: messageID)
    }

    private func queueContent(_ content: WireChatContent, preview: String, to peerIdentityID: String) throws {
        guard let sender = identity.activeIdentity,
              let trusted = database.trustedContact(localIdentityID: sender.id, identityID: peerIdentityID) else {
            throw NSError(domain: "VeilLink", code: 10, userInfo: [NSLocalizedDescriptionKey: "当前身份尚未与对方完成安全配对。"])
        }
        let conversationID = try database.conversationID(localIdentityID: sender.id, for: peerIdentityID)
            ?? database.createConversation(localIdentityID: sender.id, peerIdentityID: peerIdentityID, title: trusted.displayName)
        let storedBody: String
        switch content.kind {
        case .text, .voice: storedBody = content.text ?? preview
        case .image: storedBody = preview
        }
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: sender.id, body: storedBody, sentAt: content.sentAt, isOutgoing: true, deliveryState: .queued)
        try database.saveMessage(message, conversationPreview: preview)
        if let attachment = content.attachment, let mimeType = content.mimeType { _ = try database.saveAttachment(messageID: message.id, data: attachment, mimeType: mimeType) }
        try database.enqueueOutbound(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: sender.id)
        if let attachment = content.attachment {
            let chunkCount = max(1, Int(ceil(Double(attachment.count) / Double(WireProtocol.attachmentChunkBytes))))
            try database.configureOutboundAttachment(messageID: message.id, chunkCount: chunkCount)
        }
        onMessagesChanged?(true); flushOutbound(for: peerIdentityID)
    }

    private func sendHello(to transportID: UUID) throws {
        if let context = sessions[transportID] {
            let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .hello, payload: try encoder.encode(context.localHello))
            let result = transportSend?(transportID, envelope, .control) ?? .temporarilyUnavailable
            guard result != .unsupportedLink else {
                throw NSError(domain: "VeilLink", code: 20, userInfo: [NSLocalizedDescriptionKey: "蓝牙链路无法承载安全握手。"])
            }
            return
        }
        guard let local = identity.activeIdentity else { throw IdentityError.missingIdentity }
        let ephemeral = Curve25519.KeyAgreement.PrivateKey(); let nonce = PasswordKDF.randomData(count: 16)
        let unsigned = HelloPacket(protocolVersion: WireProtocol.version, identityID: local.id, displayName: local.displayName, identityPublicKey: local.publicKey, agreementPublicKey: ephemeral.publicKey.rawRepresentation, nonce: nonce, signature: Data())
        let hello = HelloPacket(protocolVersion: unsigned.protocolVersion, identityID: unsigned.identityID, displayName: unsigned.displayName, identityPublicKey: unsigned.identityPublicKey, agreementPublicKey: unsigned.agreementPublicKey, nonce: unsigned.nonce, signature: try identity.signingKey().signature(for: unsigned.signedPayload))
        sessions[transportID] = SessionContext(transportID: transportID, localEphemeral: ephemeral, localHello: hello)
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .hello, payload: try encoder.encode(hello))
        let result = transportSend?(transportID, envelope, .control) ?? .temporarilyUnavailable
        guard result != .unsupportedLink else {
            sessions.removeValue(forKey: transportID)
            throw NSError(domain: "VeilLink", code: 20, userInfo: [NSLocalizedDescriptionKey: "蓝牙链路无法承载安全握手。"])
        }
    }

    private func handleHello(transportID: UUID, data: Data) throws {
        let remote = try decoder.decode(HelloPacket.self, from: data)
        guard remote.protocolVersion == WireProtocol.version, remote.identityPublicKey.count == 32, remote.agreementPublicKey.count == 32,
              remote.nonce.count == 16, remote.signature.count == 64, !remote.displayName.isEmpty,
              remote.displayName.lengthOfBytes(using: .utf8) <= WireProtocol.maximumDisplayNameBytes,
              CryptoEngine.identityID(publicKey: remote.identityPublicKey) == remote.identityID else { throw CryptoEngineError.invalidSignature }
        try CryptoEngine.verify(signature: remote.signature, for: remote.signedPayload, publicKey: remote.identityPublicKey)
        if sessions[transportID] == nil {
            try sendHello(to: transportID)
        } else if sessions[transportID]?.remoteHello == nil {
            // If our first Hello was lost but the peer's Hello arrived, echo the same signed
            // local Hello again. This closes a real asymmetric-handshake loss window.
            try? sendHello(to: transportID)
        }
        guard var context = sessions[transportID], remote.identityID != context.localHello.identityID else { throw CryptoEngineError.invalidKeyMaterial }
        if database.peerTrustState(localIdentityID: context.localHello.identityID, identityID: remote.identityID) == .blocked {
            nearbyPeers.removeAll { $0.transportID == transportID || $0.id == remote.identityID }
            nearbyPeers.append(NearbyPeer(id: remote.identityID, transportID: transportID, displayName: remote.displayName, rssi: -100, trustState: .blocked, pairingCode: nil, lastSeen: Date()))
            sessions.removeValue(forKey: transportID)
            peerTransport.removeValue(forKey: remote.identityID)
            recordSecurityEvent("已阻止黑名单身份 \(remote.displayName)")
            transportDisconnect?(transportID)
            return
        }
        if let establishedRemote = context.remoteHello {
            guard establishedRemote == remote else { throw CryptoEngineError.invalidKeyMaterial }
            return
        }
        let ordered = [context.localHello, remote].sorted { $0.identityID < $1.identityID }
        var transcript = Data("VeilLink/Transcript/v4".utf8)
        for hello in ordered { transcript.append(Data("|\(hello.protocolVersion)|\(hello.identityID)|".utf8)); transcript.append(hello.identityPublicKey); transcript.append(hello.agreementPublicKey); transcript.append(hello.nonce) }
        let keys = try CryptoEngine.deriveSessionKeys(localPrivateKey: context.localEphemeral, remotePublicKey: remote.agreementPublicKey, transcript: transcript, localIdentityID: context.localHello.identityID, remoteIdentityID: remote.identityID)
        context.remoteHello = remote; context.keys = keys; context.replayWindow = ReplayWindow(); context.nextSendSequence = 1; sessions[transportID] = context; peerTransport[remote.identityID] = transportID
        cancelHandshakeTimeout(for: transportID)
        let trusted = database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)
        let trustState: NearbyPeer.TrustState = trusted?.publicKey == remote.identityPublicKey ? .trusted : .awaitingConfirmation
        let peer = NearbyPeer(id: remote.identityID, transportID: transportID, displayName: remote.displayName, rssi: nearbyPeers.first(where: { $0.transportID == transportID })?.rssi ?? -100, trustState: trustState, pairingCode: trustState == .trusted ? nil : CryptoEngine.pairingCode(key: keys.rootKey, transcript: transcript), lastSeen: Date())
        nearbyPeers.removeAll { $0.transportID == transportID || $0.id == remote.identityID }; nearbyPeers.append(peer)
        if trustState == .trusted {
            try? database.wakeOutboundForPeer(targetIdentityID: remote.identityID, localIdentityID: context.localHello.identityID)
            flushOutbound(for: remote.identityID)
        }
    }

    private func handleEncryptedMessage(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard UUID(uuidString: payload.messageID) != nil, context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let content = try decoder.decode(WireChatContent.self, from: CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "chat"))
        try validate(content)
        guard context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }

        if database.isLocallyDeletedMessage(messageID: payload.messageID, senderIdentityID: remote.identityID) {
            switch content.kind {
            case .text:
                try sendAcknowledgement(for: payload.messageID, transportID: transportID, context: &context)
            case .image, .voice:
                guard let chunkCount = content.attachmentChunkCount, chunkCount > 0 else { throw CryptoEngineError.invalidCiphertext }
                try sendAttachmentCheckpoint(messageID: payload.messageID, nextChunk: chunkCount, chunkCount: chunkCount, transportID: transportID, context: &context)
            }
            sessions[transportID] = context
            return
        }

        if let existing = database.fetchMessage(id: payload.messageID) {
            guard !existing.isOutgoing, existing.senderIdentityID == remote.identityID else { throw CryptoEngineError.invalidCiphertext }
            switch content.kind {
            case .text:
                guard existing.body == content.text else { throw CryptoEngineError.invalidCiphertext }
            case .image:
                guard existing.body == "[图片]" else { throw CryptoEngineError.invalidCiphertext }
            case .voice:
                guard existing.body == content.text, VoiceMessageCodec.decode(existing.body) != nil else { throw CryptoEngineError.invalidCiphertext }
            }
        } else {
            let conversationID = try database.conversationID(localIdentityID: context.localHello.identityID, for: remote.identityID)
                ?? database.createConversation(localIdentityID: context.localHello.identityID, peerIdentityID: remote.identityID, title: remote.displayName)
            let progress: Double? = (content.kind == .image || content.kind == .voice) ? 0 : nil
            let body: String
            switch content.kind {
            case .text: body = content.text ?? ""
            case .image: body = "[图片]"
            case .voice: body = content.text ?? ""
            }
            let message = ChatMessage(id: payload.messageID, conversationID: conversationID, senderIdentityID: remote.identityID, body: body, sentAt: content.sentAt, isOutgoing: false, deliveryState: .delivered, transferProgress: progress)
            let preview: String
            switch content.kind {
            case .text: preview = MiniGameCodec.previewText(for: message.body) ?? ReplyTextCodec.previewText(for: message.body)
            case .image: preview = "[图片]"
            case .voice: preview = VoiceMessageCodec.decode(message.body).map { VoiceMessageCodec.preview(durationSeconds: $0.durationSeconds) } ?? "[语音]"
            }
            try database.saveMessage(message, conversationPreview: preview)
            onInboundMessageReceived?()
        }

        switch content.kind {
        case .text:
            try sendAcknowledgement(for: payload.messageID, transportID: transportID, context: &context)
        case .image, .voice:
            guard let byteCount = content.attachmentByteCount,
                  let digest = content.attachmentSHA256,
                  let chunkCount = content.attachmentChunkCount else { throw CryptoEngineError.invalidCiphertext }
            let state = try database.beginInboundAttachment(messageID: payload.messageID, byteCount: byteCount, mimeType: content.mimeType ?? "", sha256: digest, chunkCount: chunkCount)
            try sendAttachmentCheckpoint(messageID: payload.messageID, nextChunk: state.nextChunk, chunkCount: state.chunkCount, transportID: transportID, context: &context)
        }
        sessions[transportID] = context
        onMessagesChanged?(true)
    }

    private func handleAttachmentChunk(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard UUID(uuidString: payload.messageID) != nil, context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let clear = try CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "attachment-chunk")
        let chunk = try WireCodec.decodeAttachmentChunk(clear)
        guard chunk.bytes.count <= WireProtocol.attachmentChunkBytes,
              context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let state = try database.storeInboundAttachmentChunk(messageID: payload.messageID, index: Int(chunk.index), chunkCount: Int(chunk.total), clearData: chunk.bytes)
        try sendAttachmentCheckpoint(messageID: payload.messageID, nextChunk: state.nextChunk, chunkCount: state.chunkCount, transportID: transportID, context: &context)
        sessions[transportID] = context
        if state.didPersistProgress || state.completed { onMessagesChanged?(false) }
        if state.completed { onInboundAttachmentCompleted?(payload.messageID) }
    }

    private func handleAttachmentCheckpoint(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard UUID(uuidString: payload.messageID) != nil, context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let clear = try CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "attachment-checkpoint")
        let checkpoint = try WireCodec.decodeAttachmentCheckpoint(clear)
        guard context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        guard database.outboundAttachmentState(
            messageID: payload.messageID,
            targetIdentityID: remote.identityID,
            localIdentityID: context.localHello.identityID
        ) != nil else {
            let existingMessage = database.fetchMessage(id: payload.messageID)
            if existingMessage == nil || existingMessage?.deliveryState == .cancelled {
                sessions[transportID] = context
                return
            }
            throw DatabaseError.statementFailed("附件 checkpoint 找不到对应的本地发送状态。")
        }
        let didPersistProgress = try database.acceptOutboundAttachmentCheckpoint(
            messageID: payload.messageID,
            targetIdentityID: remote.identityID,
            localIdentityID: context.localHello.identityID,
            nextChunk: Int(checkpoint.nextIndex),
            chunkCount: Int(checkpoint.total)
        )
        let paused = database.isOutboundPaused(messageID: payload.messageID, targetIdentityID: remote.identityID, localIdentityID: context.localHello.identityID)
        if checkpoint.nextIndex == checkpoint.total {
            let completedMessage = database.fetchMessage(id: payload.messageID)
            let shouldNotifyDelivery = completedMessage.map { $0.isOutgoing && $0.deliveryState != .delivered } ?? false
            try database.markDelivered(messageID: payload.messageID, from: remote.identityID, localIdentityID: context.localHello.identityID)
            try database.updateTransferProgress(messageID: payload.messageID, progress: 1)
            try database.completeOutbound(messageID: payload.messageID, targetIdentityID: remote.identityID, localIdentityID: context.localHello.identityID)
            removeCachedOutboundAttachment(messageID: payload.messageID)
            if shouldNotifyDelivery { onDeliveryConfirmed?() }
        }
        sessions[transportID] = context
        if didPersistProgress || checkpoint.nextIndex == checkpoint.total { onMessagesChanged?(false) }
        if !paused { flushOutbound(for: remote.identityID) }
        stopRetryLoopIfIdle()
    }

    private func handleAcknowledgement(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard UUID(uuidString: payload.messageID) != nil, context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let ack = try decoder.decode(WireAcknowledgement.self, from: CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "ack"))
        guard ack.messageID == payload.messageID, context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        sessions[transportID] = context
        let shouldNotifyDelivery = database.fetchMessage(id: ack.messageID).map { $0.isOutgoing && $0.deliveryState != .delivered } ?? false
        try database.markDelivered(messageID: ack.messageID, from: remote.identityID, localIdentityID: context.localHello.identityID)
        try database.completeOutbound(messageID: ack.messageID, targetIdentityID: remote.identityID, localIdentityID: context.localHello.identityID)
        if shouldNotifyDelivery { onDeliveryConfirmed?() }
        onMessagesChanged?(false)
        flushOutbound(for: remote.identityID)
        stopRetryLoopIfIdle()
    }

    private func sendAcknowledgement(for messageID: String, transportID: UUID, context: inout SessionContext) throws {
        guard let keys = context.keys else { throw CryptoEngineError.invalidKeyMaterial }
        let encrypted = try CryptoEngine.encrypt(try encoder.encode(WireAcknowledgement(messageID: messageID)), key: keys.sendKey, messageID: messageID, sequence: context.nextSendSequence, context: "ack")
        context.nextSendSequence += 1
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .acknowledgement, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        _ = transportSend?(transportID, envelope, .control)
    }

    private func sendAttachmentCheckpoint(messageID: String, nextChunk: Int, chunkCount: Int, transportID: UUID, context: inout SessionContext) throws {
        guard let keys = context.keys,
              nextChunk >= 0, nextChunk <= chunkCount,
              chunkCount > 0, chunkCount <= Int(UInt16.max) else { throw CryptoEngineError.invalidKeyMaterial }
        let clear = try WireCodec.encodeAttachmentCheckpoint(WireAttachmentCheckpoint(nextIndex: UInt16(nextChunk), total: UInt16(chunkCount)))
        let encrypted = try CryptoEngine.encrypt(clear, key: keys.sendKey, messageID: messageID, sequence: context.nextSendSequence, context: "attachment-checkpoint")
        context.nextSendSequence += 1
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .attachmentCheckpoint, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        _ = transportSend?(transportID, envelope, .control)
    }

    private func flushOutbound(for peerIdentityID: String) {
        guard let transportID = peerTransport[peerIdentityID], var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys else { return }
        let localIdentityID = context.localHello.identityID
        guard remote.identityID == peerIdentityID,
              database.trustedContact(localIdentityID: localIdentityID, identityID: peerIdentityID)?.publicKey == remote.identityPublicKey,
              identity.activeIdentity?.id == localIdentityID else { return }

        let dueItems = database.dueOutboundItems(for: peerIdentityID, localIdentityID: localIdentityID, limit: 8)
        guard !dueItems.isEmpty else {
            sessions[transportID] = context
            stopRetryLoopIfIdle()
            return
        }

        var didChangeVisibleState = false
        for item in dueItems {
            // Do not declare a live message failed merely because a noisy BLE link needed many
            // retries. The persistent outbox expiry remains the upper bound; reconnecting peers
            // can therefore recover after long marginal-link periods without user intervention.
            _ = item.retryCount
            guard let message = database.fetchMessage(id: item.messageID), message.isOutgoing, message.senderIdentityID == localIdentityID else {
                try? database.completeOutbound(messageID: item.messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
                continue
            }
            do {
                if let attachment = message.attachment {
                    didChangeVisibleState = try sendAttachmentStep(message: message, attachment: attachment, peerIdentityID: peerIdentityID, transportID: transportID, localIdentityID: localIdentityID, keys: keys, context: &context) || didChangeVisibleState
                } else {
                    didChangeVisibleState = try sendTextStep(message: message, peerIdentityID: peerIdentityID, transportID: transportID, localIdentityID: localIdentityID, keys: keys, context: &context) || didChangeVisibleState
                }
            } catch {
                lastError = "消息重发失败：\(error.localizedDescription)"
                break
            }
        }
        sessions[transportID] = context
        if didChangeVisibleState { onMessagesChanged?(false) }
        ensureRetryLoopIfNeeded()
    }

    private func sendTextStep(message: ChatMessage, peerIdentityID: String, transportID: UUID, localIdentityID: String, keys: SessionKeyMaterial, context: inout SessionContext) throws -> Bool {
        guard !message.body.isEmpty, message.body.lengthOfBytes(using: .utf8) <= WireProtocol.maximumTextBytes else {
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "本地消息内容无效或超过当前协议限制。")
            return false
        }
        let content = WireChatContent(kind: .text, text: message.body, attachment: nil, mimeType: nil, sentAt: message.sentAt, attachmentByteCount: nil, attachmentSHA256: nil, attachmentChunkCount: nil)
        let encrypted = try CryptoEngine.encrypt(try encoder.encode(content), key: keys.sendKey, messageID: message.id, sequence: context.nextSendSequence, context: "chat")
        context.nextSendSequence += 1
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .encryptedMessage, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        return try applySendResult(transportSend?(transportID, envelope, .control) ?? .temporarilyUnavailable, message: message, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID)
    }

    private func sendAttachmentStep(message: ChatMessage, attachment: ChatAttachment, peerIdentityID: String, transportID: UUID, localIdentityID: String, keys: SessionKeyMaterial, context: inout SessionContext) throws -> Bool {
        let isVoice = VoiceMessageCodec.isVoiceMIMEType(attachment.mimeType)
        let maximumBytes = isVoice ? WireProtocol.maximumVoiceBytes : WireProtocol.maximumImageBytes
        let supportedType = isVoice || MediaTransferPolicy.supportsImageMIMEType(attachment.mimeType)
        guard let cached = cachedOutboundAttachment(messageID: message.id, attachment: attachment),
              cached.data.count == attachment.byteCount,
              cached.data.count <= maximumBytes,
              cached.sha256.count == 32,
              supportedType else {
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "本地附件数据缺失、损坏或编码不受支持。")
            return false
        }
        let data = cached.data
        let digest = cached.sha256
        let expectedChunkCount = max(1, Int(ceil(Double(data.count) / Double(WireProtocol.attachmentChunkBytes))))
        var state = database.outboundAttachmentState(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        if state == nil {
            try database.configureOutboundAttachment(messageID: message.id, chunkCount: expectedChunkCount)
            state = database.outboundAttachmentState(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        }
        guard let state, state.chunkCount == expectedChunkCount else {
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "本地附件 checkpoint 与图片数据不一致。")
            return false
        }

        let envelope: Data
        let priority: BLESendPriority
        if state.nextChunk < 0 {
            priority = .control
            let manifest = WireChatContent(kind: isVoice ? .voice : .image, text: isVoice ? message.body : nil, attachment: nil, mimeType: attachment.mimeType, sentAt: message.sentAt, attachmentByteCount: data.count, attachmentSHA256: digest, attachmentChunkCount: expectedChunkCount)
            let encrypted = try CryptoEngine.encrypt(try encoder.encode(manifest), key: keys.sendKey, messageID: message.id, sequence: context.nextSendSequence, context: "chat")
            context.nextSendSequence += 1
            envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .encryptedMessage, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        } else if state.nextChunk < state.chunkCount {
            priority = .bulk
            let lower = state.nextChunk * WireProtocol.attachmentChunkBytes
            let upper = min(lower + WireProtocol.attachmentChunkBytes, data.count)
            guard lower < upper else { throw CryptoEngineError.invalidCiphertext }
            let clearChunk = try WireCodec.encodeAttachmentChunk(WireAttachmentChunk(index: UInt16(state.nextChunk), total: UInt16(state.chunkCount), bytes: Data(data[lower..<upper])))
            let encrypted = try CryptoEngine.encrypt(clearChunk, key: keys.sendKey, messageID: message.id, sequence: context.nextSendSequence, context: "attachment-chunk")
            context.nextSendSequence += 1
            envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .attachmentChunk, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        } else {
            try database.markDelivered(messageID: message.id, from: peerIdentityID, localIdentityID: localIdentityID)
            try database.updateTransferProgress(messageID: message.id, progress: 1)
            try database.completeOutbound(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
            removeCachedOutboundAttachment(messageID: message.id)
            return true
        }
        guard envelope.count <= WireProtocol.maximumEnvelopeBytes else {
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "附件分块编码后超过当前协议允许的最大体积。")
            return false
        }
        return try applySendResult(transportSend?(transportID, envelope, priority) ?? .temporarilyUnavailable, message: message, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID)
    }

    private func applySendResult(_ result: TransportSendResult, message: ChatMessage, peerIdentityID: String, localIdentityID: String) throws -> Bool {
        switch result {
        case .accepted:
            let didChangeVisibleState = message.deliveryState != .sending
            if didChangeVisibleState { try database.updateDelivery(messageID: message.id, state: .sending) }
            try database.recordAcceptedOutboundAttempt(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
            return didChangeVisibleState
        case .temporarilyUnavailable:
            let didChangeVisibleState = message.deliveryState != .queued
            if didChangeVisibleState { try database.updateDelivery(messageID: message.id, state: .queued) }
            try database.deferOutbound(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
            return didChangeVisibleState
        case .unsupportedLink:
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "当前蓝牙链路无法承载这一数据块。")
            lastError = "当前蓝牙链路无法承载这一数据块。"
            return false
        }
    }

    private func failOutbound(messageID: String, peerIdentityID: String, localIdentityID: String, reason: String) {
        removeCachedOutboundAttachment(messageID: messageID)
        try? database.updateDelivery(messageID: messageID, state: .failed, error: reason)
        try? database.completeOutbound(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        onMessagesChanged?(false)
    }

    private func cachedOutboundAttachment(messageID: String, attachment: ChatAttachment) -> CachedOutboundAttachment? {
        if let cached = outboundAttachmentCache[messageID], cached.attachmentID == attachment.id {
            touchCachedOutboundAttachment(messageID: messageID)
            return cached
        }
        guard let data = database.loadAttachment(id: attachment.id),
              let digest = database.attachmentSHA256(id: attachment.id),
              data.count == attachment.byteCount, digest.count == 32 else { return nil }
        let entry = CachedOutboundAttachment(attachmentID: attachment.id, data: data, sha256: digest)
        insertCachedOutboundAttachment(entry, messageID: messageID)
        return entry
    }

    private func insertCachedOutboundAttachment(_ entry: CachedOutboundAttachment, messageID: String) {
        removeCachedOutboundAttachment(messageID: messageID)
        guard entry.data.count <= maximumOutboundAttachmentCacheBytes else { return }
        while outboundAttachmentCacheBytes + entry.data.count > maximumOutboundAttachmentCacheBytes,
              let oldest = outboundAttachmentCacheOrder.first {
            removeCachedOutboundAttachment(messageID: oldest)
        }
        outboundAttachmentCache[messageID] = entry
        outboundAttachmentCacheOrder.append(messageID)
        outboundAttachmentCacheBytes += entry.data.count
    }

    private func touchCachedOutboundAttachment(messageID: String) {
        outboundAttachmentCacheOrder.removeAll { $0 == messageID }
        outboundAttachmentCacheOrder.append(messageID)
    }

    private func removeCachedOutboundAttachment(messageID: String) {
        if let removed = outboundAttachmentCache.removeValue(forKey: messageID) {
            outboundAttachmentCacheBytes = max(0, outboundAttachmentCacheBytes - removed.data.count)
        }
        outboundAttachmentCacheOrder.removeAll { $0 == messageID }
    }

    private func clearOutboundAttachmentCache() {
        outboundAttachmentCache.removeAll(keepingCapacity: false)
        outboundAttachmentCacheOrder.removeAll(keepingCapacity: false)
        outboundAttachmentCacheBytes = 0
    }


    private func scheduleHandshakeTimeout(for transportID: UUID) {
        cancelHandshakeTimeout(for: transportID)
        handshakeTimeoutTasks[transportID] = Task { @MainActor [weak self] in
            guard let self else { return }
            for delay in self.handshakeRetryScheduleNanoseconds {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                guard let context = self.sessions[transportID] else { return }
                if context.remoteHello != nil {
                    self.handshakeTimeoutTasks.removeValue(forKey: transportID)
                    return
                }
                // Reuse the same ephemeral key/nonce for this handshake attempt. The signed Hello
                // is idempotent and a duplicate is harmless, while a lost first Hello no longer
                // forces a manual reconnect.
                try? self.sendHello(to: transportID)
            }

            guard !Task.isCancelled,
                  let context = self.sessions[transportID],
                  context.remoteHello == nil else { return }
            self.handshakeTimeoutTasks.removeValue(forKey: transportID)
            self.sessions.removeValue(forKey: transportID)
            self.packetAbuseLimiter.reset(transportID)
            self.peerTransport = self.peerTransport.filter { $0.value != transportID }
            self.recordSecurityEvent("安全握手持续丢包，已在现有链路上重新发起")
            self.lastError = "蓝牙链路较弱，正在重新建立安全会话。"
            // The physical BLE link may still be alive (especially when this device is the
            // peripheral). Re-seed the secure handshake in place instead of permanently dropping
            // the user's connection intent.
            do {
                try self.sendHello(to: transportID)
                self.scheduleHandshakeTimeout(for: transportID)
            } catch {
                self.lastError = "安全会话恢复失败，等待蓝牙链路重新连接。"
            }
        }
    }

    private func cancelHandshakeTimeout(for transportID: UUID) {
        handshakeTimeoutTasks.removeValue(forKey: transportID)?.cancel()
    }

    private func cancelAllHandshakeTimeouts() {
        handshakeTimeoutTasks.values.forEach { $0.cancel() }
        handshakeTimeoutTasks.removeAll(keepingCapacity: false)
    }

    private func handleInvalidPacket(transportID: UUID, reason: String) {
        let wasAuthenticated = sessions[transportID]?.remoteHello != nil
        let decision = packetAbuseLimiter.recordInvalidPacket(for: transportID)

        if decision.isFirstInWindow {
            recordSecurityEvent("拒绝\(reason)")
            if wasAuthenticated { lastError = "收到无法验证的数据包，已忽略。" }
        }
        guard decision.shouldDisconnect else { return }

        packetAbuseLimiter.reset(transportID)
        cancelHandshakeTimeout(for: transportID)
        if let remoteIdentityID = sessions[transportID]?.remoteHello?.identityID,
           peerTransport[remoteIdentityID] == transportID {
            peerTransport.removeValue(forKey: remoteIdentityID)
        }
        sessions.removeValue(forKey: transportID)
        nearbyPeers.removeAll { $0.transportID == transportID }
        recordSecurityEvent("持续无效数据达到阈值，已断开该 BLE 链路")
        if wasAuthenticated { lastError = "检测到连续无效数据，已安全断开该设备。" }
        transportDisconnect?(transportID)
    }

    private func retryDueOutbound() {
        try? database.expireOutboundMessages()
        for peerIdentityID in peerTransport.keys {
            flushOutbound(for: peerIdentityID)
        }
    }

    private func ensureRetryLoopIfNeeded() {
        guard retryTask == nil,
              !peerTransport.isEmpty,
              let localIdentityID = identity.activeIdentity?.id,
              database.pendingOutboundCount(localIdentityID: localIdentityID) > 0 else { return }
        let interval = maintenanceTuning.outboundRetryIntervalNanoseconds
        retryTaskGeneration &+= 1
        let generation = retryTaskGeneration
        retryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled,
                      !self.peerTransport.isEmpty,
                      let localIdentityID = self.identity.activeIdentity?.id,
                      self.database.pendingOutboundCount(localIdentityID: localIdentityID) > 0 else { break }
                self.retryDueOutbound()
            }
            if self.retryTaskGeneration == generation { self.retryTask = nil }
        }
    }

    private func stopRetryLoopIfIdle() {
        guard let localIdentityID = identity.activeIdentity?.id else {
            retryTaskGeneration &+= 1
            retryTask?.cancel()
            retryTask = nil
            return
        }
        if peerTransport.isEmpty || database.pendingOutboundCount(localIdentityID: localIdentityID) == 0 {
            retryTaskGeneration &+= 1
            retryTask?.cancel()
            retryTask = nil
        }
    }


    func sendPTTControl(_ packet: VeilPTTControlPacket, to peerIdentityIDs: [String]) {
        guard let clear = try? VeilPTTCodec.encodeControl(packet) else { return }
        for peerIdentityID in Set(peerIdentityIDs) {
            guard let transportID = peerTransport[peerIdentityID], var context = sessions[transportID],
                  let remote = context.remoteHello, let keys = context.keys,
                  remote.identityID == peerIdentityID,
                  database.trustedContact(localIdentityID: context.localHello.identityID, identityID: peerIdentityID)?.publicKey == remote.identityPublicKey else { continue }
            do {
                let encrypted = try CryptoEngine.encrypt(clear, key: keys.sendKey, messageID: packet.talkID, sequence: context.nextSendSequence, context: "ptt-control")
                context.nextSendSequence += 1
                let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .pttControl, payload: try WireCodec.encodeEncryptedPayload(encrypted))
                if envelope.count <= WireProtocol.maximumEnvelopeBytes { _ = transportSend?(transportID, envelope, .control) }
                sessions[transportID] = context
            } catch { continue }
        }
    }

    @discardableResult
    func sendPTTAudioFrame(_ frame: VeilPTTAudioFrame, to peerIdentityIDs: [String]) -> VeilPTTSendReport {
        var report = VeilPTTSendReport()
        guard let clear = try? VeilPTTCodec.encodeAudio(frame) else { return report }
        for peerIdentityID in Set(peerIdentityIDs) {
            report.requested += 1
            guard let transportID = peerTransport[peerIdentityID], var context = sessions[transportID],
                  let remote = context.remoteHello, let keys = context.keys,
                  remote.identityID == peerIdentityID,
                  database.trustedContact(localIdentityID: context.localHello.identityID, identityID: peerIdentityID)?.publicKey == remote.identityPublicKey else {
                report.unavailable += 1
                continue
            }
            do {
                let encrypted = try CryptoEngine.encrypt(clear, key: keys.sendKey, messageID: frame.talkID, sequence: context.nextSendSequence, context: "ptt-audio")
                context.nextSendSequence += 1
                let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .pttAudio, payload: try WireCodec.encodeEncryptedPayload(encrypted))
                guard envelope.count <= WireProtocol.maximumEnvelopeBytes else {
                    report.unsupported += 1
                    sessions[transportID] = context
                    continue
                }
                switch transportSend?(transportID, envelope, .realtime) ?? .temporarilyUnavailable {
                case .accepted: report.accepted += 1
                case .temporarilyUnavailable: report.unavailable += 1
                case .unsupportedLink: report.unsupported += 1
                }
                sessions[transportID] = context
            } catch {
                report.unavailable += 1
            }
        }
        return report
    }

    private func handlePTTControl(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let clear = try CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "ptt-control")
        let packet = try VeilPTTCodec.decodeControl(clear)
        guard packet.talkID == payload.messageID, context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        sessions[transportID] = context
        onPTTControl?(VeilPTTIncomingControl(peerIdentityID: remote.identityID, packet: packet))
    }

    private func handlePTTAudio(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let clear = try CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "ptt-audio")
        let frame = try VeilPTTCodec.decodeAudio(clear)
        guard frame.talkID == payload.messageID, context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        sessions[transportID] = context
        onPTTAudioFrame?(VeilPTTIncomingAudio(peerIdentityID: remote.identityID, frame: frame))
    }

    private func validate(_ content: WireChatContent) throws {
        guard abs(content.sentAt.timeIntervalSinceNow) <= 30 * 24 * 60 * 60 else { throw CryptoEngineError.invalidCiphertext }
        switch content.kind {
        case .text:
            guard let text = content.text, !text.isEmpty, text.lengthOfBytes(using: .utf8) <= WireProtocol.maximumTextBytes,
                  content.attachment == nil, content.mimeType == nil, content.attachmentByteCount == nil,
                  content.attachmentSHA256 == nil, content.attachmentChunkCount == nil else { throw CryptoEngineError.invalidCiphertext }
        case .image:
            guard content.text == nil, content.attachment == nil,
                  let mimeType = content.mimeType, MediaTransferPolicy.supportsImageMIMEType(mimeType),
                  let byteCount = content.attachmentByteCount, byteCount > 0, byteCount <= WireProtocol.maximumImageBytes,
                  let digest = content.attachmentSHA256, digest.count == 32,
                  let chunkCount = content.attachmentChunkCount, chunkCount > 0, chunkCount <= Int(UInt16.max),
                  chunkCount == max(1, Int(ceil(Double(byteCount) / Double(WireProtocol.attachmentChunkBytes)))) else { throw CryptoEngineError.invalidCiphertext }
        case .voice:
            guard content.attachment == nil,
                  let metadata = content.text, VoiceMessageCodec.decode(metadata) != nil,
                  let mimeType = content.mimeType, VoiceMessageCodec.isVoiceMIMEType(mimeType),
                  let byteCount = content.attachmentByteCount, byteCount > 0, byteCount <= WireProtocol.maximumVoiceBytes,
                  let digest = content.attachmentSHA256, digest.count == 32,
                  let chunkCount = content.attachmentChunkCount, chunkCount > 0, chunkCount <= Int(UInt16.max),
                  chunkCount == max(1, Int(ceil(Double(byteCount) / Double(WireProtocol.attachmentChunkBytes)))) else { throw CryptoEngineError.invalidCiphertext }
        }
    }

    private func pruneNearbyPeers() { let cutoff = Date().addingTimeInterval(-10 * 60); nearbyPeers.removeAll { $0.trustState == .discovered && $0.lastSeen < cutoff } }
    private func recordSecurityEvent(_ text: String) { securityEvents.insert("\(text) · \(Date().formatted())", at: 0); if securityEvents.count > 100 { securityEvents.removeLast(securityEvents.count - 100) } }
}
