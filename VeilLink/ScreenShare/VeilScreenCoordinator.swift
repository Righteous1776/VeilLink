import Foundation
import Combine

/// App-scoped, single-session screen-share adapter. Control and media are
/// never represented as chat messages or persisted to SQLite / user backups.
@MainActor
final class VeilScreenCoordinator: ObservableObject {
    @Published private(set) var snapshot: VeilScreenSnapshot?
    @Published private(set) var receivedFrame: VeilScreenReceivedFrame?
    @Published private(set) var now = Date().timeIntervalSince1970
    @Published var showsConsent = false
    @Published var showsViewer = false

    private let sessions: SessionCoordinator
    private let bluetooth: BLETransport
    private var timer: Timer?
    private var pump: VeilScreenLegacyMailboxPump?
    private var assembler: VeilScreenShareAssembler?

    private lazy var workflow = VeilScreenSessionWorkflow(
        hooks: VeilScreenSessionHooks(
            isSecureBLE: { [weak self] peer in
                self?.sessions.hasSecureScreenBLE(for: peer) == true
            },
            sendControl: { [weak self] control, peer in
                self?.sessions.sendScreenControl(control, to: peer) == .accepted
            },
            requestSystemPicker: { [weak self] _ in
                self?.showsConsent = true
            },
            stopCapture: { [weak self] in
                self?.stopPump()
            }
        )
    )

    init(sessions: SessionCoordinator, bluetooth: BLETransport) {
        self.sessions = sessions
        self.bluetooth = bluetooth
        sessions.onScreenControl = { [weak self] peer, packet in
            self?.received(packet, from: peer)
        }
        sessions.onScreenMediaChunk = { [weak self] peer, chunk in
            self?.received(chunk, from: peer)
        }
        sessions.onScreenLinkLost = { [weak self] _ in
            self?.tick()
        }
    }

    func canInvite(peerID: String) -> Bool {
        let current = workflow.registry.active
        return sessions.hasSecureScreenBLE(for: peerID)
            && (current == nil || current?.isTerminal == true)
    }

    @discardableResult
    func invite(peerID: String) -> Bool {
        guard canInvite(peerID: peerID) else { return false }
        workflow.registry.clearEnded()
        let ok = workflow.invite(peerID: peerID, now: Date().timeIntervalSince1970)
        publish()
        return ok
    }

    @discardableResult
    func accept() -> Bool {
        let accepted = workflow.accept(now: Date().timeIntervalSince1970)
        publish()
        return accepted
    }

    func decline() {
        _ = workflow.decline(now: Date().timeIntervalSince1970)
        publish()
    }

    func requestPicker() {
        guard let current = workflow.registry.active,
              current.role == .sender,
              sessions.hasSecureScreenBLE(for: current.peerIdentityID) else { return }
        guard workflow.requestSystemCapture(now: Date().timeIntervalSince1970) else { return }
        startPump(sessionID: current.sessionID, peer: current.peerIdentityID)
        publish()
    }

    func dismissConsent() { showsConsent = false }
    func openViewer() {
        guard let current = snapshot, current.role == .viewer,
              current.isActivelyReceiving else { return }
        showsViewer = true
    }
    func dismissViewer() { showsViewer = false }

    func stop() {
        workflow.close(.localStop, now: Date().timeIntervalSince1970)
        publish()
    }

    private func received(_ packet: VeilScreenShareControl, from peer: String) {
        let success = workflow.receiveControl(
            packet, from: peer, now: Date().timeIntervalSince1970
        )
        if success { publish() }
    }

    private func received(_ chunk: VeilScreenShareChunk, from peer: String) {
        guard let current = workflow.registry.active,
              current.role == .viewer, current.sessionID == chunk.sessionID,
              current.peerIdentityID == peer, !current.isTerminal,
              sessions.hasSecureScreenBLE(for: peer) else { return }
        if assembler == nil {
            assembler = VeilScreenShareAssembler(sessionID: current.sessionID)
        }
        guard let frame = try? assembler?.receive(
            chunk, at: ProcessInfo.processInfo.systemUptime
        ),
        workflow.receiveFrame(frame, from: peer,
            sessionID: chunk.sessionID, now: Date().timeIntervalSince1970) else { return }
        let received = Date().timeIntervalSince1970
        receivedFrame = VeilScreenReceivedFrame(
            sessionID: chunk.sessionID, frameID: frame.frameID,
            receivedAt: received, jpeg: frame.image
        )
        publish()
    }

    private func startPump(sessionID: UUID, peer: String) {
        stopPump()
        guard let config = VeilScreenBroadcastSecurityConfig.load() else { return }
        let mailbox = VeilScreenEncryptedMailbox(config: config)
        let worker = VeilScreenLegacyMailboxPump(
            mailbox: mailbox,
            isAuthenticatedBLE: { [weak self] in
                self?.sessions.hasSecureScreenBLE(for: peer) == true
            },
            canSendVideoNow: { [weak self] in
                let current = self?.workflow.registry.active
                return current?.sessionID == sessionID && current?.phase == .live
            },
            didObserveFirstCaptureFrame: { [weak self] captured in
                guard let self, captured == sessionID else { return }
                _ = self.workflow.captureDidStart(
                    sessionID: captured, now: Date().timeIntervalSince1970
                )
                self.publish()
            },
            queuedBLEBytes: { [weak self] in
                guard let self,
                      let transport = self.sessions.secureScreenBLETransportID(
                          for: peer
                      ) else { return Int.max }
                return self.bluetooth.pendingBytesForScreenShare(to: transport)
            },
            offerMediaToTransport: { [weak self] chunk in
                guard chunk.sessionID == sessionID else { return false }
                return self?.sessions.sendScreenMedia(chunk, to: peer) == .accepted
            }
        )
        pump = worker
        worker.start(sessionID: sessionID)
    }

    private func stopPump() {
        pump?.stop()
        pump = nil
    }

    private func tick() {
        now = Date().timeIntervalSince1970
        workflow.tick(now: now)
        publish()
    }

    private func publish() {
        let current = workflow.registry.active
        if current?.sessionID != snapshot?.sessionID {
            assembler = current?.role == .viewer
                ? current.map { VeilScreenShareAssembler(sessionID: $0.sessionID) }
                : nil
            receivedFrame = nil
        }
        snapshot = current
        if current == nil || current?.isTerminal == true {
            stopPump()
            assembler = nil
            receivedFrame = nil
            showsConsent = false
            showsViewer = false
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
                [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }
            }
        }
    }
}
