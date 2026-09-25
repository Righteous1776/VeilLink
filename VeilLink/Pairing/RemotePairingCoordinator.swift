import Combine
import CryptoKit
import Foundation

@MainActor
final class VeilRemotePairingCoordinator: ObservableObject {
    @Published private(set) var isOffering = false
    @Published private(set) var qrText: String?
    @Published private(set) var qrExpiresAt: Date?
    @Published private(set) var candidate: VeilRemotePairCandidate?
    @Published private(set) var statusText = "远程配对未启动"
    @Published private(set) var lastError: String?
    @Published private(set) var lastPairedPeerName: String?

    var onPairingCommitted: ((String) -> Void)?

    private unowned let identity: IdentityManager
    private unowned let database: DatabaseStore
    private let capabilities: VeilRelayCapabilityStore
    private let settings = VeilRelaySettings.shared
    private let session: URLSession
    private var offerContext: OfferContext?
    private var graceOfferContexts: [OfferContext] = []
    private var responseContext: ResponseContext?
    private var loopTask: Task<Void, Never>?
    private var seenPacketIDs = Set<String>()
    private var seenPacketOrder: [String] = []
    private var registeredOfferID: String?
    private var registeredRoutesAt: Date?

    private struct OfferContext {
        let localIdentityID: String
        var qr: VeilRemotePairQRCode
        let ephemeral: Curve25519.KeyAgreement.PrivateKey
        var lockedClaimID: String?
        var peerProof: VeilRemotePairIdentityProof?
        var responderEphemeralPublicKey: Data?
        var bootstrapKey: SymmetricKey?
        var pairSecret: Data?
        var localConfirmed = false
        var remoteConfirmed = false
    }

    private struct ResponseContext {
        let localIdentityID: String
        let qr: VeilRemotePairQRCode
        let ephemeral: Curve25519.KeyAgreement.PrivateKey
        let claimID: String
        let localProof: VeilRemotePairIdentityProof
        let bootstrapKey: SymmetricKey
        var peerProof: VeilRemotePairIdentityProof?
        var pairSecret: Data?
        var localConfirmed = false
        var remoteConfirmed = false
        let startedAt: Date
    }

