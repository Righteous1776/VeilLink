import Foundation

/// UI and control-plane truth source. Every transition is based on authenticated
/// local/peer/capture events; a UI tap alone NEVER claims that capture succeeded.
enum VeilScreenRole: Equatable { case sender, viewer }
enum VeilScreenPhase: Equatable {
    case inviting, incomingInvite, awaitingSystemConsent, awaitingSender,
         connecting, live, stalled, ended, failed
}
enum VeilScreenEndReason: Equatable {
    case declined, canceled, expired, disconnected, revoked, peerStopped, error
}

enum VeilScreenEvent: Equatable {
    case peerAccepted
    case senderReady
    case viewerReady
    case peerDeclined
    case localAccepted
    case localDeclined
    case systemPickerOpened
    case captureStarted
    case firstFrame(id: UInt64)
    case frame(id: UInt64)
    case becameStale
    case timeout
    case linkLost
    case captureRevoked
    case localStop
    case peerStopped
    case failed
}

struct VeilScreenSnapshot: Equatable {
    let sessionID: UUID
    let peerIdentityID: String
    let role: VeilScreenRole
    private(set) var phase: VeilScreenPhase
    private(set) var lastFrameID: UInt64?
    private(set) var lastFrameTime: TimeInterval?
    private(set) var endReason: VeilScreenEndReason?
    private(set) var generation: UInt64 = 0
    private(set) var captureActive = false
    let createdAt: TimeInterval
    let expiresAt: TimeInterval

    static func outgoing(peerID: String, at now: TimeInterval, id: UUID = UUID()) -> Self {
        .init(sessionID: id, peerIdentityID: peerID, role: .sender,
              phase: .inviting, createdAt: now, expiresAt: now + 60)
    }

    static func incoming(peerID: String, at now: TimeInterval, id: UUID) -> Self {
        .init(sessionID: id, peerIdentityID: peerID, role: .viewer,
              phase: .incomingInvite, createdAt: now, expiresAt: now + 60)
    }

    var isTerminal: Bool { phase == .ended || phase == .failed }
    var canAccept: Bool { role == .viewer && phase == .incomingInvite }
    var canRequestSystemCapture: Bool { role == .sender && phase == .awaitingSystemConsent }
    var isActivelySending: Bool { role == .sender && (phase == .live || phase == .stalled) }
    var isActivelyReceiving: Bool { role == .viewer && (phase == .live || phase == .stalled) }
    var hasStartedCapture: Bool { role == .sender && captureActive }

    /// Requires the wire adapter to verify E2EE peer identity, session UUID,
    /// negotiated feature bit and local role BEFORE calling transition.
    @discardableResult
    mutating func transition(_ event: VeilScreenEvent, at now: TimeInterval) -> Bool {
        guard !isTerminal else { return false }
        if now >= expiresAt && (phase == .inviting || phase == .incomingInvite) {
            terminate(.expired)
            return event == .timeout
        }
        switch event {
        case .peerAccepted where role == .sender && phase == .inviting:
            phase = .awaitingSystemConsent
        case .peerDeclined where role == .sender && phase == .inviting:
            terminate(.declined)
        case .localAccepted where canAccept:
            phase = .awaitingSender
        case .localDeclined where canAccept:
            terminate(.declined)
        case .senderReady where role == .viewer && phase == .awaitingSender:
            phase = .connecting
        case .systemPickerOpened where canRequestSystemCapture:
            phase = .connecting
        case .captureStarted where role == .sender && phase == .connecting:
            guard !captureActive else { return false }
            captureActive = true
        case .viewerReady where role == .sender && phase == .connecting && captureActive:
            phase = .live
        case .firstFrame(let id) where role == .viewer && phase == .connecting:
            lastFrameID = id; lastFrameTime = now; phase = .live
        case .frame(let id) where role == .viewer && (phase == .live || phase == .stalled):
            guard lastFrameID.map({ id > $0 }) ?? true else { return false }
            lastFrameID = id; lastFrameTime = now; phase = .live
        case .becameStale where role == .viewer && phase == .live:
            guard let last = lastFrameTime, now - last >= 8 else { return false }
            phase = .stalled
        case .timeout where phase == .incomingInvite || phase == .inviting:
            guard now >= expiresAt else { return false }
            terminate(.expired)
        case .linkLost:
            terminate(.disconnected)
        case .captureRevoked where role == .sender:
            terminate(.revoked)
        case .localStop:
            terminate(.canceled)
        case .peerStopped:
            terminate(.peerStopped)
        case .failed:
            terminate(.error)
        default:
            return false
        }
        return true
    }

    private mutating func terminate(_ reason: VeilScreenEndReason) {
        phase = reason == .error ? .failed : .ended
        endReason = reason
        captureActive = false
        lastFrameID = nil
        lastFrameTime = nil
        generation &+= 1  // rejects old in-flight capture/send callbacks
    }
}

/// Authenticated session registry. One active share per conversation, no history/SQLite.
struct VeilScreenSessionRegistry {
    private(set) var active: VeilScreenSnapshot?

    @discardableResult
    mutating func install(_ candidate: VeilScreenSnapshot, trustedPeerID: String, now: TimeInterval) -> Bool {
        guard !candidate.peerIdentityID.isEmpty,
              candidate.peerIdentityID == trustedPeerID,
              !candidate.isTerminal,
              candidate.expiresAt > now,
              active == nil || active?.isTerminal == true else { return false }
        active = candidate
        return true
    }

    @discardableResult
    mutating func apply(_ event: VeilScreenEvent, sessionID: UUID, peerID: String, at now: TimeInterval) -> Bool {
        guard var current = active, current.sessionID == sessionID,
              current.peerIdentityID == peerID else { return false }
        let result = current.transition(event, at: now)
        if result { active = current }
        return result
    }

    mutating func clearEnded() {
        if active?.isTerminal == true { active = nil }
    }
}
