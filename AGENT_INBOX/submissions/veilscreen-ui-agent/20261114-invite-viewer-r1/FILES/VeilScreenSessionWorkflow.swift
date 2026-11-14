import Foundation

/// Adapter supplied by the real AppModel/SessionCoordinator at integration time.
/// isSecureBLE MUST verify the current authenticated E2EE identity and BLE route.
/// sendControl MUST encrypt with fresh AEAD sequence and a screen-control domain.
struct VeilScreenSessionHooks {
    let isSecureBLE: (String) -> Bool
    let sendControl: (VeilScreenShareControl, String) -> Bool
    let requestSystemPicker: (UUID) -> Void
    let stopCapture: () -> Void
}

/// Entirely ephemeral: no timers, disk, chat messages, or private capture APIs.
/// Call tick() on app lifecycle/timer, receiveControl() only AFTER decrypt+auth.
struct VeilScreenSessionWorkflow {
    private(set) var registry = VeilScreenSessionRegistry()
    private(set) var latestImage: VeilScreenShareFrame?
    private var lastControlSendAt: TimeInterval = -.infinity
    private var captureStartedAt: TimeInterval?
    private let hooks: VeilScreenSessionHooks

    init(hooks: VeilScreenSessionHooks) { self.hooks = hooks }

    @discardableResult
    mutating func invite(peerID: String, now: TimeInterval) -> Bool {
        guard hooks.isSecureBLE(peerID) else { return false }
        let candidate = VeilScreenSnapshot.outgoing(peerID: peerID, at: now)
        guard registry.install(candidate, trustedPeerID: peerID, now: now) else { return false }
        guard send(.invite, sessionID: candidate.sessionID, peerID: peerID) else {
            registry = VeilScreenSessionRegistry()
            return false
        }
        lastControlSendAt = now
        return true
    }

    @discardableResult
    mutating func receiveControl(_ packet: VeilScreenShareControl, from peerID: String, now: TimeInterval) -> Bool {
        guard hooks.isSecureBLE(peerID) else { return false }
        if packet.action == .invite {
            if let current = registry.active, !current.isTerminal,
               current.sessionID == packet.sessionID, current.peerIdentityID == peerID,
               current.role == .viewer {
                // Lost ACCEPT: reply idempotently instead of opening a duplicate card.
                if current.phase == .awaitingSender || current.phase == .connecting || current.phase == .live {
                    return send(.accept, sessionID: packet.sessionID, peerID: peerID)
                }
                return true
            }
            return registry.install(.incoming(peerID: peerID, at: now, id: packet.sessionID),
                                    trustedPeerID: peerID, now: now)
        }
        guard let current = registry.active,
              current.sessionID == packet.sessionID,
              current.peerIdentityID == peerID, !current.isTerminal else { return false }
        switch packet.action {
        case .accept:
            return registry.apply(.peerAccepted, sessionID: packet.sessionID, peerID: peerID, at: now)
        case .decline:
            return registry.apply(.peerDeclined, sessionID: packet.sessionID, peerID: peerID, at: now)
        case .ready:
            guard current.role == .viewer,
                  (current.phase == .awaitingSender || current.phase == .connecting || current.phase == .live || current.phase == .stalled) else { return false }
            if current.phase == .awaitingSender {
                guard registry.apply(.senderReady, sessionID: packet.sessionID, peerID: peerID, at: now) else { return false }
            }
            return send(.readyAck, sessionID: packet.sessionID, peerID: peerID)
        case .readyAck:
            return registry.apply(.viewerReady, sessionID: packet.sessionID, peerID: peerID, at: now)
        case .stop:
            close(.peerStopped, now: now, notifyPeer: false)
            return true
        case .invite: return false
        }
    }

    @discardableResult
    mutating func accept(now: TimeInterval) -> Bool {
        guard let current = registry.active, current.canAccept,
              hooks.isSecureBLE(current.peerIdentityID), now < current.expiresAt,
              send(.accept, sessionID: current.sessionID, peerID: current.peerIdentityID) else { return false }
        return registry.apply(.localAccepted, sessionID: current.sessionID,
                              peerID: current.peerIdentityID, at: now)
    }

    @discardableResult
    mutating func decline(now: TimeInterval) -> Bool {
        guard let current = registry.active, current.canAccept else { return false }
        if hooks.isSecureBLE(current.peerIdentityID) {
            _ = send(.decline, sessionID: current.sessionID, peerID: current.peerIdentityID)
        }
        return registry.apply(.localDeclined, sessionID: current.sessionID,
                              peerID: current.peerIdentityID, at: now)
    }

