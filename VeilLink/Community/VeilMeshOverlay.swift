import Combine
import Foundation

// Application-layer mesh routing for VeilLink. Physical transports remain BLE/LAN/P2P Wi-Fi.
enum VeilMeshPayloadKind: UInt8, Codable, Sendable {
    case roomMessage = 1
    case roomControl = 2
    case channelBeacon = 3
    case channelJoin = 4
    case channelLeave = 5
    case presence = 6
}

enum VeilMeshDeliveryScope: UInt8, Codable, Sendable {
    case roomBroadcast = 1
    case directed = 2
}

struct VeilMeshPacket: Codable, Equatable, Sendable {
    static let protocolVersion: UInt8 = 1
    static let maximumHopLimit: UInt8 = 8
    static let maximumPayloadBytes = 72 * 1_024

    let version: UInt8
    let packetID: UUID
    let kind: VeilMeshPayloadKind
    let scope: VeilMeshDeliveryScope
    let roomID: UUID
    let destinationTag: Data?
    let createdAt: Date
    let hopLimit: UInt8
    let hopCount: UInt8
    let sealedPayload: Data

    init(
        packetID: UUID = UUID(),
        kind: VeilMeshPayloadKind,
        scope: VeilMeshDeliveryScope,
        roomID: UUID,
        destinationTag: Data? = nil,
        createdAt: Date = Date(),
        hopLimit: UInt8 = 6,
        hopCount: UInt8 = 0,
        sealedPayload: Data
    ) throws {
        guard !sealedPayload.isEmpty,
              sealedPayload.count <= Self.maximumPayloadBytes,
              hopLimit > 0,
              hopLimit <= Self.maximumHopLimit,
              hopCount <= hopLimit,
              destinationTag == nil || destinationTag?.count == 16 else {
            throw VeilMeshError.invalidPacket
        }
        self.version = Self.protocolVersion
        self.packetID = packetID
        self.kind = kind
        self.scope = scope
        self.roomID = roomID
        self.destinationTag = destinationTag
        self.createdAt = createdAt
        self.hopLimit = hopLimit
        self.hopCount = hopCount
        self.sealedPayload = sealedPayload
    }

    var canRelay: Bool { hopCount < hopLimit }

    func relayed() throws -> VeilMeshPacket {
        guard canRelay else { throw VeilMeshError.hopLimitReached }
        return try VeilMeshPacket(
            packetID: packetID,
            kind: kind,
            scope: scope,
            roomID: roomID,
            destinationTag: destinationTag,
            createdAt: createdAt,
            hopLimit: hopLimit,
            hopCount: hopCount + 1,
            sealedPayload: sealedPayload
        )
    }
}

enum VeilMeshError: Error, Equatable {
    case invalidPacket
    case oversizedPacket
    case hopLimitReached
}

enum VeilMeshCodec {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    static let maximumEncodedBytes = 80 * 1_024

    static func encode(_ packet: VeilMeshPacket) throws -> Data {
        guard packet.version == VeilMeshPacket.protocolVersion,
              packet.sealedPayload.count <= VeilMeshPacket.maximumPayloadBytes else {
            throw VeilMeshError.invalidPacket
        }
        let data = try encoder.encode(packet)
        guard data.count <= maximumEncodedBytes else { throw VeilMeshError.oversizedPacket }
        return data
    }

    static func decode(_ data: Data) throws -> VeilMeshPacket {
        guard !data.isEmpty, data.count <= maximumEncodedBytes else { throw VeilMeshError.oversizedPacket }
        let packet = try decoder.decode(VeilMeshPacket.self, from: data)
        guard packet.version == VeilMeshPacket.protocolVersion,
              packet.hopLimit > 0,
              packet.hopLimit <= VeilMeshPacket.maximumHopLimit,
              packet.hopCount <= packet.hopLimit,
              !packet.sealedPayload.isEmpty,
              packet.sealedPayload.count <= VeilMeshPacket.maximumPayloadBytes,
              packet.destinationTag == nil || packet.destinationTag?.count == 16,
              abs(packet.createdAt.timeIntervalSinceNow) <= 24 * 60 * 60 else {
            throw VeilMeshError.invalidPacket
        }
        return packet
    }
}

struct VeilMeshRelaySnapshot: Equatable, Sendable {
    let neighborCount: Int
    let seenPacketCount: Int
    let relayedPacketCount: UInt64
    let droppedDuplicateCount: UInt64
    let droppedHopLimitCount: UInt64
    let droppedRateLimitCount: UInt64
}

@MainActor
final class VeilMeshOverlayRouter: ObservableObject {
    @Published private(set) var snapshot = VeilMeshRelaySnapshot(
        neighborCount: 0,
        seenPacketCount: 0,
        relayedPacketCount: 0,
        droppedDuplicateCount: 0,
        droppedHopLimitCount: 0,
        droppedRateLimitCount: 0
    )
    @Published var relayEnabled = true

    var neighborProvider: (() -> [UUID])?
    var sendToNeighbor: ((UUID, Data) -> TransportSendResult)?
    var onLocalPacket: ((VeilMeshPacket) -> Void)?

