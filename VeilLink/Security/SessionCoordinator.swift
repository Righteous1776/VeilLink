import Combine
import CryptoKit
import Foundation

private enum WireProtocol {
    static let version = 4
    static let maximumEnvelopeBytes = 96_000
    static let maximumTextBytes = 16_384
    static let maximumImageBytes = MediaTransferPolicy.maximumImageBytes
    static let attachmentChunkBytes = 48 * 1_024
    static let maximumDisplayNameBytes = 128
    static let maximumAcknowledgementAttempts = 10
}

private struct WireAcknowledgement: Codable { let messageID: String }

private struct WireChatContent: Codable {
    enum Kind: String, Codable { case text, image }
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

    var transportSend: ((UUID, Data) -> TransportSendResult)?
    var transportDisconnect: ((UUID) -> Void)?
    var onMessagesChanged: (() -> Void)?

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
    private let maximumOutboundAttachmentCacheBytes = 12 * 1_024 * 1_024

    private var packetAbuseLimiter = PacketAbuseLimiter()
    private var retryTimer: AnyCancellable?

    init(identity: IdentityManager, database: DatabaseStore) {
        self.identity = identity; self.database = database
        retryTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            Task { @MainActor in self?.retryDueOutbound() }
        }
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

    func connected(transportID: UUID) { do { try sendHello(to: transportID) } catch { lastError = "握手初始化失败：\(error.localizedDescription)" } }
    func disconnected(transportID: UUID) {
        sessions.removeValue(forKey: transportID)
        packetAbuseLimiter.reset(transportID)
        peerTransport = peerTransport.filter { $0.value != transportID }
        nearbyPeers.removeAll { $0.transportID == transportID }
        if peerTransport.isEmpty { clearOutboundAttachmentCache() }
    }

    func resetForIdentityChange() {
        sessions.removeAll()
        packetAbuseLimiter.resetAll()
        peerTransport.removeAll()
        nearbyPeers.removeAll()
        clearOutboundAttachmentCache()
        lastError = nil
    }

    func invalidatePeer(_ peerIdentityID: String) {
        if let transportID = peerTransport.removeValue(forKey: peerIdentityID) {
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
            recordSecurityEvent("已信任 \(remote.displayName) · 身份指纹已固定"); onMessagesChanged?(); flushOutbound(for: remote.identityID)
        } catch { lastError = error.localizedDescription }
    }

    func rejectPairing(peerID: String) {
        guard let index = nearbyPeers.firstIndex(where: { $0.id == peerID }) else { return }
        let transportID = nearbyPeers[index].transportID
        sessions.removeValue(forKey: transportID)
        peerTransport = peerTransport.filter { $0.value != transportID }
        nearbyPeers[index].trustState = .blocked
        nearbyPeers[index].pairingCode = nil
        transportDisconnect?(transportID)
    }

    func sendMessage(_ text: String, to peerIdentityID: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lengthOfBytes(using: .utf8) <= WireProtocol.maximumTextBytes else { throw NSError(domain: "VeilLink", code: 13, userInfo: [NSLocalizedDescriptionKey: "消息为空或超过 16 KB。"]) }
        try queueContent(WireChatContent(kind: .text, text: trimmed, attachment: nil, mimeType: nil, sentAt: Date(), attachmentByteCount: nil, attachmentSHA256: nil, attachmentChunkCount: nil), preview: trimmed, to: peerIdentityID)
    }

    func sendImage(_ imageData: Data, mimeType: String, to peerIdentityID: String) throws {
        guard imageData.count <= WireProtocol.maximumImageBytes else { throw NSError(domain: "VeilLink", code: 12, userInfo: [NSLocalizedDescriptionKey: "图片处理后仍超过 3 MB。"] ) }
        guard MediaTransferPolicy.supportsImageMIMEType(mimeType) else { throw NSError(domain: "VeilLink", code: 14, userInfo: [NSLocalizedDescriptionKey: "当前传输层不支持这种图片编码。"] ) }
        try queueContent(WireChatContent(kind: .image, text: nil, attachment: imageData, mimeType: mimeType, sentAt: Date(), attachmentByteCount: nil, attachmentSHA256: nil, attachmentChunkCount: nil), preview: "[图片]", to: peerIdentityID)
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
        onMessagesChanged?()
        flushOutbound(for: peerIdentityID)
    }

