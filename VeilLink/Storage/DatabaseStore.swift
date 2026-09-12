import CryptoKit
import Foundation
import SQLite3

enum DatabaseError: LocalizedError {
    case openFailed(String)
    case statementFailed(String)
    case backupFailed(String)
    case encryptionKeyMissing
    case encryptionKeyMismatch

    var errorDescription: String? {
        switch self {
        case .openFailed(let message), .statementFailed(let message), .backupFailed(let message):
            return message
        case .encryptionKeyMissing:
            return "本地数据库仍存在，但其加密密钥已从 Keychain 丢失。VeilLink 已停止打开数据，避免用新密钥覆盖原状态。"
        case .encryptionKeyMismatch:
            return "本地数据库加密密钥与现有数据不匹配。VeilLink 已停止继续读写，请使用有效备份恢复。"
        }
    }
}

final class DatabaseStore {
    let databaseURL: URL
    let attachmentsURL: URL

    private var db: OpaquePointer?
    private var storageKey: SymmetricKey
    private var storageKeyData: Data
    private let keychain: KeychainStore
    private let storageKeyName = "storage.database.key"
    private let queue = DispatchQueue(label: "studio.zeo.veillink.sqlite", qos: .userInitiated)
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    static let inboundAttachmentRetention: TimeInterval = 7 * 24 * 60 * 60
    static let maximumIncompleteInboundAttachments = 16
    static let maximumIncompleteInboundAttachmentsPerSender = 4
    static let localDeletionTombstoneRetention: TimeInterval = 8 * 24 * 60 * 60