    private var seen: [UUID: Date] = [:]
    private var seenOrder: [UUID] = []
    private var relayTimestamps: [Date] = []
    private var recentPackets: [(VeilMeshPacket, Date)] = []
    private var relayedPacketCount: UInt64 = 0
    private var droppedDuplicateCount: UInt64 = 0
    private var droppedHopLimitCount: UInt64 = 0
    private var droppedRateLimitCount: UInt64 = 0

    private let maximumSeenPackets = 8_192
    private let seenLifetime: TimeInterval = 20 * 60
    private let relayRateWindow: TimeInterval = 1.0
    private let maximumRelaysPerWindow = 96
    private let recentPacketLifetime: TimeInterval = 90
    private let maximumRecentPackets = 128

    func broadcast(_ packet: VeilMeshPacket) {
        guard markSeen(packet.packetID) else { return }
        remember(packet)
        onLocalPacket?(packet)
        forward(packet, excluding: nil)
    }

    /// Replays a short encrypted packet window when a new secure neighbor appears. Receivers
    /// deduplicate by packetID, so existing neighbors discard the replay while a new relay can
    /// carry recent room/channel traffic farther without a server.
    func replayRecent() {
        pruneRecent()
        for (packet, _) in recentPackets where packet.canRelay {
            forward(packet, excluding: nil)
        }
    }

    func receive(_ data: Data, from ingress: UUID) {
        guard let packet = try? VeilMeshCodec.decode(data) else { return }
        guard markSeen(packet.packetID) else {
            droppedDuplicateCount &+= 1
            publishSnapshot()
            return
        }
        remember(packet)
        onLocalPacket?(packet)
        guard relayEnabled else { return }
        guard packet.canRelay else {
            droppedHopLimitCount &+= 1
            publishSnapshot()
            return
        }
        guard allowRelayNow() else {
            droppedRateLimitCount &+= 1
            publishSnapshot()
            return
        }
        guard let relayed = try? packet.relayed() else { return }
        forward(relayed, excluding: ingress)
    }

    func resetTransientState() {
        seen.removeAll(keepingCapacity: false)
        seenOrder.removeAll(keepingCapacity: false)
        relayTimestamps.removeAll(keepingCapacity: false)
        recentPackets.removeAll(keepingCapacity: false)
        publishSnapshot()
    }

    private func forward(_ packet: VeilMeshPacket, excluding ingress: UUID?) {
        guard let encoded = try? VeilMeshCodec.encode(packet) else { return }
        let neighbors = Array(Set(neighborProvider?() ?? [])).filter { $0 != ingress }
        guard !neighbors.isEmpty else {
            publishSnapshot(neighborCount: 0)
            return
        }

        // Controlled flooding maximizes local reach while the seen-cache prevents loops.
        // Cap a single fan-out so one unusually dense LAN cannot explode CPU/battery use.
        let fanoutLimit = VeilDevicePerformance.current.transferVisualComplexity == .minimal ? 4 : 8
        let selected = Array(neighbors.prefix(fanoutLimit))
        for neighbor in selected {
            if sendToNeighbor?(neighbor, encoded) == .accepted {
                relayedPacketCount &+= 1
            }
        }
        publishSnapshot(neighborCount: neighbors.count)
    }

    private func markSeen(_ id: UUID) -> Bool {
        pruneSeen()
        guard seen[id] == nil else { return false }
        seen[id] = Date()
        seenOrder.append(id)
        if seenOrder.count > maximumSeenPackets {
            let overflow = seenOrder.count - maximumSeenPackets
            for id in seenOrder.prefix(overflow) { seen.removeValue(forKey: id) }
            seenOrder.removeFirst(overflow)
        }
        publishSnapshot()
        return true
    }

    private func pruneSeen() {
        let cutoff = Date().addingTimeInterval(-seenLifetime)
        var removeCount = 0
        for id in seenOrder {
            guard let date = seen[id], date < cutoff else { break }
            seen.removeValue(forKey: id)
            removeCount += 1
        }
        if removeCount > 0 { seenOrder.removeFirst(removeCount) }
    }

    private func remember(_ packet: VeilMeshPacket) {
        pruneRecent()
        recentPackets.append((packet, Date()))
        if recentPackets.count > maximumRecentPackets {
            recentPackets.removeFirst(recentPackets.count - maximumRecentPackets)
        }
    }

    private func pruneRecent() {
        let cutoff = Date().addingTimeInterval(-recentPacketLifetime)
        recentPackets.removeAll { $0.1 < cutoff }
    }

    private func allowRelayNow() -> Bool {
        let cutoff = Date().addingTimeInterval(-relayRateWindow)
        relayTimestamps.removeAll { $0 < cutoff }
        guard relayTimestamps.count < maximumRelaysPerWindow else { return false }
        relayTimestamps.append(Date())
        return true
    }

    private func publishSnapshot(neighborCount: Int? = nil) {
        snapshot = VeilMeshRelaySnapshot(
            neighborCount: neighborCount ?? Set(neighborProvider?() ?? []).count,
            seenPacketCount: seen.count,
            relayedPacketCount: relayedPacketCount,
            droppedDuplicateCount: droppedDuplicateCount,
            droppedHopLimitCount: droppedHopLimitCount,
            droppedRateLimitCount: droppedRateLimitCount
        )
    }
}
