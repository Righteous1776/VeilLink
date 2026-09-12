import Foundation

struct LocalIdentity: Codable, Identifiable, Hashable {
    let id: String
    var displayName: String
    let publicKey: Data
    let createdAt: Date
    var isPrimary: Bool
}

struct NearbyPeer: Identifiable, Hashable {
    enum TrustState: String, Codable {
        case discovered
        case awaitingConfirmation
        case trusted
        case blocked
    }

    let id: String
    var transportID: UUID
    var displayName: String
    var rssi: Int
    var trustState: TrustState
    var pairingCode: String?
    var lastSeen: Date
}

struct ConversationSummary: Identifiable, Hashable {
    let id: String
    var title: String
    var peerIdentityID: String
    var lastMessage: String
    var updatedAt: Date
    var unreadCount: Int
    var isPinned: Bool
}

struct TrustedContact: Hashable {
    let identityID: String
    let displayName: String
    let publicKey: Data
}

struct ChatMessage: Identifiable, Hashable {
    enum DeliveryState: String, Codable {
        case queued
        case sending
        case paused
        case delivered
        case cancelled
        case failed
    }

    let id: String
    let conversationID: String
    let senderIdentityID: String
    let body: String
    let sentAt: Date
    var isOutgoing: Bool
    var deliveryState: DeliveryState
    var failureReason: String? = nil
    var transferProgress: Double? = nil
    var attachment: ChatAttachment? = nil
}

struct ChatAttachment: Identifiable, Hashable {
    let id: String
    let mimeType: String
    let byteCount: Int
}

enum TransportSendResult {
    case accepted
    case temporarilyUnavailable
    case unsupportedLink
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case chats = "对话"
    case nearby = "附近"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right"
        case .nearby: return "dot.radiowaves.left.and.right"
        case .settings: return "gearshape"
        }
    }
}

struct OwnerCapability: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let diagnostics = OwnerCapability(rawValue: 1 << 0)
    static let protocolTuning = OwnerCapability(rawValue: 1 << 1)
    static let groupModeration = OwnerCapability(rawValue: 1 << 2)
    static let visualEffects = OwnerCapability(rawValue: 1 << 3)

    static let safeDefault: OwnerCapability = [
        .diagnostics,
        .protocolTuning,
        .groupModeration,
        .visualEffects
    ]
}