    init(keychain: KeychainStore, rootDirectory: URL? = nil) throws {
        self.keychain = keychain
        let fileManager = FileManager.default
        let support: URL
        if let rootDirectory {
            support = rootDirectory
        } else {
            support = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("VeilLink", isDirectory: true)
        }
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        databaseURL = support.appendingPathComponent("veillink.sqlite")
        attachmentsURL = support.appendingPathComponent("Attachments", isDirectory: true)

        let databaseAlreadyExists = fileManager.fileExists(atPath: databaseURL.path)
        if let existing = keychain.data(for: storageKeyName) {
            guard existing.count == 32 else { throw DatabaseError.encryptionKeyMismatch }
            storageKeyData = existing
            storageKey = SymmetricKey(data: existing)
        } else {
            guard !databaseAlreadyExists else { throw DatabaseError.encryptionKeyMissing }
            let generated = PasswordKDF.randomData(count: 32)
            try keychain.set(generated, for: storageKeyName)
            storageKeyData = generated
            storageKey = SymmetricKey(data: generated)
        }
        try fileManager.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
            sqlite3_close(handle)
            throw DatabaseError.openFailed("数据库打开失败：\(message)")
        }
        db = handle
        try migrate()
        try verifyStorageKey()
        _ = try? cleanupCompletedInboundTransferMetadata()
        _ = try? cleanupStaleInboundAttachments()
        _ = try? cleanupExpiredLocalDeletionTombstones()
    }

    deinit {
        sqlite3_close(db)
    }

    func upsertProfile(_ profile: LocalIdentity) throws {
        try write(
            """
            INSERT INTO profiles(id, display_name, public_key, created_at, is_primary)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                display_name = excluded.display_name,
                is_primary = excluded.is_primary;
            """,
            bindings: [.text(profile.id), .text(profile.displayName), .blob(profile.publicKey),
                       .double(profile.createdAt.timeIntervalSince1970), .int(profile.isPrimary ? 1 : 0)]
        )
    }

    func trustPeer(localIdentityID: String, identityID: String, displayName: String, publicKey: Data) throws {
        try write(
            """
            INSERT INTO contacts(local_identity_id, identity_id, display_name, public_key, trust_state, created_at)
            VALUES(?, ?, ?, ?, 'trusted', ?)
            ON CONFLICT(local_identity_id, identity_id) DO UPDATE SET
                display_name = excluded.display_name,
                public_key = excluded.public_key,
                trust_state = 'trusted';
            """,
            bindings: [.text(localIdentityID), .text(identityID), .text(displayName), .blob(publicKey), .double(Date().timeIntervalSince1970)]
        )
    }

    func peerTrustState(localIdentityID: String, identityID: String) -> NearbyPeer.TrustState? {
        let states: [String] = read(
            "SELECT trust_state FROM contacts WHERE local_identity_id = ? AND identity_id = ? LIMIT 1;",
            bindings: [.text(localIdentityID), .text(identityID)],
            transform: { text($0, 0) }
        )
        guard let raw = states.first else { return nil }
        switch raw {
        case "trusted": return .trusted
        case "blocked": return .blocked
        default: return nil
        }
    }

    func setPeerTrust(localIdentityID: String, identityID: String, blocked: Bool) throws {
        try write(
            "UPDATE contacts SET trust_state = ? WHERE local_identity_id = ? AND identity_id = ?;",
            bindings: [.text(blocked ? "blocked" : "untrusted"), .text(localIdentityID), .text(identityID)]
        )
    }

    func renameContact(localIdentityID: String, identityID: String, displayName: String) throws {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.lengthOfBytes(using: .utf8) <= 64 else {
            throw DatabaseError.statementFailed("联系人备注不能为空且不能超过 64 个 UTF-8 字节。")
        }
        try writeBatch([
            (
                "UPDATE contacts SET display_name = ? WHERE local_identity_id = ? AND identity_id = ?;",
                [.text(normalized), .text(localIdentityID), .text(identityID)]
            ),
            (
                "UPDATE conversations SET title = ? WHERE local_identity_id = ? AND peer_identity_id = ?;",
                [.text(normalized), .text(localIdentityID), .text(identityID)]
            )
        ])
    }

    func deleteLocalIdentityData(localIdentityID: String) throws {
        let relativePaths = read(
            """
            SELECT a.relative_path
            FROM attachments a
            JOIN messages m ON m.id = a.message_id
            JOIN conversations c ON c.id = m.conversation_id
            WHERE c.local_identity_id = ?;
            """,
            bindings: [.text(localIdentityID)]
        ) { text($0, 0) }

        try writeBatch([
            ("DELETE FROM conversations WHERE local_identity_id = ?;", [.text(localIdentityID)]),
            ("DELETE FROM contacts WHERE local_identity_id = ?;", [.text(localIdentityID)]),
            ("DELETE FROM profiles WHERE id = ?;", [.text(localIdentityID)])
        ])

        for relativePath in relativePaths {
            let url = attachmentsURL.appendingPathComponent(relativePath)
            if url.standardizedFileURL.deletingLastPathComponent() == attachmentsURL.standardizedFileURL {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func createConversation(localIdentityID: String, peerIdentityID: String, title: String) throws -> String {
        if let existing = conversationID(localIdentityID: localIdentityID, for: peerIdentityID) { return existing }
        let id = UUID().uuidString
        try write(
            "INSERT INTO conversations(id, local_identity_id, peer_identity_id, title, updated_at) VALUES(?, ?, ?, ?, ?);",
            bindings: [.text(id), .text(localIdentityID), .text(peerIdentityID), .text(title), .double(Date().timeIntervalSince1970)]
        )
        return id
    }

    func trustedContact(localIdentityID: String, identityID: String) -> TrustedContact? {
        read(
            "SELECT identity_id, display_name, public_key FROM contacts WHERE local_identity_id = ? AND identity_id = ? AND trust_state = 'trusted' LIMIT 1;",
            bindings: [.text(localIdentityID), .text(identityID)]
        ) { statement in
            TrustedContact(
                identityID: text(statement, 0),
                displayName: text(statement, 1),
                publicKey: data(statement, 2)
            )
        }.first
    }

    func conversationID(localIdentityID: String, for peerIdentityID: String) -> String? {
        read(
            "SELECT id FROM conversations WHERE local_identity_id = ? AND peer_identity_id = ? ORDER BY updated_at DESC LIMIT 1;",
            bindings: [.text(localIdentityID), .text(peerIdentityID)]
        ) { text($0, 0) }.first
    }

    func saveMessage(_ message: ChatMessage, conversationPreview: String? = nil) throws {
        guard !messageExists(id: message.id) else { return }
        let protectedBody = try ChaChaPoly.seal(Data(message.body.utf8), using: storageKey).combined
        let protectedPreview = try ChaChaPoly.seal(Data((conversationPreview ?? message.body).utf8), using: storageKey).combined
        try writeBatch([
            (
                """
                INSERT INTO messages(
                    id, conversation_id, sender_identity_id, body_ciphertext,
                    sent_at, is_outgoing, delivery_state, transfer_progress
                ) VALUES(?, ?, ?, ?, ?, ?, ?, ?);
                """,
                [
                    .text(message.id), .text(message.conversationID), .text(message.senderIdentityID),
                    .blob(protectedBody), .double(message.sentAt.timeIntervalSince1970),
                    .int(message.isOutgoing ? 1 : 0), .text(message.deliveryState.rawValue),
                    message.transferProgress.map(SQLiteValue.double) ?? .null
                ]
            ),
            (
                "UPDATE conversations SET updated_at = ?, last_message_preview = ?, unread_count = unread_count + ? WHERE id = ?;",
                [
                    .double(message.sentAt.timeIntervalSince1970), .blob(protectedPreview),
                    .int(message.isOutgoing ? 0 : 1), .text(message.conversationID)
                ]
            )
        ])
    }

    func saveAttachment(messageID: String, data: Data, mimeType: String) throws -> ChatAttachment {
        let id = UUID().uuidString
        let relativePath = "\(id).bin"
        let destination = attachmentsURL.appendingPathComponent(relativePath)
        let protected = try ChaChaPoly.seal(data, using: storageKey).combined
        try protected.write(to: destination, options: [.atomic, .completeFileProtection])
        let hash = Data(SHA256.hash(data: data))
        do {
            try write(
                "INSERT INTO attachments(id, message_id, relative_path, mime_type, byte_count, sha256) VALUES(?, ?, ?, ?, ?, ?);",
                bindings: [.text(id), .text(messageID), .text(relativePath), .text(mimeType), .int(data.count), .blob(hash)]
            )
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return ChatAttachment(id: id, mimeType: mimeType, byteCount: data.count)
    }

    func loadAttachment(id: String) -> Data? {
        let paths: [String] = read(
            "SELECT relative_path FROM attachments WHERE id = ? LIMIT 1;",
            bindings: [.text(id)],
            transform: { text($0, 0) }
        )
        guard let relativePath = paths.first else { return nil }
        let url = attachmentsURL.appendingPathComponent(relativePath)
        guard url.standardizedFileURL.deletingLastPathComponent() == attachmentsURL.standardizedFileURL,
              let protected = try? Data(contentsOf: url),
              let box = try? ChaChaPoly.SealedBox(combined: protected),
              let opened = try? ChaChaPoly.open(box, using: storageKey) else { return nil }
        return opened
    }

    func attachmentSHA256(id: String) -> Data? {
        read("SELECT sha256 FROM attachments WHERE id = ? LIMIT 1;", bindings: [.text(id)]) { data($0, 0) }.first
    }

    func updateTransferProgress(messageID: String, progress: Double?) throws {
        let value = progress.map { min(max($0, 0), 1) }
        try write(
            "UPDATE messages SET transfer_progress = ? WHERE id = ?;",
            bindings: [value.map(SQLiteValue.double) ?? .null, .text(messageID)]
        )
    }

    func updateDelivery(messageID: String, state: ChatMessage.DeliveryState, error: String? = nil) throws {
        try write(
            "UPDATE messages SET delivery_state = ?, delivery_error = ? WHERE id = ?;",
            bindings: [.text(state.rawValue), error.map(SQLiteValue.text) ?? .null, .text(messageID)]
        )
    }

    func messageExists(id: String) -> Bool {
        !read("SELECT 1 FROM messages WHERE id = ? LIMIT 1;", bindings: [.text(id)]) { _ in true }.isEmpty
    }

    func markDelivered(messageID: String, from peerIdentityID: String, localIdentityID: String) throws {
        try write("""
            UPDATE messages SET delivery_state = ?, delivery_error = NULL
            WHERE id = ? AND is_outgoing = 1
              AND conversation_id IN (SELECT id FROM conversations WHERE local_identity_id = ? AND peer_identity_id = ?);
            """, bindings: [.text(ChatMessage.DeliveryState.delivered.rawValue), .text(messageID), .text(localIdentityID), .text(peerIdentityID)])
    }

    func fetchMessage(id: String) -> ChatMessage? {
        read("""
            SELECT m.id, m.conversation_id, m.sender_identity_id, m.body_ciphertext,
                   m.sent_at, m.is_outgoing, m.delivery_state, m.delivery_error, m.transfer_progress, a.id, a.mime_type, a.byte_count
            FROM messages m LEFT JOIN attachments a ON a.message_id = m.id
            WHERE m.id = ? LIMIT 1;
            """, bindings: [.text(id)]) { decodedMessage($0) }.first
    }

    func enqueueOutbound(messageID: String, targetIdentityID: String, localIdentityID: String) throws {
        let now = Date().timeIntervalSince1970
        try write("""
            INSERT INTO outbound_queue(message_id, local_identity_id, target_identity_id, created_at, next_attempt_at, retry_count, expires_at, is_paused)
            VALUES(?, ?, ?, ?, ?, 0, ?, 0)
            ON CONFLICT(message_id) DO UPDATE SET
                local_identity_id = excluded.local_identity_id,
                target_identity_id = excluded.target_identity_id,
                next_attempt_at = MIN(outbound_queue.next_attempt_at, excluded.next_attempt_at),
                is_paused = 0;
            """, bindings: [.text(messageID), .text(localIdentityID), .text(targetIdentityID), .double(now), .double(now), .double(now + 7 * 24 * 60 * 60)])
    }

    struct OutboundQueueItem: Equatable {
        let messageID: String
        let retryCount: Int
    }

    func dueOutboundItems(for targetIdentityID: String, localIdentityID: String, limit: Int = 8) -> [OutboundQueueItem] {
        let now = Date().timeIntervalSince1970; let safeLimit = max(1, min(limit, 32))
        return read("""
            SELECT message_id, retry_count FROM outbound_queue
            WHERE local_identity_id = ? AND target_identity_id = ? AND is_paused = 0 AND next_attempt_at <= ? AND expires_at > ?
            ORDER BY created_at ASC LIMIT \(safeLimit);
            """, bindings: [.text(localIdentityID), .text(targetIdentityID), .double(now), .double(now)]) {
                OutboundQueueItem(messageID: text($0, 0), retryCount: Int(sqlite3_column_int64($0, 1)))
            }
    }

    func dueOutboundMessageIDs(for targetIdentityID: String, localIdentityID: String, limit: Int = 8) -> [String] {
        dueOutboundItems(for: targetIdentityID, localIdentityID: localIdentityID, limit: limit).map(\.messageID)
    }

    func recordAcceptedOutboundAttempt(messageID: String, targetIdentityID: String, localIdentityID: String) throws {
        let now = Date().timeIntervalSince1970
        // Compute the next retry/backoff in one UPDATE. The previous implementation
        // performed a SELECT followed by UPDATE for every accepted BLE send, which
        // is especially expensive during chunked attachment transfer.
        try write(
            """
            UPDATE outbound_queue
            SET retry_count = MIN(retry_count + 1, 30),
                next_attempt_at = ? + CASE
                    WHEN retry_count <= 0 THEN 4
                    WHEN retry_count = 1 THEN 8
                    WHEN retry_count = 2 THEN 16
                    WHEN retry_count = 3 THEN 32
                    ELSE 60
                END
            WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;
            """,
            bindings: [.double(now), .text(messageID), .text(localIdentityID), .text(targetIdentityID)]
        )
    }

    func deferOutbound(messageID: String, targetIdentityID: String, localIdentityID: String, delay: TimeInterval = 3) throws {
        let safeDelay = min(max(delay, 1), 30)
        try write("UPDATE outbound_queue SET next_attempt_at = ? WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;", bindings: [.double(Date().timeIntervalSince1970 + safeDelay), .text(messageID), .text(localIdentityID), .text(targetIdentityID)])
    }

    func outboundRetryCount(messageID: String, targetIdentityID: String, localIdentityID: String) -> Int {
        read("SELECT retry_count FROM outbound_queue WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ? LIMIT 1;", bindings: [.text(messageID), .text(localIdentityID), .text(targetIdentityID)]) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }

    struct OutboundAttachmentState: Equatable {
        let nextChunk: Int
        let chunkCount: Int
    }

    func configureOutboundAttachment(messageID: String, chunkCount: Int) throws {
        guard chunkCount > 0, chunkCount <= Int(UInt16.max) else {
            throw DatabaseError.statementFailed("附件分块数量超出协议限制。")
        }
        try write(
            "UPDATE outbound_queue SET attachment_next_chunk = -1, attachment_chunk_count = ? WHERE message_id = ?;",
            bindings: [.int(chunkCount), .text(messageID)]
        )
        try updateTransferProgress(messageID: messageID, progress: 0)
    }

    func outboundAttachmentState(messageID: String, targetIdentityID: String, localIdentityID: String) -> OutboundAttachmentState? {
        read(
            "SELECT attachment_next_chunk, attachment_chunk_count FROM outbound_queue WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ? AND attachment_chunk_count > 0 LIMIT 1;",
            bindings: [.text(messageID), .text(localIdentityID), .text(targetIdentityID)]
        ) { statement in
            OutboundAttachmentState(nextChunk: Int(sqlite3_column_int64(statement, 0)), chunkCount: Int(sqlite3_column_int64(statement, 1)))
        }.first
    }

    @discardableResult
    func acceptOutboundAttachmentCheckpoint(messageID: String, targetIdentityID: String, localIdentityID: String, nextChunk: Int, chunkCount: Int) throws -> Bool {
        guard let state = outboundAttachmentState(messageID: messageID, targetIdentityID: targetIdentityID, localIdentityID: localIdentityID),
              state.chunkCount == chunkCount, nextChunk >= 0, nextChunk <= chunkCount else {
            throw DatabaseError.statementFailed("附件 checkpoint 与本地发送状态不一致。")
        }
        let acceptedNextChunk = max(state.nextChunk, nextChunk)
        let now = Date().timeIntervalSince1970
        let didPersistProgress = shouldPersistTransferProgress(index: acceptedNextChunk, total: chunkCount)
        if didPersistProgress {
            let progress = min(max(Double(acceptedNextChunk) / Double(chunkCount), 0), 1)
            try writeBatch([
                (
                    "UPDATE outbound_queue SET attachment_next_chunk = ?, retry_count = 0, next_attempt_at = ? WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;",
                    [.int(acceptedNextChunk), .double(now), .text(messageID), .text(localIdentityID), .text(targetIdentityID)]
                ),
                (
                    "UPDATE messages SET transfer_progress = ? WHERE id = ?;",
                    [.double(progress), .text(messageID)]
                )
            ])
        } else {
            try write(
                "UPDATE outbound_queue SET attachment_next_chunk = ?, retry_count = 0, next_attempt_at = ? WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;",
                bindings: [.int(acceptedNextChunk), .double(now), .text(messageID), .text(localIdentityID), .text(targetIdentityID)]
            )
        }
        return didPersistProgress
    }

    func restartOutbound(messageID: String, targetIdentityID: String, localIdentityID: String) throws {
        let now = Date().timeIntervalSince1970
        try write("UPDATE outbound_queue SET retry_count = 0, next_attempt_at = ?, expires_at = ?, is_paused = 0, attachment_next_chunk = CASE WHEN attachment_chunk_count > 0 THEN -1 ELSE attachment_next_chunk END WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;", bindings: [.double(now), .double(now + 7 * 24 * 60 * 60), .text(messageID), .text(localIdentityID), .text(targetIdentityID)])
        if outboundAttachmentState(messageID: messageID, targetIdentityID: targetIdentityID, localIdentityID: localIdentityID) != nil {
            try updateTransferProgress(messageID: messageID, progress: 0)
        }
    }

    func isOutboundPaused(messageID: String, targetIdentityID: String, localIdentityID: String) -> Bool {
        read(
            "SELECT is_paused FROM outbound_queue WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ? LIMIT 1;",
            bindings: [.text(messageID), .text(localIdentityID), .text(targetIdentityID)]
        ) { sqlite3_column_int($0, 0) == 1 }.first ?? false
    }

    func pauseOutbound(messageID: String, targetIdentityID: String, localIdentityID: String) throws {
        try writeBatch([
            (
                "UPDATE outbound_queue SET is_paused = 1 WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;",
                [.text(messageID), .text(localIdentityID), .text(targetIdentityID)]
            ),
            (
                "UPDATE messages SET delivery_state = ?, delivery_error = NULL WHERE id = ?;",
                [.text(ChatMessage.DeliveryState.paused.rawValue), .text(messageID)]
            )
        ])
    }

    func resumeOutbound(messageID: String, targetIdentityID: String, localIdentityID: String) throws {
        let now = Date().timeIntervalSince1970
        try writeBatch([
            (
                "UPDATE outbound_queue SET is_paused = 0, retry_count = 0, next_attempt_at = ?, expires_at = ? WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;",
                [.double(now), .double(now + 7 * 24 * 60 * 60), .text(messageID), .text(localIdentityID), .text(targetIdentityID)]
            ),
            (
                "UPDATE messages SET delivery_state = ?, delivery_error = NULL WHERE id = ?;",
                [.text(ChatMessage.DeliveryState.queued.rawValue), .text(messageID)]
            )
        ])
    }

    func cancelOutbound(messageID: String, targetIdentityID: String, localIdentityID: String) throws {
        try writeBatch([
            (
                "DELETE FROM outbound_queue WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;",
                [.text(messageID), .text(localIdentityID), .text(targetIdentityID)]
            ),
            (
                "UPDATE messages SET delivery_state = ?, delivery_error = ? WHERE id = ?;",
                [.text(ChatMessage.DeliveryState.cancelled.rawValue), .text("已取消发送。"), .text(messageID)]
            )
        ])
    }

    func completeOutbound(messageID: String, targetIdentityID: String, localIdentityID: String) throws {
        try write("DELETE FROM outbound_queue WHERE message_id = ? AND local_identity_id = ? AND target_identity_id = ?;", bindings: [.text(messageID), .text(localIdentityID), .text(targetIdentityID)])
    }

    func expireOutboundMessages() throws {
        let now = Date().timeIntervalSince1970
        let reason = sqlLiteral("超过 7 天仍未送达。可在对话中手动重试。")
        try transaction("""
            UPDATE messages
            SET delivery_state = '\(ChatMessage.DeliveryState.failed.rawValue)', delivery_error = '\(reason)'
            WHERE id IN (SELECT message_id FROM outbound_queue WHERE expires_at <= \(now));
            DELETE FROM outbound_queue WHERE expires_at <= \(now);
            """)
    }

    @discardableResult
    func cleanupCompletedInboundTransferMetadata() throws -> Int {
        let count = read("SELECT COUNT(*) FROM inbound_attachment_transfers WHERE completed = 1;") {
            Int(sqlite3_column_int64($0, 0))
        }.first ?? 0
        guard count > 0 else { return 0 }
        try transaction("""
            UPDATE messages
            SET transfer_progress = CASE
                WHEN EXISTS (SELECT 1 FROM attachments a WHERE a.message_id = messages.id) THEN 1
                ELSE 0
            END
            WHERE id IN (SELECT message_id FROM inbound_attachment_transfers WHERE completed = 1);
            DELETE FROM inbound_attachment_chunks
            WHERE message_id IN (SELECT message_id FROM inbound_attachment_transfers WHERE completed = 1);
            DELETE FROM inbound_attachment_transfers WHERE completed = 1;
            """)
        return count
    }

    @discardableResult
    func cleanupStaleInboundAttachments(now: Date = Date(), maxAge: TimeInterval = DatabaseStore.inboundAttachmentRetention) throws -> Int {
        let safeAge = max(60, maxAge)
        let cutoff = now.timeIntervalSince1970 - safeAge
        let count = read(
            "SELECT COUNT(*) FROM inbound_attachment_transfers WHERE completed = 0 AND updated_at < ?;",
            bindings: [.double(cutoff)]
        ) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        guard count > 0 else { return 0 }
        try transaction("""
            UPDATE messages SET transfer_progress = 0
            WHERE id IN (
                SELECT message_id FROM inbound_attachment_transfers
                WHERE completed = 0 AND updated_at < \(cutoff)
            );
            DELETE FROM inbound_attachment_chunks
            WHERE message_id IN (
                SELECT message_id FROM inbound_attachment_transfers
                WHERE completed = 0 AND updated_at < \(cutoff)
            );
            DELETE FROM inbound_attachment_transfers
            WHERE completed = 0 AND updated_at < \(cutoff);
            """)
        return count
    }

    struct InboundAttachmentState: Equatable {
        let nextChunk: Int
        let chunkCount: Int
        let completed: Bool
        let didPersistProgress: Bool

        init(nextChunk: Int, chunkCount: Int, completed: Bool, didPersistProgress: Bool = false) {
            self.nextChunk = nextChunk
            self.chunkCount = chunkCount
            self.completed = completed
            self.didPersistProgress = didPersistProgress
        }
    }

    func beginInboundAttachment(messageID: String, byteCount: Int, mimeType: String, sha256: Data, chunkCount: Int) throws -> InboundAttachmentState {
        guard byteCount > 0, byteCount <= MediaTransferPolicy.maximumImageBytes,
              MediaTransferPolicy.supportsImageMIMEType(mimeType), sha256.count == 32,
              chunkCount > 0, chunkCount <= Int(UInt16.max) else {
            throw DatabaseError.statementFailed("收到的附件 Manifest 无效。")
        }
        _ = try cleanupStaleInboundAttachments()

        if let stored = storedAttachmentMetadata(messageID: messageID) {
            guard stored.byteCount == byteCount, stored.mimeType == mimeType, stored.sha256 == sha256 else {
                throw DatabaseError.statementFailed("同一消息的已保存附件与 Manifest 冲突。")
            }
            try write("DELETE FROM inbound_attachment_chunks WHERE message_id = ?;", bindings: [.text(messageID)])
            try write("DELETE FROM inbound_attachment_transfers WHERE message_id = ?;", bindings: [.text(messageID)])
            try updateTransferProgress(messageID: messageID, progress: 1)
            return InboundAttachmentState(nextChunk: chunkCount, chunkCount: chunkCount, completed: true)
        }

        if let existing = inboundAttachmentMetadata(messageID: messageID) {
            guard existing.byteCount == byteCount, existing.mimeType == mimeType, existing.sha256 == sha256, existing.chunkCount == chunkCount else {
                throw DatabaseError.statementFailed("同一消息的附件 Manifest 发生冲突。")
            }
            if existing.completed {
                // A completed marker without the final attachment is inconsistent.
                // Drop only temporary state so the authenticated sender can restart.
                try write("DELETE FROM inbound_attachment_chunks WHERE message_id = ?;", bindings: [.text(messageID)])
                try write("DELETE FROM inbound_attachment_transfers WHERE message_id = ?;", bindings: [.text(messageID)])
                try updateTransferProgress(messageID: messageID, progress: 0)
            } else {
                let next = inboundNextChunk(messageID: messageID, chunkCount: chunkCount)
                if next == chunkCount {
                    try finalizeInboundAttachment(messageID: messageID, metadata: existing)
                    return InboundAttachmentState(nextChunk: chunkCount, chunkCount: chunkCount, completed: true)
                }
                return InboundAttachmentState(nextChunk: next, chunkCount: chunkCount, completed: false)
            }
        }
        guard let senderIdentityID = read("SELECT sender_identity_id FROM messages WHERE id = ? AND is_outgoing = 0 LIMIT 1;", bindings: [.text(messageID)]) { text($0, 0) }.first,
              !senderIdentityID.isEmpty else {
            throw DatabaseError.statementFailed("附件 Manifest 缺少有效发送者。")
        }
        let activeTransfers = read("SELECT COUNT(*) FROM inbound_attachment_transfers WHERE completed = 0;") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        guard activeTransfers < Self.maximumIncompleteInboundAttachments else {
            throw DatabaseError.statementFailed("未完成的附件传输过多，请先完成或等待旧传输清理。")
        }
        let activeFromSender = read(
            """
            SELECT COUNT(*) FROM inbound_attachment_transfers t
            JOIN messages m ON m.id = t.message_id
            WHERE t.completed = 0 AND m.is_outgoing = 0 AND m.sender_identity_id = ?;
            """,
            bindings: [.text(senderIdentityID)]
        ) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
        guard activeFromSender < Self.maximumIncompleteInboundAttachmentsPerSender else {
            throw DatabaseError.statementFailed("该发送者同时存在过多未完成附件。")
        }
        try write(
            "INSERT INTO inbound_attachment_transfers(message_id, byte_count, mime_type, sha256, chunk_count, completed, updated_at) VALUES(?, ?, ?, ?, ?, 0, ?);",
            bindings: [.text(messageID), .int(byteCount), .text(mimeType), .blob(sha256), .int(chunkCount), .double(Date().timeIntervalSince1970)]
        )
        try updateTransferProgress(messageID: messageID, progress: 0)
        return InboundAttachmentState(nextChunk: 0, chunkCount: chunkCount, completed: false)
    }

    func storeInboundAttachmentChunk(messageID: String, index: Int, chunkCount: Int, clearData: Data) throws -> InboundAttachmentState {
        guard let metadata = inboundAttachmentMetadata(messageID: messageID),
              metadata.chunkCount == chunkCount, !clearData.isEmpty, index >= 0, index < chunkCount else {
            throw DatabaseError.statementFailed("附件分块与 Manifest 不一致。")
        }
        if metadata.completed { return InboundAttachmentState(nextChunk: chunkCount, chunkCount: chunkCount, completed: true) }

        if let existing = inboundChunkClearData(messageID: messageID, index: index) {
            guard existing == clearData else { throw DatabaseError.statementFailed("收到冲突的重复附件分块。") }
        } else {
            let protected = try ChaChaPoly.seal(clearData, using: storageKey).combined
            try write(
                "INSERT INTO inbound_attachment_chunks(message_id, chunk_index, ciphertext, clear_byte_count) VALUES(?, ?, ?, ?);",
                bindings: [.text(messageID), .int(index), .blob(protected), .int(clearData.count)]
            )
        }

        let next = inboundNextChunk(messageID: messageID, chunkCount: chunkCount)
        try write("UPDATE inbound_attachment_transfers SET updated_at = ? WHERE message_id = ?;", bindings: [.double(Date().timeIntervalSince1970), .text(messageID)])
        let didPersistProgress = shouldPersistTransferProgress(index: next, total: chunkCount)
        if didPersistProgress {
            try updateTransferProgress(messageID: messageID, progress: Double(next) / Double(chunkCount))
        }
        if next == chunkCount {
            try finalizeInboundAttachment(messageID: messageID, metadata: metadata)
            return InboundAttachmentState(nextChunk: chunkCount, chunkCount: chunkCount, completed: true, didPersistProgress: true)
        }
        return InboundAttachmentState(nextChunk: next, chunkCount: chunkCount, completed: false, didPersistProgress: didPersistProgress)
    }

    private struct StoredAttachmentMetadata {
        let byteCount: Int
        let mimeType: String
        let sha256: Data
    }

    private func storedAttachmentMetadata(messageID: String) -> StoredAttachmentMetadata? {
        read(
            "SELECT byte_count, mime_type, sha256 FROM attachments WHERE message_id = ? LIMIT 1;",
            bindings: [.text(messageID)]
        ) { statement in
            StoredAttachmentMetadata(
                byteCount: Int(sqlite3_column_int64(statement, 0)),
                mimeType: text(statement, 1),
                sha256: data(statement, 2)
            )
        }.first
    }

    private func shouldPersistTransferProgress(index: Int, total: Int) -> Bool {
        guard total > 0 else { return true }
        if index <= 0 || index >= total { return true }
        let stride = max(1, total / 32)
        return index % stride == 0
    }

    private struct InboundAttachmentMetadata {
        let byteCount: Int
        let mimeType: String
        let sha256: Data
        let chunkCount: Int
        let completed: Bool
    }

    private func inboundAttachmentMetadata(messageID: String) -> InboundAttachmentMetadata? {
        read(
            "SELECT byte_count, mime_type, sha256, chunk_count, completed FROM inbound_attachment_transfers WHERE message_id = ? LIMIT 1;",
            bindings: [.text(messageID)]
        ) { statement in
            InboundAttachmentMetadata(
                byteCount: Int(sqlite3_column_int64(statement, 0)),
                mimeType: text(statement, 1),
                sha256: data(statement, 2),
                chunkCount: Int(sqlite3_column_int64(statement, 3)),
                completed: sqlite3_column_int(statement, 4) == 1
            )
        }.first
    }

    private func inboundChunkClearData(messageID: String, index: Int) -> Data? {
        guard let protected = read(
            "SELECT ciphertext FROM inbound_attachment_chunks WHERE message_id = ? AND chunk_index = ? LIMIT 1;",
            bindings: [.text(messageID), .int(index)]
        ) { data($0, 0) }.first,
              let box = try? ChaChaPoly.SealedBox(combined: protected),
              let clear = try? ChaChaPoly.open(box, using: storageKey) else { return nil }
        return clear
    }

    private func inboundNextChunk(messageID: String, chunkCount: Int) -> Int {
        let indexes = read(
            "SELECT chunk_index FROM inbound_attachment_chunks WHERE message_id = ? ORDER BY chunk_index ASC;",
            bindings: [.text(messageID)]
        ) { Int(sqlite3_column_int64($0, 0)) }
        var next = 0
        for index in indexes {
            if index == next { next += 1 }
            else if index > next { break }
        }
        return min(next, chunkCount)
    }

    private func finalizeInboundAttachment(messageID: String, metadata: InboundAttachmentMetadata) throws {
        if fetchMessage(id: messageID)?.attachment != nil {
            try write("DELETE FROM inbound_attachment_chunks WHERE message_id = ?;", bindings: [.text(messageID)])
            try write("DELETE FROM inbound_attachment_transfers WHERE message_id = ?;", bindings: [.text(messageID)])
            try updateTransferProgress(messageID: messageID, progress: 1)
            return
        }
        var assembled = Data()
        assembled.reserveCapacity(metadata.byteCount)
        for index in 0..<metadata.chunkCount {
            guard let chunk = inboundChunkClearData(messageID: messageID, index: index) else {
                throw DatabaseError.statementFailed("附件 checkpoint 指向不存在的分块。")
            }
            assembled.append(chunk)
            guard assembled.count <= metadata.byteCount else { throw DatabaseError.statementFailed("附件实际体积超过 Manifest。") }
        }
        guard assembled.count == metadata.byteCount, Data(SHA256.hash(data: assembled)) == metadata.sha256 else {
            throw DatabaseError.statementFailed("附件完整性校验失败。")
        }
        _ = try saveAttachment(messageID: messageID, data: assembled, mimeType: metadata.mimeType)
        try write("DELETE FROM inbound_attachment_chunks WHERE message_id = ?;", bindings: [.text(messageID)])
        try write("DELETE FROM inbound_attachment_transfers WHERE message_id = ?;", bindings: [.text(messageID)])
        try updateTransferProgress(messageID: messageID, progress: 1)
    }

    func fetchConversations(localIdentityID: String) -> [ConversationSummary] {
        read(
            """
            SELECT id, title, peer_identity_id, COALESCE(last_message_preview, ''), updated_at, unread_count, is_pinned
            FROM conversations WHERE local_identity_id = ? ORDER BY is_pinned DESC, updated_at DESC;
            """,
            bindings: [.text(localIdentityID)]
        ) { statement in
            let previewBlob = data(statement, 3)
            let preview: String
            if let box = try? ChaChaPoly.SealedBox(combined: previewBlob),
               let clear = try? ChaChaPoly.open(box, using: storageKey) {
                preview = String(data: clear, encoding: .utf8) ?? ""
            } else {
                preview = ""
            }
            return ConversationSummary(
                id: text(statement, 0),
                title: text(statement, 1),
                peerIdentityID: text(statement, 2),
                lastMessage: preview,
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                unreadCount: Int(sqlite3_column_int(statement, 5)),
                isPinned: sqlite3_column_int(statement, 6) == 1
            )
        }
    }

    func fetchMessages(conversationID: String) -> [ChatMessage] {
        read("""
            SELECT m.id, m.conversation_id, m.sender_identity_id, m.body_ciphertext,
                   m.sent_at, m.is_outgoing, m.delivery_state, m.delivery_error, m.transfer_progress, a.id, a.mime_type, a.byte_count
            FROM messages m LEFT JOIN attachments a ON a.message_id = m.id
            WHERE m.conversation_id = ? ORDER BY m.sent_at ASC;
            """, bindings: [.text(conversationID)]) { decodedMessage($0) }
    }


    func setConversationPinned(conversationID: String, pinned: Bool) throws {
        try write(
            "UPDATE conversations SET is_pinned = ? WHERE id = ?;",
            bindings: [.int(pinned ? 1 : 0), .text(conversationID)]
        )
    }

    func markConversationRead(conversationID: String) throws {
        try write(
            "UPDATE conversations SET unread_count = 0 WHERE id = ?;",
            bindings: [.text(conversationID)]
        )
    }

    func markConversationUnread(conversationID: String) throws {
        try write(
            "UPDATE conversations SET unread_count = CASE WHEN unread_count < 1 THEN 1 ELSE unread_count END WHERE id = ?;",
            bindings: [.text(conversationID)]
        )
    }

    func deleteMessageLocally(messageID: String, conversationID: String) throws {
        guard let message = fetchMessage(id: messageID), message.conversationID == conversationID else { return }
        if !message.isOutgoing, message.attachment != nil, (message.transferProgress ?? 0) < 1 {
            throw DatabaseError.statementFailed("正在接收的图片完成前不能直接本地删除；请等待传输完成。")
        }
        let attachmentPaths = read(
            "SELECT relative_path FROM attachments WHERE message_id = ?;",
            bindings: [.text(messageID)]
        ) { text($0, 0) }
        let replacement = read(
            "SELECT body_ciphertext, sent_at FROM messages WHERE conversation_id = ? AND id <> ? ORDER BY sent_at DESC LIMIT 1;",
            bindings: [.text(conversationID), .text(messageID)]
        ) { statement in (data(statement, 0), sqlite3_column_double(statement, 1)) }.first
        let replacementPreview = try replacement.map { encryptedBody, sentAt -> (Data, Double) in
            let clear = try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: encryptedBody), using: storageKey)
            guard let body = String(data: clear, encoding: .utf8) else { throw DatabaseError.statementFailed("本地消息预览无法解密。") }
            let preview = ReplyTextCodec.previewText(for: body)
            return (try ChaChaPoly.seal(Data(preview.utf8), using: storageKey).combined, sentAt)
        }
        let emptyPreview = try ChaChaPoly.seal(Data(), using: storageKey).combined
        var statements: [(String, [SQLiteValue])] = []
        if !message.isOutgoing {
            statements.append((
                "INSERT OR REPLACE INTO local_message_tombstones(message_id, sender_identity_id, expires_at) VALUES(?, ?, ?);",
                [.text(message.id), .text(message.senderIdentityID), .double(Date().timeIntervalSince1970 + Self.localDeletionTombstoneRetention)]
            ))
        }
        statements.append(("DELETE FROM messages WHERE id = ? AND conversation_id = ?;", [.text(messageID), .text(conversationID)]))
        if let replacementPreview {
            statements.append((
                "UPDATE conversations SET last_message_preview = ?, updated_at = ? WHERE id = ?;",
                [.blob(replacementPreview.0), .double(replacementPreview.1), .text(conversationID)]
            ))
        } else {
            statements.append((
                "UPDATE conversations SET last_message_preview = ? WHERE id = ?;",
                [.blob(emptyPreview), .text(conversationID)]
            ))
        }
        try writeBatch(statements)
        removeAttachmentFiles(relativePaths: attachmentPaths)
    }

    func hasIncompleteInboundAttachments(conversationID: String) -> Bool {
        !read(
            """
            SELECT 1 FROM inbound_attachment_transfers t
            JOIN messages m ON m.id = t.message_id
            WHERE m.conversation_id = ? AND m.is_outgoing = 0 AND t.completed = 0
            LIMIT 1;
            """,
            bindings: [.text(conversationID)]
        ) { _ in true }.isEmpty
    }

    func clearConversationLocally(conversationID: String) throws {
        guard !hasIncompleteInboundAttachments(conversationID: conversationID) else {
            throw DatabaseError.statementFailed("当前仍有图片正在接收。请等待图片完成后再清空聊天记录。")
        }
        let attachmentPaths = read(
            """
            SELECT a.relative_path FROM attachments a
            JOIN messages m ON m.id = a.message_id
            WHERE m.conversation_id = ?;
            """,
            bindings: [.text(conversationID)]
        ) { text($0, 0) }
        let emptyPreview = try ChaChaPoly.seal(Data(), using: storageKey).combined
        let expiresAt = Date().timeIntervalSince1970 + Self.localDeletionTombstoneRetention
        try writeBatch([
            (
                "INSERT OR REPLACE INTO local_message_tombstones(message_id, sender_identity_id, expires_at) SELECT id, sender_identity_id, ? FROM messages WHERE conversation_id = ? AND is_outgoing = 0;",
                [.double(expiresAt), .text(conversationID)]
            ),
            ("DELETE FROM messages WHERE conversation_id = ?;", [.text(conversationID)]),
            (
                "UPDATE conversations SET last_message_preview = ?, unread_count = 0, updated_at = ? WHERE id = ?;",
                [.blob(emptyPreview), .double(Date().timeIntervalSince1970), .text(conversationID)]
            )
        ])
        removeAttachmentFiles(relativePaths: attachmentPaths)
    }

    func isLocallyDeletedMessage(messageID: String, senderIdentityID: String) -> Bool {
        let now = Date().timeIntervalSince1970
        return !read(
            "SELECT 1 FROM local_message_tombstones WHERE message_id = ? AND sender_identity_id = ? AND expires_at > ? LIMIT 1;",
            bindings: [.text(messageID), .text(senderIdentityID), .double(now)]
        ) { _ in true }.isEmpty
    }

    @discardableResult
    func cleanupExpiredLocalDeletionTombstones() throws -> Int {
        let now = Date().timeIntervalSince1970
        let count = read("SELECT COUNT(*) FROM local_message_tombstones WHERE expires_at <= ?;", bindings: [.double(now)]) {
            Int(sqlite3_column_int64($0, 0))
        }.first ?? 0
        if count > 0 {
            try write("DELETE FROM local_message_tombstones WHERE expires_at <= ?;", bindings: [.double(now)])
        }
        return count
    }

    private func removeAttachmentFiles(relativePaths: [String]) {
        for relativePath in relativePaths {
            let url = attachmentsURL.appendingPathComponent(relativePath)
            guard url.standardizedFileURL.deletingLastPathComponent() == attachmentsURL.standardizedFileURL else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    func createConsistentSnapshot(at destinationURL: URL) throws {
        try queue.sync {
            guard let source = db else { throw DatabaseError.backupFailed("数据库尚未打开。") }
            try? FileManager.default.removeItem(at: destinationURL)
            var destination: OpaquePointer?
            guard sqlite3_open(destinationURL.path, &destination) == SQLITE_OK,
                  let destination else {
                sqlite3_close(destination)
                throw DatabaseError.backupFailed("无法创建备份数据库。")
            }
            defer { sqlite3_close(destination) }

            guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
                throw DatabaseError.backupFailed(String(cString: sqlite3_errmsg(destination)))
            }
            defer { sqlite3_backup_finish(backup) }
            guard sqlite3_backup_step(backup, -1) == SQLITE_DONE else {
                throw DatabaseError.backupFailed(String(cString: sqlite3_errmsg(destination)))
            }
        }
    }

    func validateSnapshot(at snapshotURL: URL) throws {
        var handle: OpaquePointer?
        let immutableURI = snapshotURL.absoluteString + "?immutable=1"
        guard sqlite3_open_v2(immutableURI, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let handle else {
            sqlite3_close(handle)
            throw DatabaseError.backupFailed("恢复包中的数据库无法打开。")
        }
        defer { sqlite3_close(handle) }

        var integrityStatement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "PRAGMA integrity_check;", -1, &integrityStatement, nil) == SQLITE_OK,
              let integrityStatement else {
            throw DatabaseError.backupFailed("无法验证恢复数据库完整性。")
        }
        defer { sqlite3_finalize(integrityStatement) }
        guard sqlite3_step(integrityStatement) == SQLITE_ROW,
              let integrityText = sqlite3_column_text(integrityStatement, 0),
              String(cString: integrityText).lowercased() == "ok" else {
            throw DatabaseError.backupFailed("恢复数据库完整性校验失败。")
        }

        let requiredTables = ["profiles", "contacts", "conversations", "messages", "attachments"]
        for table in requiredTables {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(
                handle,
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1;",
                -1,
                &statement,
                nil
            ) == SQLITE_OK, let statement else {
                throw DatabaseError.backupFailed("无法验证恢复数据库结构。")
            }
            defer { sqlite3_finalize(statement) }
            table.withCString { sqlite3_bind_text(statement, 1, $0, -1, transient) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw DatabaseError.backupFailed("恢复数据库缺少必要数据表：\(table)。")
            }
        }
    }

    func replaceDatabase(with snapshotURL: URL) throws {
        try queue.sync {
            guard let current = db else { throw DatabaseError.openFailed("数据库尚未打开。") }
            var source: OpaquePointer?
            let immutableURI = snapshotURL.absoluteString + "?immutable=1"
            guard sqlite3_open_v2(immutableURI, &source, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
                  let source else {
                sqlite3_close(source)
                throw DatabaseError.backupFailed("恢复包中的数据库无法打开。")
            }
            defer { sqlite3_close(source) }
            guard let backup = sqlite3_backup_init(current, "main", source, "main") else {
                throw DatabaseError.backupFailed(String(cString: sqlite3_errmsg(current)))
            }
            defer { sqlite3_backup_finish(backup) }
            guard sqlite3_backup_step(backup, -1) == SQLITE_DONE else {
                throw DatabaseError.backupFailed(String(cString: sqlite3_errmsg(current)))
            }
        }
        try migrate()
    }

    func integrityCheck() -> String {
        read("PRAGMA integrity_check;") { text($0, 0) }.first ?? "unknown"
    }

    func verifyStorageKey() throws {
        let markerName = "storage-key-check-v1"
        let expected = Data("VeilLink/StorageKeyCheck/v1".utf8)
        if let protectedMarker = read(
            "SELECT value FROM secure_metadata WHERE key = ? LIMIT 1;",
            bindings: [.text(markerName)]
        ) { data($0, 0) }.first {
            guard let box = try? ChaChaPoly.SealedBox(combined: protectedMarker),
                  let clear = try? ChaChaPoly.open(box, using: storageKey),
                  clear == expected else { throw DatabaseError.encryptionKeyMismatch }
            return
        }

        // Databases created before V0.2 have no marker. Validate at least one existing
        // encrypted payload before trusting the current Keychain key, then install it.
        if let protectedBody = read("SELECT body_ciphertext FROM messages LIMIT 1;") { data($0, 0) }.first {
            guard let box = try? ChaChaPoly.SealedBox(combined: protectedBody),
                  (try? ChaChaPoly.open(box, using: storageKey)) != nil else {
                throw DatabaseError.encryptionKeyMismatch
            }
        } else if let relativePath = read("SELECT relative_path FROM attachments LIMIT 1;") { text($0, 0) }.first {
            let url = attachmentsURL.appendingPathComponent(relativePath)
            guard let protectedAttachment = try? Data(contentsOf: url),
                  let box = try? ChaChaPoly.SealedBox(combined: protectedAttachment),
                  (try? ChaChaPoly.open(box, using: storageKey)) != nil else {
                throw DatabaseError.encryptionKeyMismatch
            }
        }

        let protectedMarker = try ChaChaPoly.seal(expected, using: storageKey).combined
        try write(
            "INSERT OR REPLACE INTO secure_metadata(key, value) VALUES(?, ?);",
            bindings: [.text(markerName), .blob(protectedMarker)]
        )
    }

    func wrappedStorageKey(using backupKey: SymmetricKey) throws -> Data {
        try ChaChaPoly.seal(storageKeyData, using: backupKey).combined
    }

    func installWrappedStorageKey(_ wrapped: Data, using backupKey: SymmetricKey) throws {
        let box = try ChaChaPoly.SealedBox(combined: wrapped)
        let rawKey = try ChaChaPoly.open(box, using: backupKey)
        guard rawKey.count == 32 else { throw BackupError.corruptedPackage }
        try keychain.set(rawKey, for: storageKeyName)
        storageKeyData = rawKey
        storageKey = SymmetricKey(data: rawKey)
    }

    private func decodedMessage(_ statement: OpaquePointer) -> ChatMessage {
        let blob = data(statement, 3)
        let plaintext: Data
        if let box = try? ChaChaPoly.SealedBox(combined: blob), let opened = try? ChaChaPoly.open(box, using: storageKey) { plaintext = opened } else { plaintext = Data() }
        let failureReason = sqlite3_column_type(statement, 7) == SQLITE_NULL ? nil : text(statement, 7)
        let transferProgress = sqlite3_column_type(statement, 8) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 8)
        let attachment: ChatAttachment?
        if sqlite3_column_type(statement, 9) != SQLITE_NULL { attachment = ChatAttachment(id: text(statement, 9), mimeType: text(statement, 10), byteCount: Int(sqlite3_column_int64(statement, 11))) } else { attachment = nil }
        return ChatMessage(id: text(statement, 0), conversationID: text(statement, 1), senderIdentityID: text(statement, 2), body: String(data: plaintext, encoding: .utf8) ?? "", sentAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)), isOutgoing: sqlite3_column_int(statement, 5) == 1, deliveryState: ChatMessage.DeliveryState(rawValue: text(statement, 6)) ?? .failed, failureReason: failureReason, transferProgress: transferProgress, attachment: attachment)
    }

    func adoptLegacyUnscopedRows(localIdentityID: String) throws {
        guard !localIdentityID.isEmpty else { return }
        try transaction("""
            UPDATE OR IGNORE contacts SET local_identity_id = '\(sqlLiteral(localIdentityID))' WHERE local_identity_id = '';
            DELETE FROM contacts WHERE local_identity_id = '' AND EXISTS (
                SELECT 1 FROM contacts scoped
                WHERE scoped.local_identity_id = '\(sqlLiteral(localIdentityID))' AND scoped.identity_id = contacts.identity_id
            );
            UPDATE conversations SET local_identity_id = '\(sqlLiteral(localIdentityID))' WHERE local_identity_id = '';
            UPDATE outbound_queue SET local_identity_id = '\(sqlLiteral(localIdentityID))' WHERE local_identity_id = '';
            """)
    }

    func pendingOutboundCount(localIdentityID: String) -> Int {
        read("SELECT COUNT(*) FROM outbound_queue WHERE local_identity_id = ? AND expires_at > ?;", bindings: [.text(localIdentityID), .double(Date().timeIntervalSince1970)]) {
            Int(sqlite3_column_int64($0, 0))
        }.first ?? 0
    }

    func databaseSizeBytes() -> Int64 {
        (try? databaseURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private func migrate() throws {
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA foreign_keys=ON;")
        try execute("PRAGMA synchronous=NORMAL;")
        try execute("PRAGMA busy_timeout=3000;")
        try execute("PRAGMA wal_autocheckpoint=512;")
        try execute("PRAGMA journal_size_limit=4194304;")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations(
                version INTEGER PRIMARY KEY,
                applied_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS profiles(
                id TEXT PRIMARY KEY,
                display_name TEXT NOT NULL,
                public_key BLOB NOT NULL,
                created_at REAL NOT NULL,
                is_primary INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS contacts(
                local_identity_id TEXT NOT NULL,
                identity_id TEXT NOT NULL,
                display_name TEXT NOT NULL,
                public_key BLOB NOT NULL,
                trust_state TEXT NOT NULL,
                created_at REAL NOT NULL,
                PRIMARY KEY(local_identity_id, identity_id)
            );
            CREATE TABLE IF NOT EXISTS conversations(
                id TEXT PRIMARY KEY,
                local_identity_id TEXT NOT NULL,
                peer_identity_id TEXT NOT NULL,
                title TEXT NOT NULL,
                last_message_preview TEXT,
                updated_at REAL NOT NULL,
                unread_count INTEGER NOT NULL DEFAULT 0,
                is_pinned INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS messages(
                id TEXT PRIMARY KEY,
                conversation_id TEXT NOT NULL,
                sender_identity_id TEXT NOT NULL,
                body_ciphertext BLOB NOT NULL,
                sent_at REAL NOT NULL,
                is_outgoing INTEGER NOT NULL,
                delivery_state TEXT NOT NULL,
                delivery_error TEXT,
                transfer_progress REAL,
                FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_messages_conversation_time
                ON messages(conversation_id, sent_at);
            CREATE TABLE IF NOT EXISTS attachments(
                id TEXT PRIMARY KEY,
                message_id TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                mime_type TEXT NOT NULL,
                byte_count INTEGER NOT NULL,
                sha256 BLOB NOT NULL,
                FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS pending_packets(
                id TEXT PRIMARY KEY,
                target_identity_id TEXT NOT NULL,
                encrypted_payload BLOB NOT NULL,
                expires_at REAL NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS outbound_queue(
                message_id TEXT PRIMARY KEY, local_identity_id TEXT NOT NULL, target_identity_id TEXT NOT NULL, created_at REAL NOT NULL, next_attempt_at REAL NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0, expires_at REAL NOT NULL,
                attachment_next_chunk INTEGER NOT NULL DEFAULT -1, attachment_chunk_count INTEGER NOT NULL DEFAULT 0,
                is_paused INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS inbound_attachment_transfers(
                message_id TEXT PRIMARY KEY,
                byte_count INTEGER NOT NULL,
                mime_type TEXT NOT NULL,
                sha256 BLOB NOT NULL,
                chunk_count INTEGER NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0,
                updated_at REAL NOT NULL,
                FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS inbound_attachment_chunks(
                message_id TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                ciphertext BLOB NOT NULL,
                clear_byte_count INTEGER NOT NULL,
                PRIMARY KEY(message_id, chunk_index),
                FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS local_message_tombstones(
                message_id TEXT NOT NULL,
                sender_identity_id TEXT NOT NULL,
                expires_at REAL NOT NULL,
                PRIMARY KEY(message_id, sender_identity_id)
            );
            CREATE INDEX IF NOT EXISTS idx_local_message_tombstones_expiry
                ON local_message_tombstones(expires_at);
            CREATE TABLE IF NOT EXISTS secure_metadata(
                key TEXT PRIMARY KEY,
                value BLOB NOT NULL
            );
            CREATE TABLE IF NOT EXISTS audit_events(
                id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                redacted_detail TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            INSERT OR IGNORE INTO schema_migrations(version, applied_at)
                VALUES(1, strftime('%s','now'));
            INSERT OR IGNORE INTO schema_migrations(version, applied_at)
                VALUES(2, strftime('%s','now'));
            """
        )
        try migrateIdentityScopeV4()
        try execute("INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES(4, strftime('%s','now'));")
        try migrateDeliveryLifecycleV5()
        try execute("INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES(5, strftime('%s','now'));")
        try migrateAttachmentResumeV6()
        try execute("INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES(6, strftime('%s','now'));")
        try migrateUserTransferControlsV7()
        try execute("INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES(7, strftime('%s','now'));")
        try migrateConversationControlsV8()
        try execute("INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES(8, strftime('%s','now'));")
    }

    private func migrateDeliveryLifecycleV5() throws {
        if !columnExists(table: "messages", column: "delivery_error") {
            try execute("ALTER TABLE messages ADD COLUMN delivery_error TEXT;")
        }
    }

    private func migrateAttachmentResumeV6() throws {
        if !columnExists(table: "messages", column: "transfer_progress") {
            try execute("ALTER TABLE messages ADD COLUMN transfer_progress REAL;")
        }
        if !columnExists(table: "outbound_queue", column: "attachment_next_chunk") {
            try execute("ALTER TABLE outbound_queue ADD COLUMN attachment_next_chunk INTEGER NOT NULL DEFAULT -1;")
        }
        if !columnExists(table: "outbound_queue", column: "attachment_chunk_count") {
            try execute("ALTER TABLE outbound_queue ADD COLUMN attachment_chunk_count INTEGER NOT NULL DEFAULT 0;")
        }
        try execute("""
            CREATE TABLE IF NOT EXISTS inbound_attachment_transfers(
                message_id TEXT PRIMARY KEY, byte_count INTEGER NOT NULL, mime_type TEXT NOT NULL,
                sha256 BLOB NOT NULL, chunk_count INTEGER NOT NULL, completed INTEGER NOT NULL DEFAULT 0,
                updated_at REAL NOT NULL, FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS inbound_attachment_chunks(
                message_id TEXT NOT NULL, chunk_index INTEGER NOT NULL, ciphertext BLOB NOT NULL, clear_byte_count INTEGER NOT NULL,
                PRIMARY KEY(message_id, chunk_index), FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_inbound_attachment_chunks_message ON inbound_attachment_chunks(message_id, chunk_index);
            CREATE INDEX IF NOT EXISTS idx_inbound_attachment_stale_v6 ON inbound_attachment_transfers(completed, updated_at);
            """)
    }

    private func migrateUserTransferControlsV7() throws {
        if !columnExists(table: "outbound_queue", column: "is_paused") {
            try execute("ALTER TABLE outbound_queue ADD COLUMN is_paused INTEGER NOT NULL DEFAULT 0;")
        }
        try execute("CREATE INDEX IF NOT EXISTS idx_outbound_due_v7 ON outbound_queue(local_identity_id, target_identity_id, is_paused, next_attempt_at);")
        try execute("""
            CREATE TABLE IF NOT EXISTS local_message_tombstones(
                message_id TEXT NOT NULL, sender_identity_id TEXT NOT NULL, expires_at REAL NOT NULL,
                PRIMARY KEY(message_id, sender_identity_id)
            );
            CREATE INDEX IF NOT EXISTS idx_local_message_tombstones_expiry
                ON local_message_tombstones(expires_at);
            """)
    }

    private func migrateConversationControlsV8() throws {
        if !columnExists(table: "conversations", column: "is_pinned") {
            try execute("ALTER TABLE conversations ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0;")
        }
        try execute("CREATE INDEX IF NOT EXISTS idx_conversations_pinned_v8 ON conversations(local_identity_id, is_pinned, updated_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS idx_conversations_peer_v8 ON conversations(local_identity_id, peer_identity_id, updated_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS idx_attachments_message_v8 ON attachments(message_id);")
    }

    private func migrateIdentityScopeV4() throws {
        if !columnExists(table: "contacts", column: "local_identity_id") {
            try transaction("""
                ALTER TABLE contacts RENAME TO contacts_legacy_v3;
                CREATE TABLE contacts(
                    local_identity_id TEXT NOT NULL, identity_id TEXT NOT NULL, display_name TEXT NOT NULL,
                    public_key BLOB NOT NULL, trust_state TEXT NOT NULL, created_at REAL NOT NULL,
                    PRIMARY KEY(local_identity_id, identity_id)
                );
                INSERT OR IGNORE INTO contacts(local_identity_id, identity_id, display_name, public_key, trust_state, created_at)
                SELECT COALESCE((SELECT id FROM profiles ORDER BY is_primary DESC, created_at ASC LIMIT 1), ''),
                       identity_id, display_name, public_key, trust_state, created_at FROM contacts_legacy_v3;
                DROP TABLE contacts_legacy_v3;
                """)
        }
        if !columnExists(table: "conversations", column: "local_identity_id") {
            try execute("ALTER TABLE conversations ADD COLUMN local_identity_id TEXT NOT NULL DEFAULT '';")
            try execute("""
                UPDATE conversations
                SET local_identity_id = COALESCE(
                    (SELECT sender_identity_id FROM messages WHERE conversation_id = conversations.id AND is_outgoing = 1 ORDER BY sent_at ASC LIMIT 1),
                    (SELECT id FROM profiles ORDER BY is_primary DESC, created_at ASC LIMIT 1),
                    ''
                )
                WHERE local_identity_id = '';
                """)
        }
        if !columnExists(table: "outbound_queue", column: "local_identity_id") {
            try execute("ALTER TABLE outbound_queue ADD COLUMN local_identity_id TEXT NOT NULL DEFAULT '';")
            try execute("""
                UPDATE outbound_queue
                SET local_identity_id = COALESCE((SELECT sender_identity_id FROM messages WHERE id = outbound_queue.message_id AND is_outgoing = 1 LIMIT 1), '')
                WHERE local_identity_id = '';
                """)
        }
        try execute("CREATE INDEX IF NOT EXISTS idx_contacts_local ON contacts(local_identity_id, trust_state);")
        try execute("CREATE INDEX IF NOT EXISTS idx_conversations_updated_v4 ON conversations(local_identity_id, updated_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS idx_conversations_peer_v4 ON conversations(local_identity_id, peer_identity_id);")
        try execute("CREATE INDEX IF NOT EXISTS idx_outbound_due_v4 ON outbound_queue(local_identity_id, target_identity_id, next_attempt_at);")
    }

    private func columnExists(table: String, column: String) -> Bool {
        read("PRAGMA table_info(\(table));") { text($0, 1) }.contains(column)
    }

    private func sqlLiteral(_ value: String) -> String { value.replacingOccurrences(of: "'", with: "''") }

    private func transaction(_ sql: String) throws {
        try queue.sync {
            guard let db else { throw DatabaseError.openFailed("数据库尚未打开。") }
            var error: UnsafeMutablePointer<Int8>?
            let wrapped = "BEGIN IMMEDIATE;\n\(sql)\nCOMMIT;"
            guard sqlite3_exec(db, wrapped, nil, nil, &error) == SQLITE_OK else {
                let message = error.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(db))
                sqlite3_free(error)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw DatabaseError.statementFailed(message)
            }
        }
    }

    private func execute(_ sql: String) throws {
        try queue.sync {
            guard let db else { throw DatabaseError.openFailed("数据库尚未打开。") }
            var error: UnsafeMutablePointer<Int8>?
            guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
                let message = error.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(db))
                sqlite3_free(error)
                throw DatabaseError.statementFailed(message)
            }
        }
    }

    private func writeBatch(_ statements: [(String, [SQLiteValue])]) throws {
        try queue.sync {
            guard let db else { throw DatabaseError.openFailed("数据库尚未打开。") }
            guard sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil) == SQLITE_OK else {
                throw DatabaseError.statementFailed(String(cString: sqlite3_errmsg(db)))
            }
            do {
                for (sql, bindings) in statements {
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
                          let statement else {
                        throw DatabaseError.statementFailed(String(cString: sqlite3_errmsg(db)))
                    }
                    defer { sqlite3_finalize(statement) }
                    bind(bindings, to: statement)
                    guard sqlite3_step(statement) == SQLITE_DONE else {
                        throw DatabaseError.statementFailed(String(cString: sqlite3_errmsg(db)))
                    }
                }
                guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
                    throw DatabaseError.statementFailed(String(cString: sqlite3_errmsg(db)))
                }
            } catch {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }

    private func write(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try queue.sync {
            guard let db else { throw DatabaseError.openFailed("数据库尚未打开。") }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement else {
                throw DatabaseError.statementFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(statement) }
            bind(bindings, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.statementFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    private func read<T>(
        _ sql: String,
        bindings: [SQLiteValue] = [],
        transform: (OpaquePointer) -> T
    ) -> [T] {
        queue.sync {
            guard let db else { return [] }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement else { return [] }
            defer { sqlite3_finalize(statement) }
            bind(bindings, to: statement)
            var results: [T] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(transform(statement))
            }
            return results
        }
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer) {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .text(let value):
                value.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
            case .blob(let value):
                value.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), transient)
                }
            case .double(let value): sqlite3_bind_double(statement, index, value)
            case .int(let value): sqlite3_bind_int64(statement, index, sqlite3_int64(value))
            case .null: sqlite3_bind_null(statement, index)
            }
        }
    }

    private func text(_ statement: OpaquePointer, _ column: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: pointer)
    }

    private func data(_ statement: OpaquePointer, _ column: Int32) -> Data {
        guard let bytes = sqlite3_column_blob(statement, column) else { return Data() }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
    }
}

private enum SQLiteValue {
    case text(String)
    case blob(Data)
    case double(Double)
    case int(Int)
    case null
}