    @discardableResult
    mutating func requestSystemCapture(now: TimeInterval) -> Bool {
        guard let current = registry.active, current.canRequestSystemCapture,
              registry.apply(.systemPickerOpened, sessionID: current.sessionID,
                             peerID: current.peerIdentityID, at: now) else { return false }
        hooks.requestSystemPicker(current.sessionID)
        return true
    }

    /// Invoke ONLY after OS capture has actually started; not on picker appearance.
    @discardableResult
    mutating func captureDidStart(sessionID: UUID, now: TimeInterval) -> Bool {
        guard let current = registry.active, current.role == .sender,
              current.sessionID == sessionID,
              registry.apply(.captureStarted, sessionID: sessionID,
                             peerID: current.peerIdentityID, at: now) else { return false }
        captureStartedAt = now
        if !send(.ready, sessionID: sessionID, peerID: current.peerIdentityID) {
            close(.failed, now: now, notifyPeer: false)
            return false
        }
        lastControlSendAt = now
        return true
    }

    /// Call after an authenticated/decrypted frame is fully assembled and validated.
    @discardableResult
    mutating func receiveFrame(_ frame: VeilScreenShareFrame, from peerID: String,
                               sessionID: UUID, now: TimeInterval) -> Bool {
        guard let current = registry.active, current.role == .viewer,
              current.peerIdentityID == peerID, current.sessionID == sessionID,
              hooks.isSecureBLE(peerID), !frame.image.isEmpty,
              frame.image.count <= VeilScreenShareChunk.maximumFrameBytes,
              (64...2048).contains(frame.width), (64...2048).contains(frame.height),
              frame.image.count >= 4,
              frame.image.prefix(2).elementsEqual([0xFF, 0xD8]),
              frame.image.suffix(2).elementsEqual([0xFF, 0xD9]) else { return false }
        let event: VeilScreenEvent = current.phase == .connecting
            ? .firstFrame(id: frame.frameID) : .frame(id: frame.frameID)
        guard registry.apply(event, sessionID: sessionID, peerID: peerID, at: now) else { return false }
        latestImage = frame
        return true
    }

    /// Control-plane retries are lightweight; never retry video as chat.
    mutating func tick(now: TimeInterval) {
        guard let current = registry.active, !current.isTerminal else { return }
        if !hooks.isSecureBLE(current.peerIdentityID) {
            close(.linkLost, now: now, notifyPeer: false)
            return
        }
        if current.phase == .inviting || current.phase == .incomingInvite {
            if now >= current.expiresAt {
                _ = registry.apply(.timeout, sessionID: current.sessionID,
                                   peerID: current.peerIdentityID, at: now)
                return
            }
            if current.phase == .inviting && now - lastControlSendAt >= 3 {
                _ = send(.invite, sessionID: current.sessionID, peerID: current.peerIdentityID)
                lastControlSendAt = now
            }
        }
        if current.role == .sender && current.phase == .connecting,
           current.captureActive, let started = captureStartedAt {
            if now - started >= 15 { close(.failed, now: now, notifyPeer: true); return }
            if now - lastControlSendAt >= 2 {
                _ = send(.ready, sessionID: current.sessionID, peerID: current.peerIdentityID)
                lastControlSendAt = now
            }
        }
        if current.role == .viewer && current.phase == .live,
           let last = current.lastFrameTime, now - last >= 8 {
            _ = registry.apply(.becameStale, sessionID: current.sessionID,
                               peerID: current.peerIdentityID, at: now)
        }
        if current.role == .viewer && (current.phase == .awaitingSender || current.phase == .connecting),
           now - current.createdAt > 75 {
            close(.failed, now: now, notifyPeer: true)
        }
    }

    mutating func close(_ event: VeilScreenEvent = .localStop, now: TimeInterval,
                        notifyPeer: Bool = true) {
        guard let current = registry.active, !current.isTerminal else { return }
        if notifyPeer && hooks.isSecureBLE(current.peerIdentityID) {
            _ = send(.stop, sessionID: current.sessionID, peerID: current.peerIdentityID)
        }
        if current.role == .sender && current.captureActive { hooks.stopCapture() }
        _ = registry.apply(event, sessionID: current.sessionID,
                           peerID: current.peerIdentityID, at: now)
        latestImage = nil
        captureStartedAt = nil
    }

    private func send(_ action: VeilScreenShareAction, sessionID: UUID, peerID: String) -> Bool {
        guard hooks.isSecureBLE(peerID) else { return false }
        return hooks.sendControl(.init(sessionID: sessionID, action: action), peerID)
    }
}