    init(identity: IdentityManager, database: DatabaseStore, capabilities: VeilRelayCapabilityStore) {
        self.identity = identity
        self.database = database
        self.capabilities = capabilities
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 7
        configuration.timeoutIntervalForResource = 12
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    var hasConfiguredRelay: Bool { !configuredRegions.isEmpty }

    func startOffering() {
        lastError = nil
        responseContext = nil
        guard identity.activeIdentity != nil else {
            lastError = "请先创建并解锁 VeilLink 身份。"
            return
        }
        guard hasConfiguredRelay else {
            lastError = VeilRemotePairError.noRelayEndpoint.localizedDescription
            return
        }
        do {
            try rotateOffer()
            isOffering = true
            restartLoop()
        } catch {
            fail(error)
        }
    }

    func refreshOfferNow() {
        guard hasConfiguredRelay else { fail(VeilRemotePairError.noRelayEndpoint); return }
        do {
            try rotateOffer()
            isOffering = true
            restartLoop()
        } catch { fail(error) }
    }

    func stop() {
        loopTask?.cancel(); loopTask = nil
        offerContext = nil
        graceOfferContexts.removeAll(keepingCapacity: false)
        responseContext = nil
        candidate = nil
        qrText = nil
        qrExpiresAt = nil
        isOffering = false
        registeredOfferID = nil
        registeredRoutesAt = nil
        statusText = "远程配对未启动"
    }

    func resetForIdentityChange() { stop() }

    func consumeQRCode(_ text: String) {
        lastError = nil
        guard let localIdentity = identity.activeIdentity else {
            lastError = "请先创建并解锁 VeilLink 身份。"
            return
        }
        guard hasConfiguredRelay else { fail(VeilRemotePairError.noRelayEndpoint); return }
        do {
            let qr = try VeilRemotePairQRCodeCodec.decode(text)
            offerContext = nil
            graceOfferContexts.removeAll(keepingCapacity: false)
            isOffering = false
            qrText = nil
            qrExpiresAt = nil
            let responderEphemeral = Curve25519.KeyAgreement.PrivateKey()
            let claimID = UUID().uuidString
            let bootstrap = try VeilRemotePairCrypto.bootstrapKey(
                localEphemeralPrivateKey: responderEphemeral,
                remoteEphemeralPublicKey: qr.initiatorEphemeralPublicKey,
                qr: qr
            )
            let proof = try VeilRemotePairCrypto.makeIdentityProof(
                identity: localIdentity,
                signingKey: identity.signingKey(),
                qr: qr,
                claimID: claimID,
                initiatorEphemeralPublicKey: qr.initiatorEphemeralPublicKey,
                responderEphemeralPublicKey: responderEphemeral.publicKey.rawRepresentation,
                role: .responder,
                nonce: PasswordKDF.randomData(count: 24)
            )
            registeredOfferID = nil
            registeredRoutesAt = nil
            responseContext = ResponseContext(
                localIdentityID: localIdentity.id,
                qr: qr,
                ephemeral: responderEphemeral,
                claimID: claimID,
                localProof: proof,
                bootstrapKey: bootstrap,
                peerProof: nil,
                pairSecret: nil,
                localConfirmed: false,
                remoteConfirmed: false,
                startedAt: Date()
            )
            candidate = nil
            statusText = "正在通过双 Relay 提交一次性配对请求"
            restartLoop()
            Task { @MainActor [weak self] in await self?.sendClaim() }
        } catch { fail(error) }
    }

    func confirmCandidate() {
        guard var current = candidate else { return }
        guard Date() <= current.expiresAt else {
            expireCurrentHandshake(message: "远程配对确认窗口已经过期，请重新生成或导入二维码。")
            return
        }
        current.localConfirmed = true
        candidate = current
        if offerContext != nil { offerContext?.localConfirmed = true }
        if responseContext != nil { responseContext?.localConfirmed = true }
        statusText = current.remoteConfirmed ? "双方已确认，正在写入信任关系" : "本机已确认 · 等待对方确认"
        Task { @MainActor [weak self] in
            await self?.sendConfirmation()
            self?.commitIfReady()
        }
    }

    func rejectCandidate() {
        let rejectContext = currentRejectContext()
        candidate = nil
        if offerContext != nil {
            do { try rotateOffer(); statusText = "已拒绝并刷新一次性二维码" }
            catch { fail(error) }
        } else {
            responseContext = nil
            loopTask?.cancel(); loopTask = nil
            statusText = "已拒绝远程配对"
        }
        if let rejectContext {
            Task { @MainActor [weak self] in await self?.sendReject(rejectContext) }
        }
    }

    private func rotateOffer(now: Date = Date(), preservePreviousForGrace: Bool = false) throws {
        guard let activeIdentity = identity.activeIdentity else { throw IdentityError.missingIdentity }
        if preservePreviousForGrace, let previous = offerContext, previous.lockedClaimID == nil {
            graceOfferContexts.append(previous)
            graceOfferContexts = Array(graceOfferContexts
                .filter { now <= $0.qr.expiresAt.addingTimeInterval(VeilRemotePairCrypto.handshakeGrace) }
                .suffix(2))
        } else if !preservePreviousForGrace {
            graceOfferContexts.removeAll(keepingCapacity: false)
        }
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let qr = try VeilRemotePairCrypto.makeQRCode(ephemeralPublicKey: ephemeral.publicKey.rawRepresentation, now: now)
        offerContext = OfferContext(
            localIdentityID: activeIdentity.id,
            qr: qr, ephemeral: ephemeral, lockedClaimID: nil, peerProof: nil,
            responderEphemeralPublicKey: nil, bootstrapKey: nil, pairSecret: nil,
            localConfirmed: false, remoteConfirmed: false
        )
        responseContext = nil
        candidate = nil
        qrText = try VeilRemotePairQRCodeCodec.encode(qr)
        qrExpiresAt = qr.expiresAt
        statusText = "一次性二维码已生成 · 60 秒后自动轮换"
        if !preservePreviousForGrace {
            seenPacketIDs.removeAll(keepingCapacity: true)
            seenPacketOrder.removeAll(keepingCapacity: true)
        }
        registeredOfferID = nil
        registeredRoutesAt = nil
    }

    private func restartLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.tick()
                try? await Task.sleep(nanoseconds: 850_000_000)
            }
        }
    }

    private func tick() async {
        guard let activeIdentityID = identity.activeIdentity?.id else {
            stop()
            return
        }
        if let offer = offerContext, offer.localIdentityID != activeIdentityID {
            stop()
            statusText = "身份已切换 · 旧二维码已经作废"
            return
        }
        if let response = responseContext, response.localIdentityID != activeIdentityID {
            stop()
            statusText = "身份已切换 · 远程配对已经取消"
            return
        }
        if var offer = offerContext {
            let now = Date()
            if candidate == nil, now >= offer.qr.expiresAt {
                do {
                    try rotateOffer(now: now, preservePreviousForGrace: true)
                    offer = offerContext!
                } catch { fail(error); return }
            } else if candidate != nil, now > offer.qr.expiresAt.addingTimeInterval(VeilRemotePairCrypto.handshakeGrace) {
                expireCurrentHandshake(message: "远程配对确认窗口已经过期，二维码已自动刷新。")
                return
            }
            await ensureRoutesRegistered(qr: offer.qr)
            await pollOffer(&offer)
            offerContext = offer
            if candidate == nil { await pollGraceOffers(now: now) }
            if let active = offerContext, active.localConfirmed && !active.remoteConfirmed { await sendConfirmation() }
            commitIfReady()
            return
        }
        if var response = responseContext {
            guard Date() <= response.qr.expiresAt.addingTimeInterval(VeilRemotePairCrypto.handshakeGrace) else {
                expireCurrentHandshake(message: VeilRemotePairError.handshakeExpired.localizedDescription)
                return
            }
            await ensureRoutesRegistered(qr: response.qr)
            if response.peerProof == nil { await sendClaim() }
            await pollResponse(&response)
            responseContext = response
            if response.localConfirmed && !response.remoteConfirmed { await sendConfirmation() }
            commitIfReady()
        }
    }

    private func sendClaim() async {
        guard let response = responseContext else { return }
        do {
            let inner = try VeilRemotePairCrypto.sealInner(
                response.localProof,
                key: response.bootstrapKey,
                qr: response.qr,
                claimID: response.claimID,
                kind: .claim
            )
            let packet = VeilRemotePairRelayPacket(
                version: VeilRemotePairCrypto.version,
                kind: .claim,
                logicalPacketID: UUID().uuidString,
                offerID: response.qr.offerID,
                claimID: response.claimID,
                responderEphemeralPublicKey: response.ephemeral.publicKey.rawRepresentation,
                innerCiphertext: inner,
                sentAt: Date()
            )
            await push(packet, qr: response.qr, direction: .toInitiator)
        } catch { fail(error) }
    }

    private func sendAccept(offer: OfferContext, claimID: String, bootstrapKey: SymmetricKey) async {
        guard let localIdentity = identity.activeIdentity,
              let responderEphemeral = offer.responderEphemeralPublicKey else { return }
        do {
            let proof = try VeilRemotePairCrypto.makeIdentityProof(
                identity: localIdentity,
                signingKey: identity.signingKey(),
                qr: offer.qr,
                claimID: claimID,
                initiatorEphemeralPublicKey: offer.qr.initiatorEphemeralPublicKey,
                responderEphemeralPublicKey: responderEphemeral,
                role: .initiator,
                nonce: PasswordKDF.randomData(count: 24)
            )
            let inner = try VeilRemotePairCrypto.sealInner(proof, key: bootstrapKey, qr: offer.qr, claimID: claimID, kind: .accept)
            let packet = VeilRemotePairRelayPacket(
                version: VeilRemotePairCrypto.version, kind: .accept,
                logicalPacketID: UUID().uuidString,
                offerID: offer.qr.offerID, claimID: claimID,
                responderEphemeralPublicKey: nil, innerCiphertext: inner, sentAt: Date()
            )
            await push(packet, qr: offer.qr, direction: .toResponder)
        } catch { fail(error) }
    }

    private func sendConfirmation() async {
        if let offer = offerContext,
           let claimID = offer.lockedClaimID,
           let key = offer.bootstrapKey,
           let localID = identity.activeIdentity?.id {
            await sendConfirmation(qr: offer.qr, claimID: claimID, localID: localID, key: key, direction: .toResponder)
        } else if let response = responseContext,
                  let localID = identity.activeIdentity?.id {
            await sendConfirmation(qr: response.qr, claimID: response.claimID, localID: localID, key: response.bootstrapKey, direction: .toInitiator)
        }
    }

    private func sendConfirmation(qr: VeilRemotePairQRCode, claimID: String, localID: String, key: SymmetricKey, direction: VeilRemotePairRelayDirection) async {
        do {
            let confirmation = VeilRemotePairConfirmation(
                version: VeilRemotePairCrypto.version, offerID: qr.offerID,
                claimID: claimID, identityID: localID, confirmedAt: Date()
            )
            let inner = try VeilRemotePairCrypto.sealInner(confirmation, key: key, qr: qr, claimID: claimID, kind: .confirm)
            let packet = VeilRemotePairRelayPacket(
                version: VeilRemotePairCrypto.version, kind: .confirm,
                logicalPacketID: UUID().uuidString,
                offerID: qr.offerID, claimID: claimID,
                responderEphemeralPublicKey: nil, innerCiphertext: inner, sentAt: Date()
            )
            await push(packet, qr: qr, direction: direction)
        } catch { fail(error) }
    }

    private struct RejectContext {
        let qr: VeilRemotePairQRCode
        let claimID: String
        let key: SymmetricKey
        let direction: VeilRemotePairRelayDirection
    }

    private func currentRejectContext() -> RejectContext? {
        if let offer = offerContext, let claimID = offer.lockedClaimID, let key = offer.bootstrapKey {
            return RejectContext(qr: offer.qr, claimID: claimID, key: key, direction: .toResponder)
        }
        if let response = responseContext {
            return RejectContext(qr: response.qr, claimID: response.claimID, key: response.bootstrapKey, direction: .toInitiator)
        }
        return nil
    }

    private func sendReject(_ context: RejectContext) async {
        let payload = Data("reject".utf8)
        do {
            let inner = try VeilRemotePairCrypto.sealInner(payload, key: context.key, qr: context.qr, claimID: context.claimID, kind: .reject)
            let packet = VeilRemotePairRelayPacket(
                version: VeilRemotePairCrypto.version, kind: .reject,
                logicalPacketID: UUID().uuidString,
                offerID: context.qr.offerID, claimID: context.claimID,
                responderEphemeralPublicKey: nil, innerCiphertext: inner, sentAt: Date()
            )
            await push(packet, qr: context.qr, direction: context.direction)
        } catch { }
    }

    private func pollOffer(_ offer: inout OfferContext, serverReceiptCutoff: Date? = nil) async {
        let packets = await pullAll(qr: offer.qr, direction: .toInitiator)
        for (region, stored) in packets {
            let acknowledgementQR = offer.qr
            defer { Task { @MainActor [weak self] in await self?.ack(stored.packetID, qr: acknowledgementQR, region: region, direction: .toInitiator) } }
            do {
                let packet = try VeilRemotePairCrypto.openRelayPacket(stored.body, qr: offer.qr, region: region, direction: .toInitiator)
                guard remember(packet.logicalPacketID) else { continue }
                switch packet.kind {
                case .claim:
                    if let cutoff = serverReceiptCutoff {
                        guard let receivedAt = stored.receivedAt,
                              receivedAt <= cutoff.addingTimeInterval(15),
                              receivedAt >= offer.qr.createdAt.addingTimeInterval(-15) else { continue }
                    } else {
                        guard Date() <= offer.qr.expiresAt.addingTimeInterval(2) else { continue }
                    }
                    guard packet.sentAt <= offer.qr.expiresAt.addingTimeInterval(15),
                          let responderEphemeral = packet.responderEphemeralPublicKey,
                          responderEphemeral.count == 32 else { continue }
                    if let locked = offer.lockedClaimID, locked != packet.claimID { continue }
                    let bootstrap = try VeilRemotePairCrypto.bootstrapKey(
                        localEphemeralPrivateKey: offer.ephemeral,
                        remoteEphemeralPublicKey: responderEphemeral,
                        qr: offer.qr
                    )
                    let proof = try VeilRemotePairCrypto.openInner(
                        VeilRemotePairIdentityProof.self,
                        ciphertext: packet.innerCiphertext,
                        key: bootstrap,
                        qr: offer.qr,
                        claimID: packet.claimID,
                        kind: .claim
                    )
                    try VeilRemotePairCrypto.verifyIdentityProof(
                        proof, qr: offer.qr, claimID: packet.claimID,
                        initiatorEphemeralPublicKey: offer.qr.initiatorEphemeralPublicKey,
                        responderEphemeralPublicKey: responderEphemeral,
                        role: .responder
                    )
                    guard proof.identityID != identity.activeIdentity?.id else { throw VeilRemotePairError.selfPairing }
                    offer.lockedClaimID = packet.claimID
                    offer.peerProof = proof
                    offer.responderEphemeralPublicKey = responderEphemeral
                    offer.bootstrapKey = bootstrap
                    if let local = identity.activeIdentity {
                        let pairSecret = try VeilRemotePairCrypto.finalPairSecret(
                            localEphemeralPrivateKey: offer.ephemeral,
                            remoteEphemeralPublicKey: responderEphemeral,
                            qr: offer.qr,
                            initiatorIdentityID: local.id,
                            responderIdentityID: proof.identityID,
                            initiatorPublicKey: local.publicKey,
                            responderPublicKey: proof.identityPublicKey
                        )
                        offer.pairSecret = pairSecret
                        let sas = VeilRemotePairCrypto.sas(pairSecret: pairSecret, offerID: offer.qr.offerID, initiatorIdentityID: local.id, responderIdentityID: proof.identityID)
                        candidate = VeilRemotePairCandidate(
                            id: packet.claimID, role: .initiator,
                            peerIdentityID: proof.identityID, peerDisplayName: proof.displayName,
                            peerPublicKey: proof.identityPublicKey, sas: sas,
                            expiresAt: offer.qr.expiresAt.addingTimeInterval(VeilRemotePairCrypto.handshakeGrace),
                            localConfirmed: offer.localConfirmed, remoteConfirmed: offer.remoteConfirmed
                        )
                        statusText = "收到远程配对请求 · 请核对双方六码"
                        await sendAccept(offer: offer, claimID: packet.claimID, bootstrapKey: bootstrap)
                    }
                case .confirm:
                    guard let locked = offer.lockedClaimID, locked == packet.claimID, let key = offer.bootstrapKey else { continue }
                    let confirmation = try VeilRemotePairCrypto.openInner(VeilRemotePairConfirmation.self, ciphertext: packet.innerCiphertext, key: key, qr: offer.qr, claimID: packet.claimID, kind: .confirm)
                    guard confirmation.version == VeilRemotePairCrypto.version,
                          confirmation.offerID == offer.qr.offerID,
                          confirmation.claimID == packet.claimID,
                          confirmation.identityID == offer.peerProof?.identityID,
                          abs(confirmation.confirmedAt.timeIntervalSinceNow) <= VeilRemotePairCrypto.handshakeGrace else { continue }
                    offer.remoteConfirmed = true
                    if var c = candidate { c.remoteConfirmed = true; candidate = c }
                    statusText = offer.localConfirmed ? "双方已确认，正在完成配对" : "对方已确认 · 等待本机确认"
                case .reject:
                    statusText = "对方已取消配对 · 已刷新二维码"
                    try rotateOffer()
                    if let refreshed = offerContext { offer = refreshed }
                    return
                case .accept:
                    continue
                }
            } catch { continue }
        }
    }

    private func pollGraceOffers(now: Date) async {
        graceOfferContexts.removeAll { now > $0.qr.expiresAt.addingTimeInterval(VeilRemotePairCrypto.handshakeGrace) }
        guard candidate == nil, !graceOfferContexts.isEmpty else { return }

        for index in graceOfferContexts.indices.reversed() {
            var grace = graceOfferContexts[index]
            await pollOffer(&grace, serverReceiptCutoff: grace.qr.expiresAt)
            graceOfferContexts[index] = grace
            if candidate != nil, grace.lockedClaimID != nil {
                // The claim reached a Relay while that QR was still valid. Promote the old
                // ephemeral context only for completing the authenticated handshake; the stale
                // QR itself is no longer displayed or accepted as a fresh capability.
                offerContext = grace
                graceOfferContexts.removeAll(keepingCapacity: false)
                qrText = nil
                qrExpiresAt = grace.qr.expiresAt.addingTimeInterval(VeilRemotePairCrypto.handshakeGrace)
                statusText = "已取回有效期内到达的远程请求 · 请核对双方六码"
                return
            }
        }
    }

    private func pollResponse(_ response: inout ResponseContext) async {
        let packets = await pullAll(qr: response.qr, direction: .toResponder)
        for (region, stored) in packets {
            let acknowledgementQR = response.qr
            defer { Task { @MainActor [weak self] in await self?.ack(stored.packetID, qr: acknowledgementQR, region: region, direction: .toResponder) } }
            do {
                let packet = try VeilRemotePairCrypto.openRelayPacket(stored.body, qr: response.qr, region: region, direction: .toResponder)
                guard remember(packet.logicalPacketID), packet.claimID == response.claimID else { continue }
                switch packet.kind {
                case .accept:
                    let proof = try VeilRemotePairCrypto.openInner(VeilRemotePairIdentityProof.self, ciphertext: packet.innerCiphertext, key: response.bootstrapKey, qr: response.qr, claimID: response.claimID, kind: .accept)
                    try VeilRemotePairCrypto.verifyIdentityProof(
                        proof, qr: response.qr, claimID: response.claimID,
                        initiatorEphemeralPublicKey: response.qr.initiatorEphemeralPublicKey,
                        responderEphemeralPublicKey: response.ephemeral.publicKey.rawRepresentation,
                        role: .initiator
                    )
                    guard proof.identityID != identity.activeIdentity?.id else { throw VeilRemotePairError.selfPairing }
                    response.peerProof = proof
                    if let local = identity.activeIdentity {
                        let pairSecret = try VeilRemotePairCrypto.finalPairSecret(
                            localEphemeralPrivateKey: response.ephemeral,
                            remoteEphemeralPublicKey: response.qr.initiatorEphemeralPublicKey,
                            qr: response.qr,
                            initiatorIdentityID: proof.identityID,
                            responderIdentityID: local.id,
                            initiatorPublicKey: proof.identityPublicKey,
                            responderPublicKey: local.publicKey
                        )
                        response.pairSecret = pairSecret
                        let sas = VeilRemotePairCrypto.sas(pairSecret: pairSecret, offerID: response.qr.offerID, initiatorIdentityID: proof.identityID, responderIdentityID: local.id)
                        candidate = VeilRemotePairCandidate(
                            id: response.claimID, role: .responder,
                            peerIdentityID: proof.identityID, peerDisplayName: proof.displayName,
                            peerPublicKey: proof.identityPublicKey, sas: sas,
                            expiresAt: response.qr.expiresAt.addingTimeInterval(VeilRemotePairCrypto.handshakeGrace),
                            localConfirmed: response.localConfirmed, remoteConfirmed: response.remoteConfirmed
                        )
                        statusText = "已验证发起方身份 · 请核对双方六码"
                    }
                case .confirm:
                    guard let peer = response.peerProof else { continue }
                    let confirmation = try VeilRemotePairCrypto.openInner(VeilRemotePairConfirmation.self, ciphertext: packet.innerCiphertext, key: response.bootstrapKey, qr: response.qr, claimID: response.claimID, kind: .confirm)
                    guard confirmation.version == VeilRemotePairCrypto.version,
                          confirmation.offerID == response.qr.offerID,
                          confirmation.claimID == response.claimID,
                          confirmation.identityID == peer.identityID,
                          abs(confirmation.confirmedAt.timeIntervalSinceNow) <= VeilRemotePairCrypto.handshakeGrace else { continue }
                    response.remoteConfirmed = true
                    if var c = candidate { c.remoteConfirmed = true; candidate = c }
                    statusText = response.localConfirmed ? "双方已确认，正在完成配对" : "对方已确认 · 等待本机确认"
                case .reject:
                    expireCurrentHandshake(message: "对方拒绝了这次配对。")
                    return
                case .claim:
                    continue
                }
            } catch { continue }
        }
    }

    private func commitIfReady() {
        if let offer = offerContext,
           offer.localConfirmed, offer.remoteConfirmed,
           let proof = offer.peerProof,
           let pairSecret = offer.pairSecret {
            if commit(peer: proof, pairSecret: pairSecret) {
                offerContext = nil
                finishSuccess(name: proof.displayName)
            }
            return
        }
        if let response = responseContext,
           response.localConfirmed, response.remoteConfirmed,
           let proof = response.peerProof,
           let pairSecret = response.pairSecret {
            if commit(peer: proof, pairSecret: pairSecret) {
                responseContext = nil
                finishSuccess(name: proof.displayName)
            }
        }
    }

    @discardableResult
    private func commit(peer: VeilRemotePairIdentityProof, pairSecret: Data) -> Bool {
        guard let localID = identity.activeIdentity?.id else { return false }
        do {
            try database.trustPeer(localIdentityID: localID, identityID: peer.identityID, displayName: peer.displayName, publicKey: peer.identityPublicKey)
            if database.conversationID(localIdentityID: localID, for: peer.identityID) == nil {
                _ = try database.createConversation(localIdentityID: localID, peerIdentityID: peer.identityID, title: peer.displayName)
            }
            try capabilities.installRemotePairingSecret(pairSecret, peerIdentityID: peer.identityID)
            onPairingCommitted?(peer.identityID)
            return true
        } catch {
            fail(error)
            return false
        }
    }

    private func finishSuccess(name: String) {
        candidate = nil
        qrText = nil
        qrExpiresAt = nil
        isOffering = false
        loopTask?.cancel(); loopTask = nil
        registeredOfferID = nil
        registeredRoutesAt = nil
        seenPacketIDs.removeAll(keepingCapacity: true)
        seenPacketOrder.removeAll(keepingCapacity: true)
        lastPairedPeerName = name
        statusText = "已完成远程首次配对 · Internet Relay 可以建立安全会话"
    }

    private func expireCurrentHandshake(message: String) {
        let wasOffering = offerContext != nil
        candidate = nil
        responseContext = nil
        if wasOffering {
            do {
                try rotateOffer()
                isOffering = true
                statusText = message
            } catch {
                fail(error)
            }
        } else {
            offerContext = nil
            graceOfferContexts.removeAll(keepingCapacity: false)
            qrText = nil
            qrExpiresAt = nil
            isOffering = false
            loopTask?.cancel(); loopTask = nil
            registeredOfferID = nil
            registeredRoutesAt = nil
            statusText = message
        }
    }

    private var configuredRegions: [VeilRelayRegion] {
        VeilRelayRegion.allCases.filter { settings.configuration(for: $0).enabled && settings.configuration(for: $0).baseURL != nil }
    }

    private func ensureRoutesRegistered(qr: VeilRemotePairQRCode) async {
        let now = Date()
        if registeredOfferID == qr.offerID,
           let last = registeredRoutesAt,
           now.timeIntervalSince(last) < 45 { return }
        await registerRoutes(qr: qr)
        registeredOfferID = qr.offerID
        registeredRoutesAt = now
    }

    private func registerRoutes(qr: VeilRemotePairQRCode) async {
        for region in configuredRegions {
            for direction in [VeilRemotePairRelayDirection.toInitiator, .toResponder] {
                guard let route = try? VeilRemotePairCrypto.route(qr: qr, region: region, direction: direction) else { continue }
                let request = VeilRelayRegisterRequest(
                    version: VeilRelayCrypto.protocolVersion,
                    mailbox: route.mailbox,
                    readToken: route.readToken,
                    writeToken: route.writeToken,
                    expiresAt: Date().addingTimeInterval(180)
                )
                _ = await postJSON(request, region: region, path: "v1/register")
            }
        }
    }

    private func push(_ packet: VeilRemotePairRelayPacket, qr: VeilRemotePairQRCode, direction: VeilRemotePairRelayDirection) async {
        for region in configuredRegions {
            do {
                let route = try VeilRemotePairCrypto.route(qr: qr, region: region, direction: direction)
                let body = try VeilRemotePairCrypto.sealRelayPacket(packet, qr: qr, region: region, direction: direction)
                let request = VeilRelayPushRequest(
                    version: VeilRelayCrypto.protocolVersion,
                    packetID: UUID().uuidString,
                    mailbox: route.mailbox,
                    writeToken: route.writeToken,
                    expiresAt: Date().addingTimeInterval(180),
                    body: body
                )
                _ = await postJSON(request, region: region, path: "v1/push")
            } catch { continue }
        }
    }

    private func pullAll(qr: VeilRemotePairQRCode, direction: VeilRemotePairRelayDirection) async -> [(VeilRelayRegion, VeilRelayStoredPacket)] {
        var result: [(VeilRelayRegion, VeilRelayStoredPacket)] = []
        for region in configuredRegions {
            guard let route = try? VeilRemotePairCrypto.route(qr: qr, region: region, direction: direction),
                  let base = settings.configuration(for: region).baseURL else { continue }
            var components = URLComponents(url: base.appendingPathComponent("v1/pull"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "mailbox", value: route.mailbox)]
            guard let url = components?.url else { continue }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(route.readToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 5
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
                let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
                let payload = try decoder.decode(VeilRelayPullResponse.self, from: data)
                result.append(contentsOf: payload.packets.prefix(12).map { (region, $0) })
            } catch { continue }
        }
        return result
    }

    private func ack(_ packetID: String, qr: VeilRemotePairQRCode, region: VeilRelayRegion, direction: VeilRemotePairRelayDirection) async {
        guard let route = try? VeilRemotePairCrypto.route(qr: qr, region: region, direction: direction) else { return }
        _ = await postJSON(
            VeilRelayAckRequest(version: VeilRelayCrypto.protocolVersion, mailbox: route.mailbox, readToken: route.readToken, packetIDs: [packetID]),
            region: region, path: "v1/ack"
        )
    }

    private func postJSON<T: Encodable>(_ value: T, region: VeilRelayRegion, path: String) async -> Bool {
        guard let base = settings.configuration(for: region).baseURL else { return false }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 6
        do {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
            request.httpBody = try encoder.encode(value)
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
            return true
        } catch { return false }
    }

    private func remember(_ packetID: String) -> Bool {
        guard seenPacketIDs.insert(packetID).inserted else { return false }
        seenPacketOrder.append(packetID)
        if seenPacketOrder.count > 256 {
            for old in seenPacketOrder.prefix(seenPacketOrder.count - 256) { seenPacketIDs.remove(old) }
            seenPacketOrder.removeFirst(seenPacketOrder.count - 256)
        }
        return true
    }

    private func fail(_ error: Error) {
        lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        statusText = lastError ?? "远程配对失败"
    }
}
