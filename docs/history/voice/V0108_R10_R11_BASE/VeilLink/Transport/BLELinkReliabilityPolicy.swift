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
    let interBurstDelay: TimeInterval
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
                packetBurstLimit: isSE1 ? 12 : (isIPhone7 ? 16 : 32),
                interBurstDelay: legacy ? 0.002 : 0
            )
        case .good:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: isSE1 ? 10 : (isIPhone7 ? 12 : 24),
                interBurstDelay: legacy ? 0.004 : 0.002
            )
        case .marginal:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: isSE1 ? 6 : (isIPhone7 ? 8 : 12),
                interBurstDelay: legacy ? 0.010 : 0.007
            )
        case .weak:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: 4,
                interBurstDelay: legacy ? 0.020 : 0.014
            )
        case .unknown:
            return BLELinkTuning(
                quality: quality,
                packetBurstLimit: isSE1 ? 8 : (isIPhone7 ? 10 : 16),
                interBurstDelay: legacy ? 0.006 : 0.003
            )
        }
    }

    static func reconnectDelay(attempt: Int) -> TimeInterval {
        switch max(1, attempt) {
        case 1: return 0.75
        case 2: return 1.5
        case 3: return 3
        case 4: return 6
        case 5: return 12
        case 6: return 20
        default: return 30
        }
    }
}
