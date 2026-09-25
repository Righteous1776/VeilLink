import Combine
import CryptoKit
import Foundation

struct VeilCommunityMessageRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let roomID: UUID
    let sentAt: Date
    let body: String
    let senderMode: VeilCommunityIdentityMode
    let senderAlias: String
    let senderIdentityID: String?
    let isOutgoing: Bool
}

struct VeilCommunityDiscoveredChannel: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let hopCount: UInt8
    let discoveredAt: Date
    fileprivate let inviteToken: Data

    var ageText: String {
        let seconds = max(0, Int(Date().timeIntervalSince(discoveredAt)))
        if seconds < 60 { return "刚刚" }
        return "\(seconds / 60) 分钟前"
    }
}

private struct VeilCommunityPersistedState: Codable {
    var rooms: [VeilCommunityRoom]
    var messages: [VeilCommunityMessageRecord]
}

private struct VeilCommunityInvite: Codable {
    let room: VeilCommunityRoom
    let roomKey: Data
}

private struct VeilCommunityChannelBeacon: Codable {
    let version: UInt8
    let room: VeilCommunityRoom
    let inviteToken: Data
    let announcedAt: Date
    let signature: Data

    var signedPayload: Data {
        var data = Data("VeilLink/ChannelBeacon/v1|\(room.id.uuidString)|\(room.title)|\(room.epoch)|\(Int64(announcedAt.timeIntervalSince1970 * 1000))|".utf8)
        data.append(inviteToken)
        return data
    }
}

@MainActor
final class VeilCommunityStore: ObservableObject {
    @Published private(set) var rooms: [VeilCommunityRoom] = []
    @Published private(set) var messages: [VeilCommunityMessageRecord] = []
    @Published private(set) var discoveredChannels: [VeilCommunityDiscoveredChannel] = []
    @Published var lastError: String?

    var onOutboundMeshPacket: ((VeilMeshPacket) -> Void)?

    private let keychain: KeychainStore
    private let identity: IdentityManager
    private let baseDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cancellables = Set<AnyCancellable>()

    private var stateURL: URL {
        let scope = identity.activeIdentity?.id.replacingOccurrences(of: "/", with: "_") ?? "unscoped"
        return baseDirectory.appendingPathComponent("community-\(scope)-v1.json")
    }

    init(keychain: KeychainStore, identity: IdentityManager) {
        self.keychain = keychain
        self.identity = identity
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("VeilLink", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.baseDirectory = dir
        load()
        identity.$activeIdentity
            .map { $0?.id }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.reloadForActiveIdentity() }
            .store(in: &cancellables)
    }

    func reloadForActiveIdentity() {
        rooms.removeAll(keepingCapacity: false)
        messages.removeAll(keepingCapacity: false)
        discoveredChannels.removeAll(keepingCapacity: false)
        load()
    }

