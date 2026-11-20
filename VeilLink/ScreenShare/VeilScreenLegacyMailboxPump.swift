#if os(iOS)
import Foundation

/// Host-side decoder and bridge into VeilScreen's existing BLE scheduler.
/// Requires an authenticated peer+session and an active transport before polling.
/// No UI button can assert that media is LIVE before the peer confirms a first frame.
@MainActor
final class VeilScreenLegacyMailboxPump {
    private let mailbox: VeilScreenEncryptedMailbox
    private var sessionID: UUID?
    private var latest = VeilScreenLatestFrameGate()
    private var timer: Timer?
    private var scheduler = VeilScreenBLEScheduler()
    private let isAuthenticatedBLE: () -> Bool
    private let canSendVideoNow: () -> Bool
    private let didObserveFirstCaptureFrame: (UUID) -> Void
    private var didSignalCapture = false
    private var readInFlight = false
    private var lifecycleGeneration: UInt64 = 0
    private let offerMediaToTransport: (VeilScreenShareChunk) -> Bool
    private let queuedBLEBytes: () -> Int

    init(mailbox: VeilScreenEncryptedMailbox,
         isAuthenticatedBLE: @escaping () -> Bool,
         canSendVideoNow: @escaping () -> Bool,
         didObserveFirstCaptureFrame: @escaping (UUID) -> Void,
         queuedBLEBytes: @escaping () -> Int,
         offerMediaToTransport: @escaping (VeilScreenShareChunk) -> Bool) {
        self.mailbox = mailbox
        self.isAuthenticatedBLE = isAuthenticatedBLE
        self.canSendVideoNow = canSendVideoNow
        self.didObserveFirstCaptureFrame = didObserveFirstCaptureFrame
        self.queuedBLEBytes = queuedBLEBytes
        self.offerMediaToTransport = offerMediaToTransport
    }

    func start(sessionID: UUID) {
        stop()
        self.sessionID = sessionID
        didSignalCapture = false
        lifecycleGeneration &+= 1
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let sessionID { mailbox.deactivate(sessionID: sessionID) }
        sessionID = nil
        scheduler.cancel()
        latest.reset()
        didSignalCapture = false
        readInFlight = false
        lifecycleGeneration &+= 1
    }

    private func poll() {
        guard let sessionID else { return }
        guard isAuthenticatedBLE() else { stop(); return }
        if !readInFlight {
            readInFlight = true
            let generation = lifecycleGeneration
            let box = mailbox
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let frame = box.takeLatest(expectedSession: sessionID)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.sessionID == sessionID,
                          self.lifecycleGeneration == generation else { return }
                    self.readInFlight = false
                    if let frame { self.admit(frame, sessionID: sessionID) }
                    self.drain()
                }
            }
        }
        drain()
    }

    private func admit(_ frame: VeilScreenMailboxFrame, sessionID: UUID) {
        guard latest.accept(frameID: frame.frameID,
                             writtenAt: frame.createdAt.timeIntervalSince1970,
                             now: Date().timeIntervalSince1970) else { return }
        // OS extension actually produced video; transition R1 to READY once.
        if !didSignalCapture {
            didSignalCapture = true
            didObserveFirstCaptureFrame(sessionID)
        }
        _ = scheduler.offer(image: frame.jpeg, sessionID: sessionID,
                            frameID: frame.frameID, width: frame.width,
                            height: frame.height, now: ProcessInfo.processInfo.systemUptime)
    }

    private func drain() {
        guard canSendVideoNow() else { return } // requires R1 READY-ACK
        // Low-priority, backlog-limited; never retry as a durable chat attachment.
        for _ in 0..<8 {
            guard let chunk = scheduler.peek(pendingBLEBytes: queuedBLEBytes(),
                         now: ProcessInfo.processInfo.systemUptime),
                  offerMediaToTransport(chunk) else { break }
            _ = scheduler.didAdmit(chunk)
        }
    }
}
#endif
