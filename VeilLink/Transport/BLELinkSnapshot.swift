import Foundation

enum BLEPeerLinkRole: String, Equatable {
    case central = "CENTRAL"
    case peripheral = "PERIPHERAL"
    case dual = "DUAL"
    case unavailable = "—"
}

struct BLEPeerLinkSnapshot: Identifiable, Equatable {
    let id: UUID
    let isConnected: Bool
    let isWanted: Bool
    let reconnectAttempt: Int
    let rssi: Int?
    let quality: BLELinkQuality
    let pendingPackets: Int
    let pendingBytes: Int
    let controlPendingPackets: Int
    let maximumPacketSize: Int?
    let role: BLEPeerLinkRole
    let stalledFor: TimeInterval?

    var isRecovering: Bool { isWanted && !isConnected }

    var qualityTitle: String {
        switch quality {
        case .strong: return "很强"
        case .good: return "良好"
        case .marginal: return "一般"
        case .weak: return "较弱"
        case .unknown: return "未知"
        }
    }

    var statusTitle: String {
        if isConnected { return "链路已就绪" }
        if isRecovering { return reconnectAttempt > 0 ? "自动重连中" : "等待恢复" }
        return "未连接"
    }

    /// A compact, explainable health score for UI only. It never changes transport behavior.
    var healthScore: Int {
        var score: Int
        switch quality {
        case .strong: score = 96
        case .good: score = 82
        case .marginal: score = 62
        case .weak: score = 38
        case .unknown: score = 55
        }
        if !isConnected { score -= isRecovering ? 24 : 42 }
        score -= min(18, reconnectAttempt * 3)
        if controlPendingPackets > 0 { score -= min(8, controlPendingPackets / 12) }
        if pendingBytes > 512 * 1_024 { score -= 10 }
        else if pendingBytes > 128 * 1_024 { score -= 5 }
        if let stalledFor, stalledFor >= 5 { score -= 10 }
        return max(0, min(100, score))
    }

    var queueSummary: String {
        guard pendingPackets > 0 else { return "队列空闲" }
        let bytes: String
        if pendingBytes >= 1_048_576 {
            bytes = String(format: "%.1f MB", Double(pendingBytes) / 1_048_576)
        } else if pendingBytes >= 1_024 {
            bytes = String(format: "%.0f KB", Double(pendingBytes) / 1_024)
        } else {
            bytes = "\(pendingBytes) B"
        }
        return controlPendingPackets > 0
            ? "\(pendingPackets) 包 · \(bytes) · 控制 \(controlPendingPackets)"
            : "\(pendingPackets) 包 · \(bytes)"
    }

    var compactDetail: String {
        var parts: [String] = []
        if let rssi { parts.append("\(rssi) dBm") }
        parts.append(qualityTitle)
        if let maximumPacketSize { parts.append("ATT \(maximumPacketSize) B") }
        if pendingPackets > 0 { parts.append(queueSummary) }
        return parts.joined(separator: " · ")
    }
}

enum BLELinkDiagnosticsFormatter {
    static func report(
        generatedAt: Date,
        isRunning: Bool,
        statusText: String,
        connectedPeerCount: Int,
        snapshots: [BLEPeerLinkSnapshot]
    ) -> String {
        let timestamp = ISO8601DateFormatter().string(from: generatedAt)
        var lines = [
            "VeilLink Transport Diagnostics",
            "Generated: \(timestamp)",
            "Running: \(isRunning ? "yes" : "no")",
            "Status: \(statusText)",
            "Connected peers: \(connectedPeerCount)",
            "Peer snapshots: \(snapshots.count)"
        ]
        for snapshot in snapshots.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let shortID = String(snapshot.id.uuidString.prefix(8))
            let rssi = snapshot.rssi.map(String.init) ?? "n/a"
            let mtu = snapshot.maximumPacketSize.map(String.init) ?? "n/a"
            let stalled = snapshot.stalledFor.map { String(format: "%.1fs", $0) } ?? "n/a"
            lines.append(
                "- \(shortID) state=\(snapshot.statusTitle) role=\(snapshot.role.rawValue) quality=\(snapshot.quality.rawValue) health=\(snapshot.healthScore) rssi=\(rssi) mtu=\(mtu) pendingPackets=\(snapshot.pendingPackets) pendingBytes=\(snapshot.pendingBytes) controlPending=\(snapshot.controlPendingPackets) reconnectAttempt=\(snapshot.reconnectAttempt) stalled=\(stalled)"
            )
        }
        lines.append("Privacy: no message body, attachment content, identity key, session key, or pairing code is included.")
        return lines.joined(separator: "\n")
    }
}