    func createRoom(title: String, kind: VeilCommunityRoomKind, discoverable: Bool) -> VeilCommunityRoom? {
        guard let active = identity.activeIdentity else { return nil }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.lengthOfBytes(using: .utf8) <= 80 else { return nil }
        let authority = Curve25519.Signing.PrivateKey()
        let room = VeilCommunityRoom(
            id: UUID(),
            title: normalized,
            kind: kind,
            createdAt: Date(),
            ownerIdentityID: kind == .privateGroup ? active.id : nil,
            authorityPublicKey: authority.publicKey.rawRepresentation,
            epoch: 1,
            defaultHopLimit: kind == .publicChannel ? 8 : 5,
            isDiscoverable: discoverable
        )
        let key = VeilCommunityCrypto.generateRoomKey()
        do {
            try keychain.set(key, for: roomKeyName(room.id, room.epoch))
            try keychain.set(authority.rawRepresentation, for: authorityKeyName(room.id))
            if kind == .publicChannel {
                let anon = VeilCommunityCrypto.anonymousSigningKey()
                try keychain.set(anon.rawRepresentation, for: anonymousKeyName(room.id))
            }
            rooms.append(room)
            persist()
            if kind == .publicChannel, discoverable { announce(room: room) }
            return room
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func send(body: String, roomID: UUID, mode: VeilCommunityIdentityMode) {
        guard let room = rooms.first(where: { $0.id == roomID }),
              let roomKey = roomKey(room) else { return }
        do {
            let signingKey: Curve25519.Signing.PrivateKey
            let realIdentityID: String?
            switch mode {
            case .identified:
                signingKey = try identity.signingKey()
                realIdentityID = identity.activeIdentity?.id
            case .anonymous:
                signingKey = try anonymousKey(for: room)
                realIdentityID = nil
            }
            let sealed = try VeilCommunityCrypto.seal(
                body: body,
                room: room,
                roomKey: roomKey,
                senderMode: mode,
                realIdentityID: realIdentityID,
                signingKey: signingKey
            )
            let payload = try encoder.encode(sealed)
            let packet = try VeilMeshPacket(
                kind: .roomMessage,
                scope: .roomBroadcast,
                roomID: room.id,
                hopLimit: room.defaultHopLimit,
                sealedPayload: payload
            )
            let clear = try VeilCommunityCrypto.open(sealed, room: room, roomKey: roomKey)
            append(clear: clear, outgoing: true)
            onOutboundMeshPacket?(packet)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func receive(_ packet: VeilMeshPacket) {
        switch packet.kind {
        case .roomMessage:
            receiveRoomMessage(packet)
        case .channelBeacon:
            receiveChannelBeacon(packet)
        default:
            break
        }
    }

    func announceDiscoverableRooms() {
        discoveredChannels.removeAll { Date().timeIntervalSince($0.discoveredAt) > 120 }
        for room in rooms where room.kind == .publicChannel && room.isDiscoverable {
            announce(room: room)
        }
    }

    func inviteToken(roomID: UUID) -> Data? {
        guard let room = rooms.first(where: { $0.id == roomID }), let key = roomKey(room) else { return nil }
        return try? encoder.encode(VeilCommunityInvite(room: room, roomKey: key))
    }

    func inviteCode(roomID: UUID) -> String? {
        inviteToken(roomID: roomID)?.base64EncodedString()
    }

    func join(inviteCode: String) -> VeilCommunityRoom? {
        guard let data = Data(base64Encoded: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return join(inviteToken: data)
    }

    func join(inviteToken: Data) -> VeilCommunityRoom? {
        guard inviteToken.count <= 16 * 1_024,
              let invite = try? decoder.decode(VeilCommunityInvite.self, from: inviteToken),
              invite.roomKey.count == 32,
              invite.room.authorityPublicKey.count == 32,
              invite.room.defaultHopLimit > 0,
              invite.room.defaultHopLimit <= VeilMeshPacket.maximumHopLimit else { return nil }
        do {
            try keychain.set(invite.roomKey, for: roomKeyName(invite.room.id, invite.room.epoch))
            if invite.room.kind == .publicChannel, keychain.data(for: anonymousKeyName(invite.room.id)) == nil {
                try keychain.set(VeilCommunityCrypto.anonymousSigningKey().rawRepresentation, for: anonymousKeyName(invite.room.id))
            }
            rooms.removeAll { $0.id == invite.room.id }
            rooms.append(invite.room)
            persist()
            return invite.room
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func joinDiscoveredChannel(_ roomID: UUID) -> VeilCommunityRoom? {
        guard let channel = discoveredChannels.first(where: { $0.id == roomID }) else { return nil }
        return join(inviteToken: channel.inviteToken)
    }

    func messages(in roomID: UUID) -> [VeilCommunityMessageRecord] {
        messages.filter { $0.roomID == roomID }.sorted { $0.sentAt < $1.sentAt }
    }

    private func receiveRoomMessage(_ packet: VeilMeshPacket) {
        guard let room = rooms.first(where: { $0.id == packet.roomID }),
              let roomKey = roomKey(room),
              let sealed = try? decoder.decode(VeilCommunitySealedMessage.self, from: packet.sealedPayload) else { return }
        do {
            let clear = try VeilCommunityCrypto.open(sealed, room: room, roomKey: roomKey)
            guard !messages.contains(where: { $0.id == clear.messageID }) else { return }
            append(clear: clear, outgoing: false)
        } catch {
            lastError = "群聊消息校验失败"
        }
    }

    private func announce(room: VeilCommunityRoom) {
        guard room.kind == .publicChannel,
              room.isDiscoverable,
              let token = inviteToken(roomID: room.id),
              let authorityData = keychain.data(for: authorityKeyName(room.id)),
              let authority = try? Curve25519.Signing.PrivateKey(rawRepresentation: authorityData) else { return }
        do {
            var beacon = VeilCommunityChannelBeacon(
                version: 1,
                room: room,
                inviteToken: token,
                announcedAt: Date(),
                signature: Data()
            )
            beacon = VeilCommunityChannelBeacon(
                version: 1,
                room: room,
                inviteToken: token,
                announcedAt: beacon.announcedAt,
                signature: try authority.signature(for: beacon.signedPayload)
            )
            let packet = try VeilMeshPacket(
                kind: .channelBeacon,
                scope: .roomBroadcast,
                roomID: room.id,
                hopLimit: min(8, room.defaultHopLimit),
                sealedPayload: try encoder.encode(beacon)
            )
            onOutboundMeshPacket?(packet)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func receiveChannelBeacon(_ packet: VeilMeshPacket) {
        guard packet.sealedPayload.count <= 24 * 1_024,
              let beacon = try? decoder.decode(VeilCommunityChannelBeacon.self, from: packet.sealedPayload),
              beacon.version == 1,
              beacon.room.id == packet.roomID,
              beacon.room.kind == .publicChannel,
              beacon.room.isDiscoverable,
              beacon.room.authorityPublicKey.count == 32,
              abs(beacon.announcedAt.timeIntervalSinceNow) <= 180,
              let authority = try? Curve25519.Signing.PublicKey(rawRepresentation: beacon.room.authorityPublicKey),
              authority.isValidSignature(beacon.signature, for: beacon.signedPayload),
              let invite = try? decoder.decode(VeilCommunityInvite.self, from: beacon.inviteToken),
              invite.room == beacon.room,
              invite.roomKey.count == 32 else { return }
        guard !rooms.contains(where: { $0.id == beacon.room.id }) else { return }
        let record = VeilCommunityDiscoveredChannel(
            id: beacon.room.id,
            title: beacon.room.title,
            hopCount: packet.hopCount,
            discoveredAt: Date(),
            inviteToken: beacon.inviteToken
        )
        discoveredChannels.removeAll { $0.id == record.id }
        discoveredChannels.append(record)
        discoveredChannels.sort { $0.discoveredAt > $1.discoveredAt }
        if discoveredChannels.count > 128 { discoveredChannels.removeLast(discoveredChannels.count - 128) }
    }

    private func append(clear: VeilCommunityMessageCleartext, outgoing: Bool) {
        messages.append(VeilCommunityMessageRecord(
            id: clear.messageID,
            roomID: clear.roomID,
            sentAt: clear.sentAt,
            body: clear.body,
            senderMode: clear.senderMode,
            senderAlias: clear.senderAlias,
            senderIdentityID: clear.senderIdentityID,
            isOutgoing: outgoing
        ))
        if messages.count > 20_000 { messages.removeFirst(messages.count - 20_000) }
        persist()
    }

    private func roomKey(_ room: VeilCommunityRoom) -> Data? {
        keychain.data(for: roomKeyName(room.id, room.epoch))
    }

    private func anonymousKey(for room: VeilCommunityRoom) throws -> Curve25519.Signing.PrivateKey {
        let name = anonymousKeyName(room.id)
        if let data = keychain.data(for: name) {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        }
        let key = VeilCommunityCrypto.anonymousSigningKey()
        try keychain.set(key.rawRepresentation, for: name)
        return key
    }

    private var identityScope: String { identity.activeIdentity?.id ?? "unscoped" }
    private func roomKeyName(_ id: UUID, _ epoch: UInt32) -> String { "community.\(identityScope).room.\(id.uuidString).epoch.\(epoch)" }
    private func anonymousKeyName(_ id: UUID) -> String { "community.\(identityScope).room.\(id.uuidString).anonymous-signing" }
    private func authorityKeyName(_ id: UUID) -> String { "community.\(identityScope).room.\(id.uuidString).authority-signing" }

    private func load() {
        guard let data = try? Data(contentsOf: stateURL),
              data.count <= 8 * 1_024 * 1_024,
              let state = try? decoder.decode(VeilCommunityPersistedState.self, from: data) else { return }
        rooms = state.rooms
        messages = state.messages
    }

    private func persist() {
        let state = VeilCommunityPersistedState(rooms: rooms, messages: messages)
        guard let data = try? encoder.encode(state), data.count <= 8 * 1_024 * 1_024 else { return }
        try? data.write(to: stateURL, options: .atomic)
    }
}