    private func queueContent(_ content: WireChatContent, preview: String, to peerIdentityID: String) throws {
        guard let sender = identity.activeIdentity,
              let trusted = database.trustedContact(localIdentityID: sender.id, identityID: peerIdentityID) else {
            throw NSError(domain: "VeilLink", code: 10, userInfo: [NSLocalizedDescriptionKey: "当前身份尚未与对方完成安全配对。"])
        }
        let conversationID = try database.conversationID(localIdentityID: sender.id, for: peerIdentityID)
            ?? database.createConversation(localIdentityID: sender.id, peerIdentityID: peerIdentityID, title: trusted.displayName)
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: sender.id, body: preview, sentAt: content.sentAt, isOutgoing: true, deliveryState: .queued)
        try database.saveMessage(message)
        if let attachment = content.attachment, let mimeType = content.mimeType { _ = try database.saveAttachment(messageID: message.id, data: attachment, mimeType: mimeType) }
        try database.enqueueOutbound(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: sender.id)
        if let attachment = content.attachment {
            let chunkCount = max(1, Int(ceil(Double(attachment.count) / Double(WireProtocol.attachmentChunkBytes))))
            try database.configureOutboundAttachment(messageID: message.id, chunkCount: chunkCount)
        }
        onMessagesChanged?(); flushOutbound(for: peerIdentityID)
    }

    private func sendHello(to transportID: UUID) throws {
        if let context = sessions[transportID] {
            let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .hello, payload: try encoder.encode(context.localHello))
            guard transportSend?(transportID, envelope) == .accepted else { throw NSError(domain: "VeilLink", code: 20, userInfo: [NSLocalizedDescriptionKey: "蓝牙发送队列暂时不可用。"]) }
            return
        }
        guard let local = identity.activeIdentity else { throw IdentityError.missingIdentity }
        let ephemeral = Curve25519.KeyAgreement.PrivateKey(); let nonce = PasswordKDF.randomData(count: 16)
        let unsigned = HelloPacket(protocolVersion: WireProtocol.version, identityID: local.id, displayName: local.displayName, identityPublicKey: local.publicKey, agreementPublicKey: ephemeral.publicKey.rawRepresentation, nonce: nonce, signature: Data())
        let hello = HelloPacket(protocolVersion: unsigned.protocolVersion, identityID: unsigned.identityID, displayName: unsigned.displayName, identityPublicKey: unsigned.identityPublicKey, agreementPublicKey: unsigned.agreementPublicKey, nonce: unsigned.nonce, signature: try identity.signingKey().signature(for: unsigned.signedPayload))
        sessions[transportID] = SessionContext(transportID: transportID, localEphemeral: ephemeral, localHello: hello)
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .hello, payload: try encoder.encode(hello))
        guard transportSend?(transportID, envelope) == .accepted else {
            sessions.removeValue(forKey: transportID)
            throw NSError(domain: "VeilLink", code: 20, userInfo: [NSLocalizedDescriptionKey: "蓝牙发送队列暂时不可用。"])
        }
    }

    private func handleHello(transportID: UUID, data: Data) throws {
        let remote = try decoder.decode(HelloPacket.self, from: data)
        guard remote.protocolVersion == WireProtocol.version, remote.identityPublicKey.count == 32, remote.agreementPublicKey.count == 32,
              remote.nonce.count == 16, remote.signature.count == 64, !remote.displayName.isEmpty,
              remote.displayName.lengthOfBytes(using: .utf8) <= WireProtocol.maximumDisplayNameBytes,
              CryptoEngine.identityID(publicKey: remote.identityPublicKey) == remote.identityID else { throw CryptoEngineError.invalidSignature }
        try CryptoEngine.verify(signature: remote.signature, for: remote.signedPayload, publicKey: remote.identityPublicKey)
        if sessions[transportID] == nil { try sendHello(to: transportID) }
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
        let trusted = database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)
        let trustState: NearbyPeer.TrustState = trusted?.publicKey == remote.identityPublicKey ? .trusted : .awaitingConfirmation
        let peer = NearbyPeer(id: remote.identityID, transportID: transportID, displayName: remote.displayName, rssi: nearbyPeers.first(where: { $0.transportID == transportID })?.rssi ?? -100, trustState: trustState, pairingCode: trustState == .trusted ? nil : CryptoEngine.pairingCode(key: keys.rootKey, transcript: transcript), lastSeen: Date())
        nearbyPeers.removeAll { $0.transportID == transportID || $0.id == remote.identityID }; nearbyPeers.append(peer)
        if trustState == .trusted { flushOutbound(for: remote.identityID) }
    }

    private func handleEncryptedMessage(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard UUID(uuidString: payload.messageID) != nil, context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let content = try decoder.decode(WireChatContent.self, from: CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "chat"))
        try validate(content)
        guard context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }

        if let existing = database.fetchMessage(id: payload.messageID) {
            guard !existing.isOutgoing, existing.senderIdentityID == remote.identityID else { throw CryptoEngineError.invalidCiphertext }
            switch content.kind {
            case .text:
                guard existing.body == content.text else { throw CryptoEngineError.invalidCiphertext }
            case .image:
                guard existing.body == "[图片]" else { throw CryptoEngineError.invalidCiphertext }
            }
        } else {
            let conversationID = try database.conversationID(localIdentityID: context.localHello.identityID, for: remote.identityID)
                ?? database.createConversation(localIdentityID: context.localHello.identityID, peerIdentityID: remote.identityID, title: remote.displayName)
            let progress: Double? = content.kind == .image ? 0 : nil
            let message = ChatMessage(id: payload.messageID, conversationID: conversationID, senderIdentityID: remote.identityID, body: content.kind == .image ? "[图片]" : (content.text ?? ""), sentAt: content.sentAt, isOutgoing: false, deliveryState: .delivered, transferProgress: progress)
            try database.saveMessage(message)
        }

        switch content.kind {
        case .text:
            try sendAcknowledgement(for: payload.messageID, transportID: transportID, context: &context)
        case .image:
            guard let byteCount = content.attachmentByteCount,
                  let digest = content.attachmentSHA256,
                  let chunkCount = content.attachmentChunkCount else { throw CryptoEngineError.invalidCiphertext }
            let state = try database.beginInboundAttachment(messageID: payload.messageID, byteCount: byteCount, mimeType: content.mimeType ?? "", sha256: digest, chunkCount: chunkCount)
            try sendAttachmentCheckpoint(messageID: payload.messageID, nextChunk: state.nextChunk, chunkCount: state.chunkCount, transportID: transportID, context: &context)
        }
        sessions[transportID] = context
        onMessagesChanged?()
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
        onMessagesChanged?()
    }

    private func handleAttachmentCheckpoint(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard UUID(uuidString: payload.messageID) != nil, context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let clear = try CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "attachment-checkpoint")
        let checkpoint = try WireCodec.decodeAttachmentCheckpoint(clear)
        guard context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        try database.acceptOutboundAttachmentCheckpoint(
            messageID: payload.messageID,
            targetIdentityID: remote.identityID,
            localIdentityID: context.localHello.identityID,
            nextChunk: Int(checkpoint.nextIndex),
            chunkCount: Int(checkpoint.total)
        )
        if checkpoint.nextIndex == checkpoint.total {
            try database.markDelivered(messageID: payload.messageID, from: remote.identityID, localIdentityID: context.localHello.identityID)
            try database.updateTransferProgress(messageID: payload.messageID, progress: 1)
            try database.completeOutbound(messageID: payload.messageID, targetIdentityID: remote.identityID, localIdentityID: context.localHello.identityID)
            removeCachedOutboundAttachment(messageID: payload.messageID)
        } else {
            try database.updateDelivery(messageID: payload.messageID, state: .sending)
        }
        sessions[transportID] = context
        onMessagesChanged?()
        flushOutbound(for: remote.identityID)
    }

    private func handleAcknowledgement(transportID: UUID, data: Data) throws {
        guard var context = sessions[transportID], let remote = context.remoteHello, let keys = context.keys,
              database.trustedContact(localIdentityID: context.localHello.identityID, identityID: remote.identityID)?.publicKey == remote.identityPublicKey else { throw CryptoEngineError.invalidCiphertext }
        let payload = try WireCodec.decodeEncryptedPayload(data)
        guard UUID(uuidString: payload.messageID) != nil, context.replayWindow.isPotentiallyFresh(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        let ack = try decoder.decode(WireAcknowledgement.self, from: CryptoEngine.decrypt(payload, key: keys.receiveKey, context: "ack"))
        guard ack.messageID == payload.messageID, context.replayWindow.accept(payload.sequence) else { throw CryptoEngineError.invalidCiphertext }
        sessions[transportID] = context
        try database.markDelivered(messageID: ack.messageID, from: remote.identityID, localIdentityID: context.localHello.identityID)
        try database.completeOutbound(messageID: ack.messageID, targetIdentityID: remote.identityID, localIdentityID: context.localHello.identityID)
        onMessagesChanged?(); flushOutbound(for: remote.identityID)
    }

    private func sendAcknowledgement(for messageID: String, transportID: UUID, context: inout SessionContext) throws {
        guard let keys = context.keys else { throw CryptoEngineError.invalidKeyMaterial }
        let encrypted = try CryptoEngine.encrypt(try encoder.encode(WireAcknowledgement(messageID: messageID)), key: keys.sendKey, messageID: messageID, sequence: context.nextSendSequence, context: "ack")
        context.nextSendSequence += 1
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .acknowledgement, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        _ = transportSend?(transportID, envelope)
    }

    private func sendAttachmentCheckpoint(messageID: String, nextChunk: Int, chunkCount: Int, transportID: UUID, context: inout SessionContext) throws {
        guard let keys = context.keys,
              nextChunk >= 0, nextChunk <= chunkCount,
              chunkCount > 0, chunkCount <= Int(UInt16.max) else { throw CryptoEngineError.invalidKeyMaterial }
        let clear = try WireCodec.encodeAttachmentCheckpoint(WireAttachmentCheckpoint(nextIndex: UInt16(nextChunk), total: UInt16(chunkCount)))
        let encrypted = try CryptoEngine.encrypt(clear, key: keys.sendKey, messageID: messageID, sequence: context.nextSendSequence, context: "attachment-checkpoint")
        context.nextSendSequence += 1
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .attachmentCheckpoint, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        _ = transportSend?(transportID, envelope)
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
            return
        }

        for item in dueItems {
            if item.retryCount >= WireProtocol.maximumAcknowledgementAttempts {
                failOutbound(messageID: item.messageID, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "多次发送后仍未收到对方确认。可手动重试。")
                continue
            }
            guard let message = database.fetchMessage(id: item.messageID), message.isOutgoing, message.senderIdentityID == localIdentityID else {
                try? database.completeOutbound(messageID: item.messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
                continue
            }
            do {
                if let attachment = message.attachment {
                    try sendAttachmentStep(message: message, attachment: attachment, peerIdentityID: peerIdentityID, transportID: transportID, localIdentityID: localIdentityID, keys: keys, context: &context)
                } else {
                    try sendTextStep(message: message, peerIdentityID: peerIdentityID, transportID: transportID, localIdentityID: localIdentityID, keys: keys, context: &context)
                }
            } catch {
                lastError = "消息重发失败：\(error.localizedDescription)"
                break
            }
        }
        sessions[transportID] = context
        onMessagesChanged?()
    }

    private func sendTextStep(message: ChatMessage, peerIdentityID: String, transportID: UUID, localIdentityID: String, keys: SessionKeyMaterial, context: inout SessionContext) throws {
        guard !message.body.isEmpty, message.body.lengthOfBytes(using: .utf8) <= WireProtocol.maximumTextBytes else {
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "本地消息内容无效或超过当前协议限制。")
            return
        }
        let content = WireChatContent(kind: .text, text: message.body, attachment: nil, mimeType: nil, sentAt: message.sentAt, attachmentByteCount: nil, attachmentSHA256: nil, attachmentChunkCount: nil)
        let encrypted = try CryptoEngine.encrypt(try encoder.encode(content), key: keys.sendKey, messageID: message.id, sequence: context.nextSendSequence, context: "chat")
        context.nextSendSequence += 1
        let envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .encryptedMessage, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        try applySendResult(transportSend?(transportID, envelope) ?? .temporarilyUnavailable, message: message, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID)
    }

    private func sendAttachmentStep(message: ChatMessage, attachment: ChatAttachment, peerIdentityID: String, transportID: UUID, localIdentityID: String, keys: SessionKeyMaterial, context: inout SessionContext) throws {
        guard let cached = cachedOutboundAttachment(messageID: message.id, attachment: attachment),
              cached.data.count == attachment.byteCount,
              cached.data.count <= WireProtocol.maximumImageBytes,
              cached.sha256.count == 32,
              MediaTransferPolicy.supportsImageMIMEType(attachment.mimeType) else {
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "本地图片数据缺失或已损坏。")
            return
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
            return
        }

        let envelope: Data
        if state.nextChunk < 0 {
            let manifest = WireChatContent(kind: .image, text: nil, attachment: nil, mimeType: attachment.mimeType, sentAt: message.sentAt, attachmentByteCount: data.count, attachmentSHA256: digest, attachmentChunkCount: expectedChunkCount)
            let encrypted = try CryptoEngine.encrypt(try encoder.encode(manifest), key: keys.sendKey, messageID: message.id, sequence: context.nextSendSequence, context: "chat")
            context.nextSendSequence += 1
            envelope = try WireCodec.encodeEnvelope(version: UInt8(WireProtocol.version), kind: .encryptedMessage, payload: try WireCodec.encodeEncryptedPayload(encrypted))
        } else if state.nextChunk < state.chunkCount {
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
            return
        }
        guard envelope.count <= WireProtocol.maximumEnvelopeBytes else {
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "附件分块编码后超过当前协议允许的最大体积。")
            return
        }
        try applySendResult(transportSend?(transportID, envelope) ?? .temporarilyUnavailable, message: message, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID)
    }

    private func applySendResult(_ result: TransportSendResult, message: ChatMessage, peerIdentityID: String, localIdentityID: String) throws {
        switch result {
        case .accepted:
            try database.updateDelivery(messageID: message.id, state: .sending)
            try database.recordAcceptedOutboundAttempt(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        case .temporarilyUnavailable:
            try database.updateDelivery(messageID: message.id, state: .queued)
            try database.deferOutbound(messageID: message.id, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        case .unsupportedLink:
            failOutbound(messageID: message.id, peerIdentityID: peerIdentityID, localIdentityID: localIdentityID, reason: "当前蓝牙链路无法承载这一数据块。")
            lastError = "当前蓝牙链路无法承载这一数据块。"
        }
    }

    private func failOutbound(messageID: String, peerIdentityID: String, localIdentityID: String, reason: String) {
        removeCachedOutboundAttachment(messageID: messageID)
        try? database.updateDelivery(messageID: messageID, state: .failed, error: reason)
        try? database.completeOutbound(messageID: messageID, targetIdentityID: peerIdentityID, localIdentityID: localIdentityID)
        onMessagesChanged?()
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


    private func handleInvalidPacket(transportID: UUID, reason: String) {
        let wasAuthenticated = sessions[transportID]?.remoteHello != nil
        let decision = packetAbuseLimiter.recordInvalidPacket(for: transportID)

        if decision.isFirstInWindow {
            recordSecurityEvent("拒绝\(reason)")
            if wasAuthenticated { lastError = "收到无法验证的数据包，已忽略。" }
        }
        guard decision.shouldDisconnect else { return }

        packetAbuseLimiter.reset(transportID)
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

    private func retryDueOutbound() { try? database.expireOutboundMessages(); for peerIdentityID in Set(peerTransport.keys) { flushOutbound(for: peerIdentityID) } }

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
        }
    }

    private func pruneNearbyPeers() { let cutoff = Date().addingTimeInterval(-10 * 60); nearbyPeers.removeAll { $0.trustState == .discovered && $0.lastSeen < cutoff } }
    private func recordSecurityEvent(_ text: String) { securityEvents.insert("\(text) · \(Date().formatted())", at: 0); if securityEvents.count > 100 { securityEvents.removeLast(securityEvents.count - 100) } }
}
