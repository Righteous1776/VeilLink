#if os(iOS)
import ReplayKit
import Foundation
import CoreMedia

/// Broadcast Upload extension principal class on iOS 26. User initiates the OS picker.
/// No microphone capture, no photo library, no remote control, no video recording.
final class VeilScreenBroadcastUploadHandler: RPBroadcastSampleHandler {
    private var session: VeilScreenBroadcastSessionConfig?
    private var mailbox: VeilScreenEncryptedMailbox?
    private var encoder = VeilScreenReplayKitEncoder()
    private var pacer = VeilScreenCapturePacer()
    private var nextFrameID: UInt64 = 1

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSCoding]?) {
        guard let config = VeilScreenBroadcastSecurityConfig.load() else {
            finishBroadcastWithError(VeilScreenBroadcastError.missingEntitlements)
            return
        }
        let bridge = VeilScreenEncryptedMailbox(config: config)
        guard let current = bridge.currentSession() else {
            finishBroadcastWithError(VeilScreenBroadcastError.missingKey)
            return
        }
        session = current
        mailbox = bridge
        pacer.reset()
    }

    override func broadcastPaused() { pacer.reset() }
    override func broadcastResumed() { pacer.reset() }

    override func broadcastFinished() {
        if let current = session { mailbox?.deactivate(sessionID: current.sessionID) }
        mailbox = nil
        session = nil
        pacer.reset()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        // Audio is intentionally discarded. Only video frames leave this callback.
        guard sampleBufferType == .video, let session else { return }
        guard session.valid(at: Date()) else {
            finishBroadcastWithError(VeilScreenBroadcastError.malformedFrame)
            return
        }
        guard pacer.shouldEncode(at: ProcessInfo.processInfo.systemUptime,
                                 minimumInterval: session.frameIntervalSeconds),
              let (jpeg, width, height) = encoder.compress(sampleBuffer,
                                      width: session.targetWidth,
                                      byteBudget: session.byteBudget) else { return }
        let image = VeilScreenMailboxFrame(sessionID: session.sessionID, frameID: nextFrameID,
                      createdAt: Date(), width: width, height: height, jpeg: jpeg)
        nextFrameID &+= 1
        do { try mailbox?.publish(image, for: session) }
        catch {
            // Fail closed: no plaintext fallback. No pixel content in error logs.
            finishBroadcastWithError(error)
        }
    }
}
#endif
