#if os(iOS)
import Combine
import Foundation

/// One authenticated, ephemeral screen-share session for the entire local app.
/// Never persists screen frames, message content or screen-control events.
@MainActor
final class VeilScreenBridgeController: ObservableObject {
    @Published private(set) var snapshot: VeilScreenSnapshot?
    @Published private(set) var receivedFrame: VeilScreenReceivedFrame?
    @Published private(set) var lastFailure: String?
    @Published var showsConsent = false
    @Published var showsViewer = false

    let broadcastHost = VeilScreenLegacyBroadcastHost()

    private let sessions: SessionCoordinator
    private let bluetooth: BLETransport
    private var workflow: VeilScreenSessionWorkflow?
    private var assembler: VeilScreenShareAssembler?
    private var assemblerID: UUID?
    private var pump: VeilScreenLegacyMailboxPump?
    private var tickTimer: Timer?

    init(sessions: SessionCoordinator, bluetooth: BLETransport) {
        self.sessions = sessions
        self.bluetooth = bluetooth
    }

    func configure() {
        guard workflow == nil else { return }
        workflow = VeilScreenSessionWorkflow(hooks: VeilScreenSessionHooks(
            isSecureBLE: { [weak sessions = self.sessions] peerID in
                sessions?.supportsAuthenticatedBLEScreenShare(peerID) == true
            },
            sendControl: { [weak sessions = self.sessions] packet, peerID in
                sessions?.sendScreenShareControl(packet, to: peerID) == .accepted
            },
            requestSystemPicker: { [weak self] sessionID in
                guard let self, self.snapshot?.sessionID == sessionID else { return }
                self.showsConsent = true
            },
            stopCapture: { [weak self] in self?.stopCaptureResources() }
        ))
    }

