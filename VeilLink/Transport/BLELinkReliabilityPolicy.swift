import Foundation

enum BLESendPriority: Int, Comparable {
    case bulk = 0
    case control = 1

    static func < (lhs: BLESendPriority, rhs: BLESendPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum BLELinkQuality: String, Equatable {
    case unknown
    case strong
    case good
    case marginal
    case weak
}

struct BLELinkTuning: Equatable {
    let quality: BLELinkQuality
    let packetBurstLimit: Int
    let targetBurstBytes: Int
    let interBurstDelay: TimeInterval
}

struct BLEQueueBudget: Equatable {
    /// Extra capacity available only to control traffic after bulk reaches its normal cap.
    let controlOverflowPackets: Int
    let controlOverflowBytes: Int
}

enum BLELinkReliabilityPolicy {
    static func normalizedRSSI(_ sample: Int) -> Int? {
        guard sample != 127, sample < 0, sample >= -110 else { return nil }
        return min(-20, sample)
    }

    static func smoothedRSSI(previous: Double?, sample: Int) -> Double? {
        guard let normalized = normalizedRSSI(sample) else { return previous }
        let next = Double(normalized)
        guard let previous else { return next }
        // Deliberately slow enough to avoid changing pacing on every advertisement,
        // but responsive enough to react while a user is walking away from a peer.
        return previous * 0.72 + next * 0.28
    }

    static func quality(rssi: Int?) -> BLELinkQuality {
        guard let rssi else { return .unknown }
        switch rssi {
        case let value where value >= -62: return .strong
        case -72 ... -63: return .good
        case -82 ... -73: return .marginal
        default: return .weak
        }
    }

    static func tuning(rssi: Int?, machineIdentifier: String) -> BLELinkTuning {
        let quality = quality(rssi: rssi)
        let isSE1 = machineIdentifier == "iPhone8,4"
        let isIPhone7 = ["iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4"].contains(machineIdentifier)
        let legacy = isSE1 || isIPhone7

        switch quality {
        case .strong:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: isSE1 ? 48 : (isIPhone7 ? 64 : 96),
                targetBurstBytes: isSE1 ? 6 * 1_024 : (isIPhone7 ? 8 * 1_024 : 16 * 1_024),
                interBurstDelay: legacy ? 0.002 : 0
            )
        case .good:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: isSE1 ? 40 : (isIPhone7 ? 56 : 80),
                targetBurstBytes: isSE1 ? 4 * 1_024 : (isIPhone7 ? 6 * 1_024 : 12 * 1_024),
                interBurstDelay: legacy ? 0.004 : 0.002
            )
        case .marginal:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: isSE1 ? 20 : (isIPhone7 ? 28 : 40),
                targetBurstBytes: isSE1 ? 2 * 1_024 : (isIPhone7 ? 3 * 1_024 : 6 * 1_024),
                interBurstDelay: legacy ? 0.010 : 0.007
            )
        case .weak:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: legacy ? 12 : 18,
                targetBurstBytes: legacy ? 1_024 : 2 * 1_024,
                interBurstDelay: legacy ? 0.020 : 0.014
            )
        case .unknown:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: isSE1 ? 28 : (isIPhone7 ? 40 : 64),
                targetBurstBytes: isSE1 ? 3 * 1_024 : (isIPhone7 ? 4 * 1_024 : 8 * 1_024),
                interBurstDelay: legacy ? 0.006 : 0.003
            )
        }
    }

    /// Converts the byte-oriented pacing budget into a packet limit for the negotiated ATT MTU.
    /// The hard packet cap prevents a 20-byte legacy link from monopolising the transport queue,
    /// while a wider MTU can use the full byte budget without waiting for artificial packet rounds.
    static func effectivePacketBurstLimit(tuning: BLELinkTuning, maximumPacketSize: Int) -> Int {
        guard maximumPacketSize > 0 else { return 1 }
        let byteBound = max(1, tuning.targetBurstBytes / maximumPacketSize)
        return max(1, min(tuning.packetBurstLimit, byteBound))
    }

    /// Bulk traffic keeps the device-specific historical cap so a 48 KiB image chunk can still
    /// fit even on a legacy 20-byte ATT payload. Control traffic gets a small overflow lane above
    /// that cap instead of stealing capacity from bulk. This prevents an already queued image
    /// chunk from blocking handshake/ACK/game events without regressing legacy attachment support.
    static func queueBudget(packetLimit: Int, byteLimit: Int) -> BLEQueueBudget {
        let packetOverflow = min(1_024, max(96, packetLimit / 16))
        let byteOverflow = min(128 * 1_024, max(24 * 1_024, byteLimit / 10))
        return BLEQueueBudget(
            controlOverflowPackets: packetOverflow,
            controlOverflowBytes: byteOverflow
        )
    }

    static func canEnqueue(
        priority: BLESendPriority,
        pendingPackets: Int,
        pendingBytes: Int,
        additionalPackets: Int,
        additionalBytes: Int,
        packetLimit: Int,
        byteLimit: Int
    ) -> Bool {
        guard additionalPackets >= 0, additionalBytes >= 0,
              pendingPackets >= 0, pendingBytes >= 0 else { return false }
        let budget = queueBudget(packetLimit: packetLimit, byteLimit: byteLimit)
        let effectivePacketLimit = priority == .control
            ? packetLimit + budget.controlOverflowPackets
            : packetLimit
        let effectiveByteLimit = priority == .control
            ? byteLimit + budget.controlOverflowBytes
            : byteLimit
        return pendingPackets + additionalPackets <= effectivePacketLimit
            && pendingBytes + additionalBytes <= effectiveByteLimit
    }

    static func stallTimeout(quality: BLELinkQuality, hasControlTraffic: Bool) -> TimeInterval {
        if hasControlTraffic {
            switch quality {
            case .weak: return 9
            case .marginal: return 7
            case .strong, .good, .unknown: return 5
            }
        }
        switch quality {
        case .weak: return 16
        case .marginal: return 13
        case .strong, .good, .unknown: return 10
        }
    }

    static func reconnectDelay(attempt: Int) -> TimeInterval {
        switch max(1, attempt) {
        case 1: return 0.5
        case 2: return 1
        case 3: return 2
        case 4: return 4
        case 5: return 8
        case 6: return 15
        case 7: return 24
        default: return 30
        }
    }
}
