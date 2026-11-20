#if os(iOS)
import Foundation
import CryptoKit

/// ReplayKit extension -> host-app IPC via ONE encrypted, replaceable App Group file.
/// The key never appears in UserDefaults/files; it is in the shared Keychain group.
/// This is temporary encrypted ON-DISK IPC, not a promise of zero disk writes.
struct VeilScreenEncryptedMailbox {
    let config: VeilScreenBroadcastSecurityConfig
    private let sessionKey = "veilscreen.active.session.v2"
    private let frameName = "veilscreen.current-frame.v2"
    private let maximumPlaintextBytes = 40 * 1024
    private let maximumCiphertextBytes = 44 * 1024

    private var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: config.appGroupID)
    }
    private var frameURL: URL? { directory?.appendingPathComponent(frameName, isDirectory: false) }

    func activate(_ session: VeilScreenBroadcastSessionConfig) throws {
        guard session.valid(at: Date()) else { throw VeilScreenBroadcastError.malformedFrame }
        guard let defaults = UserDefaults(suiteName: config.appGroupID), directory != nil else {
            throw VeilScreenBroadcastError.appGroupUnavailable
        }
        // Revoke any previous local session before replacing a running broadcast.
        if let old = defaults.data(forKey: sessionKey),
           let stale = try? JSONDecoder().decode(VeilScreenBroadcastSessionConfig.self, from: old),
           stale.sessionID != session.sessionID {
            VeilScreenSharedKeyStore(config: config).remove(sessionID: stale.sessionID)
        }
        try VeilScreenSharedKeyStore(config: config).setNewKey(sessionID: session.sessionID)
        if let frameURL { try? FileManager.default.removeItem(at: frameURL) }
        defaults.set(try JSONEncoder().encode(session), forKey: sessionKey)
    }

    func currentSession() -> VeilScreenBroadcastSessionConfig? {
        guard let defaults = UserDefaults(suiteName: config.appGroupID),
              let raw = defaults.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(VeilScreenBroadcastSessionConfig.self, from: raw),
              session.valid(at: Date()),
              VeilScreenSharedKeyStore(config: config).fetch(sessionID: session.sessionID) != nil else { return nil }
        return session
    }

    func publish(_ frame: VeilScreenMailboxFrame, for session: VeilScreenBroadcastSessionConfig) throws {
        guard session.valid(at: Date()), frame.sessionID == session.sessionID,
              frame.jpeg.count >= 4, frame.jpeg.count <= min(maximumPlaintextBytes, session.byteBudget),
              frame.jpeg.starts(with: [0xFF, 0xD8]), frame.jpeg.suffix(2).elementsEqual([0xFF, 0xD9]),
              (64...2048).contains(frame.width), (64...2048).contains(frame.height) else {
            throw VeilScreenBroadcastError.malformedFrame
        }
        guard let url = frameURL else { throw VeilScreenBroadcastError.appGroupUnavailable }
        guard let key = VeilScreenSharedKeyStore(config: config).fetch(sessionID: session.sessionID) else {
            throw VeilScreenBroadcastError.missingKey
        }
        let plain = try JSONEncoder().encode(frame)
        guard plain.count <= maximumPlaintextBytes else { throw VeilScreenBroadcastError.frameTooLarge }
        let sealed = try AES.GCM.seal(plain, using: key, authenticating: Data(session.sessionID.uuidString.utf8))
        guard let combined = sealed.combined, combined.count <= maximumCiphertextBytes else {
            throw VeilScreenBroadcastError.frameTooLarge
        }
        try combined.write(to: url, options: [.atomic])
        // Allow the capture extension to continue when foreground app is not active.
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }

    /// Caller must validate session ID, trusted E2EE peer and monotonically increasing frame ID.
    /// Destructively reads the ONE most recent frame. No full video history exists.
    func takeLatest(expectedSession: UUID) -> VeilScreenMailboxFrame? {
        guard let url = frameURL else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let raw = try? Data(contentsOf: url), raw.count <= maximumCiphertextBytes,
              let key = VeilScreenSharedKeyStore(config: config).fetch(sessionID: expectedSession),
              let sealed = try? AES.GCM.SealedBox(combined: raw),
              let opened = try? AES.GCM.open(sealed, using: key, authenticating: Data(expectedSession.uuidString.utf8)),
              let frame = try? JSONDecoder().decode(VeilScreenMailboxFrame.self, from: opened),
              frame.sessionID == expectedSession, frame.jpeg.count <= 32768,
              frame.jpeg.starts(with: [0xFF, 0xD8]), frame.jpeg.suffix(2).elementsEqual([0xFF, 0xD9]),
              (64...2048).contains(frame.width), (64...2048).contains(frame.height),
              abs(frame.createdAt.timeIntervalSinceNow) <= 8 else { return nil }
        return frame
    }

    func deactivate(sessionID: UUID) {
        // Do not delete keys of a different concurrent session.
        // Decode even if expired, otherwise stale frame files survive an expired session.
        if let defaults = UserDefaults(suiteName: config.appGroupID),
           let raw = defaults.data(forKey: sessionKey),
           let existing = try? JSONDecoder().decode(VeilScreenBroadcastSessionConfig.self, from: raw),
           existing.sessionID == sessionID {
            defaults.removeObject(forKey: sessionKey)
            if let url = frameURL { try? FileManager.default.removeItem(at: url) }
        }
        VeilScreenSharedKeyStore(config: config).remove(sessionID: sessionID)
    }
}

struct VeilScreenMailboxFrame: Codable {
    let sessionID: UUID
    let frameID: UInt64
    let createdAt: Date
    let width: Int
    let height: Int
    let jpeg: Data
}
#endif