    var isAvailable: Bool {
        // An Info.plist string alone is NOT an App Group entitlement.
        // Fail closed on unsigned/incorrectly provisioned host installations.
        guard let config = VeilScreenBroadcastSecurityConfig.load() else { return false }
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: config.appGroupID
        ) != nil
    }

    func canInvite(peerID: String) -> Bool {
        sessions.supportsAuthenticatedBLEScreenShare(peerID)
            && isAvailable
            && (snapshot == nil || snapshot?.isTerminal == true)
    }

    @discardableResult
    func invite(peerID: String) -> Bool {
        guard canInvite(peerID: peerID), var current = workflow else {
            lastFailure = "屏幕共享需要双方安装新版、已建立可信蓝牙会话，并具备系统共享签名权限。"
            return false
        }
        current.clearFinishedSession()
        let accepted = current.invite(peerID: peerID, now: Date().timeIntervalSince1970)
        workflow = current
        if !accepted { lastFailure = "屏幕邀请尚未通过加密蓝牙通道。"; return false }
        lastFailure = nil
        receivedFrame = nil
        synchronize()
        return true
    }

    func receiveControl(_ packet: VeilScreenShareControl, peerID: String) {
        guard var current = workflow else { return }
        let accepted = current.receiveControl(packet, from: peerID,
                                               now: Date().timeIntervalSince1970)
        workflow = current
        if accepted {
            if packet.action == .invite {
                assembler = VeilScreenShareAssembler(sessionID: packet.sessionID)
                assemblerID = packet.sessionID
            }
            synchronize()
        }
    }

    func receiveChunk(_ chunk: VeilScreenShareChunk, peerID: String) {
        guard let state = snapshot, state.role == .viewer,
              state.peerIdentityID == peerID, state.sessionID == chunk.sessionID,
              state.phase == .connecting || state.phase == .live || state.phase == .stalled,
              sessions.supportsAuthenticatedBLEScreenShare(peerID) else { return }
        if assemblerID != state.sessionID {
            assembler = VeilScreenShareAssembler(sessionID: state.sessionID)
            assemblerID = state.sessionID
        }
        guard var currentAssembler = assembler else { return }
        do {
            let complete = try currentAssembler.receive(
                chunk, at: ProcessInfo.processInfo.systemUptime
            )
            assembler = currentAssembler
            guard let complete, var current = workflow else { return }
            let now = Date().timeIntervalSince1970
            guard current.receiveFrame(complete, from: peerID,
                                       sessionID: state.sessionID, now: now) else { return }
            workflow = current
            receivedFrame = VeilScreenReceivedFrame(
                sessionID: state.sessionID, frameID: complete.frameID,
                receivedAt: now, jpeg: complete.image
            )
            synchronize()
        } catch {
            // Invalid or replayed media is dropped. Never log image bytes.
        }
    }

    func accept() {
        guard var current = workflow else { return }
        _ = current.accept(now: Date().timeIntervalSince1970)
        workflow = current
        synchronize()
    }

    func decline() {
        guard var current = workflow else { return }
        _ = current.decline(now: Date().timeIntervalSince1970)
        workflow = current
        synchronize()
    }

    func requestCaptureConsent() {
        guard var current = workflow else { return }
        _ = current.requestSystemCapture(now: Date().timeIntervalSince1970)
        workflow = current
        synchronize()
    }

    /// Called only by the user's explicit "Prepare" button inside the OS consent sheet.
    func prepareCapture() {
        guard let state = snapshot, state.role == .sender,
              state.phase == .connecting,
              sessions.supportsAuthenticatedBLEScreenShare(state.peerIdentityID),
              let config = VeilScreenBroadcastSecurityConfig.load() else {
            lastFailure = "无法验证屏幕共享签名权限与可信蓝牙连接。"
            return
        }
        guard broadcastHost.prepare(sessionID: state.sessionID) else {
            lastFailure = broadcastHost.status
            stop()
            return
        }
        pump?.stop()
        pump = VeilScreenLegacyMailboxPump(
            mailbox: VeilScreenEncryptedMailbox(config: config),
            isAuthenticatedBLE: { [weak self] in
                guard let self, let state = self.snapshot else { return false }
                return self.sessions.supportsAuthenticatedBLEScreenShare(state.peerIdentityID)
            },
            canSendVideoNow: { [weak self] in
                guard let self, let state = self.snapshot else { return false }
                return state.role == .sender && state.phase == .live
                    && self.sessions.supportsAuthenticatedBLEScreenShare(state.peerIdentityID)
            },
            didObserveFirstCaptureFrame: { [weak self] id in
                self?.captureDidStart(id)
            },
            queuedBLEBytes: { [weak self] in
                guard let self, let state = self.snapshot,
                      let transport = self.sessions.transportID(
                        for: state.peerIdentityID, kind: .ble
                      ) else { return Int.max }
                return self.bluetooth.pendingOutboundBytes(for: transport)
            },
            offerMediaToTransport: { [weak self] chunk in
                guard let self, let state = self.snapshot,
                      state.role == .sender, state.sessionID == chunk.sessionID,
                      state.phase == .live else { return false }
                return self.sessions.sendScreenShareChunk(
                    chunk, to: state.peerIdentityID
                ) == .accepted
            }
        )
        pump?.start(sessionID: state.sessionID)
        lastFailure = nil
    }

    private func captureDidStart(_ sessionID: UUID) {
        guard var current = workflow else { return }
        _ = current.captureDidStart(
            sessionID: sessionID, now: Date().timeIntervalSince1970
        )
        workflow = current
        synchronize()
    }

    func stop() {
        guard var current = workflow else {
            stopCaptureResources()
            showsConsent = false
            showsViewer = false
            return
        }
        current.close(.localStop, now: Date().timeIntervalSince1970)
        workflow = current
        synchronize()
    }

    func linkChanged() {
        guard let state = snapshot, !state.isTerminal else { return }
        guard sessions.supportsAuthenticatedBLEScreenShare(state.peerIdentityID) else {
            guard var current = workflow else { return }
            current.close(.linkLost, now: Date().timeIntervalSince1970,
                          notifyPeer: false)
            workflow = current
            synchronize()
            return
        }
    }

    private func tick() {
        guard var current = workflow else { return }
        current.tick(now: Date().timeIntervalSince1970)
        workflow = current
        synchronize()
    }

    private func synchronize() {
        let current = workflow?.registry.active
        snapshot = current
        if current?.isTerminal == true || current == nil {
            stopCaptureResources()
            receivedFrame = nil
            assembler = nil
            assemblerID = nil
            showsConsent = false
            showsViewer = false
            tickTimer?.invalidate()
            tickTimer = nil
        } else if tickTimer == nil {
            tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
                [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }
            }
        }
    }

    private func stopCaptureResources() {
        pump?.stop()
        pump = nil
        broadcastHost.stop()
    }
}
#endif
