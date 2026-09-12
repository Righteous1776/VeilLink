import CryptoKit
import XCTest
@testable import VeilLink

final class DatabaseStoreTests: XCTestCase {
    private func makeStore() throws -> (DatabaseStore, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VeilLink-DBTests-\(UUID().uuidString)", isDirectory: true)
        return (try DatabaseStore(keychain: KeychainStore(service: "studio.zeo.veillink.tests.db.\(UUID().uuidString)"), rootDirectory: root), root)
    }

    func testOutboundQueueAndPeerScopedAcknowledgement() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-a"; let peer = "peer-a"; try store.trustPeer(localIdentityID: local, identityID: peer, displayName: "Peer A", publicKey: Data(repeating: 1, count: 32))
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer A")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "queued", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message); try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertEqual(store.dueOutboundMessageIDs(for: peer, localIdentityID: local), [message.id])
        try store.markDelivered(messageID: message.id, from: "different-peer", localIdentityID: local); XCTAssertEqual(store.fetchMessage(id: message.id)?.deliveryState, .queued)
        try store.markDelivered(messageID: message.id, from: peer, localIdentityID: local); XCTAssertEqual(store.fetchMessage(id: message.id)?.deliveryState, .delivered)
        try store.completeOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local); XCTAssertTrue(store.dueOutboundMessageIDs(for: peer, localIdentityID: local).isEmpty)
    }

    func testAttachmentRoundTripUsesEncryptedFile() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let conversation = try store.createConversation(localIdentityID: "local-attachment", peerIdentityID: "peer", title: "Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: "local", body: "[图片]", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message); let clear = Data(repeating: 0x42, count: 4_096)
        let attachment = try store.saveAttachment(messageID: message.id, data: clear, mimeType: "image/jpeg")
        XCTAssertEqual(store.loadAttachment(id: attachment.id), clear)
        let files = try FileManager.default.contentsOfDirectory(at: store.attachmentsURL, includingPropertiesForKeys: nil)
        XCTAssertNotEqual(try Data(contentsOf: XCTUnwrap(files.first)), clear)
    }

    func testOutboundQueueIsIdempotentAndCountedOnce() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-b"
        let peer = "peer-b"
        try store.trustPeer(localIdentityID: local, identityID: peer, displayName: "Peer B", publicKey: Data(repeating: 2, count: 32))
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer B")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: "local", body: "once", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertEqual(store.pendingOutboundCount(localIdentityID: local), 1)
        XCTAssertEqual(store.dueOutboundMessageIDs(for: peer, localIdentityID: local), [message.id])
    }

    func testIdentityScopedTrustConversationAndOutboxIsolation() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let localA = "local-A"
        let localB = "local-B"
        let peer = "shared-peer"
        try store.trustPeer(localIdentityID: localA, identityID: peer, displayName: "Peer for A", publicKey: Data(repeating: 3, count: 32))
        XCTAssertNotNil(store.trustedContact(localIdentityID: localA, identityID: peer))
        XCTAssertNil(store.trustedContact(localIdentityID: localB, identityID: peer))

        let conversationA = try store.createConversation(localIdentityID: localA, peerIdentityID: peer, title: "A ↔ Peer")
        let conversationB = try store.createConversation(localIdentityID: localB, peerIdentityID: peer, title: "B ↔ Peer")
        XCTAssertNotEqual(conversationA, conversationB)
        XCTAssertEqual(store.fetchConversations(localIdentityID: localA).map(\.id), [conversationA])
        XCTAssertEqual(store.fetchConversations(localIdentityID: localB).map(\.id), [conversationB])

        let message = ChatMessage(id: UUID().uuidString, conversationID: conversationA, senderIdentityID: localA, body: "A only", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: localA)
        XCTAssertEqual(store.pendingOutboundCount(localIdentityID: localA), 1)
        XCTAssertEqual(store.pendingOutboundCount(localIdentityID: localB), 0)
        XCTAssertEqual(store.dueOutboundMessageIDs(for: peer, localIdentityID: localA), [message.id])
        XCTAssertTrue(store.dueOutboundMessageIDs(for: peer, localIdentityID: localB).isEmpty)
    }

    func testTemporaryDeferralDoesNotConsumeAcknowledgementRetryBudget() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-retry"
        let peer = "peer-retry"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Retry Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "retry", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)

        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 0)
        try store.deferOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local, delay: 1)
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 0)

        try store.recordAcceptedOutboundAttempt(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 1)
    }

    func testFailureReasonPersistsAndManualRestartClearsRetryBudget() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-failure"
        let peer = "peer-failure"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Failure Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "failure", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.recordAcceptedOutboundAttempt(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.updateDelivery(messageID: message.id, state: .failed, error: "ACK timeout")

        XCTAssertEqual(store.fetchMessage(id: message.id)?.deliveryState, .failed)
        XCTAssertEqual(store.fetchMessage(id: message.id)?.failureReason, "ACK timeout")
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 1)

        try store.restartOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.updateDelivery(messageID: message.id, state: .queued)
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 0)
        XCTAssertNil(store.fetchMessage(id: message.id)?.failureReason)
    }

    func testOutboundQueueSurvivesDatabaseReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VeilLink-ReopenTests-\(UUID().uuidString)", isDirectory: true)
        let service = "studio.zeo.veillink.tests.reopen.\(UUID().uuidString)"
        let keychain = KeychainStore(service: service)
        defer {
            keychain.remove("storage.database.key")
            try? FileManager.default.removeItem(at: root)
        }
        let local = "local-reopen"
        let peer = "peer-reopen"
        var messageID = ""
        do {
            let store = try DatabaseStore(keychain: keychain, rootDirectory: root)
            let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Reopen Peer")
            let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "persist", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
            messageID = message.id
            try store.saveMessage(message)
            try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
            XCTAssertEqual(store.pendingOutboundCount(localIdentityID: local), 1)
        }
        do {
            let reopened = try DatabaseStore(keychain: keychain, rootDirectory: root)
            XCTAssertEqual(reopened.pendingOutboundCount(localIdentityID: local), 1)
            XCTAssertEqual(reopened.fetchMessage(id: messageID)?.deliveryState, .queued)
        }
    }

    func testOutboundAttachmentCheckpointResetsRetryBudgetAndTracksConfirmedProgress() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-progress"; let peer = "peer-progress"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Progress Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "[图片]", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.configureOutboundAttachment(messageID: message.id, chunkCount: 4)
        try store.recordAcceptedOutboundAttempt(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 1)

        try store.acceptOutboundAttachmentCheckpoint(messageID: message.id, targetIdentityID: peer, localIdentityID: local, nextChunk: 2, chunkCount: 4)
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 0)
        XCTAssertEqual(store.outboundAttachmentState(messageID: message.id, targetIdentityID: peer, localIdentityID: local), .init(nextChunk: 2, chunkCount: 4))
        XCTAssertEqual(try XCTUnwrap(store.fetchMessage(id: message.id)?.transferProgress), 0.5, accuracy: 0.0001)
    }

    func testInboundAttachmentCheckpointSurvivesReopenAndResumesWithoutRestarting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VeilLink-AttachmentResume-\(UUID().uuidString)", isDirectory: true)
        let keychain = KeychainStore(service: "studio.zeo.veillink.tests.resume.\(UUID().uuidString)")
        defer { keychain.remove("storage.database.key"); try? FileManager.default.removeItem(at: root) }
        let messageID = UUID().uuidString
        let clear = Data((0..<120_000).map { UInt8($0 % 251) })
        let digest = Data(SHA256.hash(data: clear))
        let chunks = [Data(clear[0..<40_000]), Data(clear[40_000..<80_000]), Data(clear[80_000..<120_000])]

        do {
            let store = try DatabaseStore(keychain: keychain, rootDirectory: root)
            let conversation = try store.createConversation(localIdentityID: "receiver", peerIdentityID: "sender", title: "Sender")
            try store.saveMessage(ChatMessage(id: messageID, conversationID: conversation, senderIdentityID: "sender", body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
            let started = try store.beginInboundAttachment(messageID: messageID, byteCount: clear.count, mimeType: "image/jpeg", sha256: digest, chunkCount: chunks.count)
            XCTAssertEqual(started.nextChunk, 0)
            let first = try store.storeInboundAttachmentChunk(messageID: messageID, index: 0, chunkCount: chunks.count, clearData: chunks[0])
            XCTAssertEqual(first.nextChunk, 1)
            XCTAssertEqual(try XCTUnwrap(store.fetchMessage(id: messageID)?.transferProgress), 1.0 / 3.0, accuracy: 0.0001)
        }

        do {
            let reopened = try DatabaseStore(keychain: keychain, rootDirectory: root)
            let resumed = try reopened.beginInboundAttachment(messageID: messageID, byteCount: clear.count, mimeType: "image/jpeg", sha256: digest, chunkCount: chunks.count)
            XCTAssertEqual(resumed.nextChunk, 1)
            _ = try reopened.storeInboundAttachmentChunk(messageID: messageID, index: 1, chunkCount: chunks.count, clearData: chunks[1])
            let finished = try reopened.storeInboundAttachmentChunk(messageID: messageID, index: 2, chunkCount: chunks.count, clearData: chunks[2])
            XCTAssertTrue(finished.completed)
            XCTAssertEqual(finished.nextChunk, chunks.count)
            let attachment = try XCTUnwrap(reopened.fetchMessage(id: messageID)?.attachment)
            XCTAssertEqual(reopened.loadAttachment(id: attachment.id), clear)
            XCTAssertEqual(try XCTUnwrap(reopened.fetchMessage(id: messageID)?.transferProgress), 1, accuracy: 0.0001)
        }
    }

    func testInboundAttachmentAcceptsHEICAndRejectsUntranscodedWebP() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let digest = Data(repeating: 7, count: 32)

        let heicID = UUID().uuidString
        let conversation = try store.createConversation(localIdentityID: "receiver-media", peerIdentityID: "sender-media", title: "Media")
        try store.saveMessage(ChatMessage(id: heicID, conversationID: conversation, senderIdentityID: "sender-media", body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
        XCTAssertNoThrow(try store.beginInboundAttachment(messageID: heicID, byteCount: 1_500_000, mimeType: "image/heic", sha256: digest, chunkCount: 31))

        let webpID = UUID().uuidString
        try store.saveMessage(ChatMessage(id: webpID, conversationID: conversation, senderIdentityID: "sender-media", body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
        XCTAssertThrowsError(try store.beginInboundAttachment(messageID: webpID, byteCount: 500_000, mimeType: "image/webp", sha256: digest, chunkCount: 11))
    }

    func testInboundAttachmentDuplicateChunkIsIdempotentButConflictIsRejected() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let messageID = UUID().uuidString
        let clear = Data(repeating: 0x31, count: 100)
        let digest = Data(SHA256.hash(data: clear))
        let conversation = try store.createConversation(localIdentityID: "receiver", peerIdentityID: "sender", title: "Sender")
        try store.saveMessage(ChatMessage(id: messageID, conversationID: conversation, senderIdentityID: "sender", body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
        _ = try store.beginInboundAttachment(messageID: messageID, byteCount: clear.count, mimeType: "image/jpeg", sha256: digest, chunkCount: 2)
        let half = Data(clear.prefix(50))
        XCTAssertEqual(try store.storeInboundAttachmentChunk(messageID: messageID, index: 0, chunkCount: 2, clearData: half).nextChunk, 1)
        XCTAssertEqual(try store.storeInboundAttachmentChunk(messageID: messageID, index: 0, chunkCount: 2, clearData: half).nextChunk, 1)
        XCTAssertThrowsError(try store.storeInboundAttachmentChunk(messageID: messageID, index: 0, chunkCount: 2, clearData: Data(repeating: 0x99, count: 50)))
    }

    func testStaleInboundAttachmentCleanupResetsCheckpointAndFreesTransferSlot() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let messageID = UUID().uuidString
        let sender = "sender-stale"
        let conversation = try store.createConversation(localIdentityID: "receiver-stale", peerIdentityID: sender, title: "Sender")
        let clear = Data(repeating: 0x41, count: 96_000)
        let digest = Data(SHA256.hash(data: clear))
        try store.saveMessage(ChatMessage(id: messageID, conversationID: conversation, senderIdentityID: sender, body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
        _ = try store.beginInboundAttachment(messageID: messageID, byteCount: clear.count, mimeType: "image/jpeg", sha256: digest, chunkCount: 2)
        _ = try store.storeInboundAttachmentChunk(messageID: messageID, index: 0, chunkCount: 2, clearData: Data(clear.prefix(48_000)))
        XCTAssertEqual(try XCTUnwrap(store.fetchMessage(id: messageID)?.transferProgress), 0.5, accuracy: 0.0001)

        let removed = try store.cleanupStaleInboundAttachments(now: Date().addingTimeInterval(DatabaseStore.inboundAttachmentRetention + 60))
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(try XCTUnwrap(store.fetchMessage(id: messageID)?.transferProgress), 0, accuracy: 0.0001)

        let restarted = try store.beginInboundAttachment(messageID: messageID, byteCount: clear.count, mimeType: "image/jpeg", sha256: digest, chunkCount: 2)
        XCTAssertEqual(restarted.nextChunk, 0)
    }

    func testInboundAttachmentPerSenderLimitDoesNotBlockDifferentSender() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let receiver = "receiver-limit"
        let senderA = "sender-A"
        let senderB = "sender-B"
        let conversationA = try store.createConversation(localIdentityID: receiver, peerIdentityID: senderA, title: "A")
        let conversationB = try store.createConversation(localIdentityID: receiver, peerIdentityID: senderB, title: "B")
        let digest = Data(repeating: 0x22, count: 32)

        for index in 0..<DatabaseStore.maximumIncompleteInboundAttachmentsPerSender {
            let id = UUID().uuidString
            try store.saveMessage(ChatMessage(id: id, conversationID: conversationA, senderIdentityID: senderA, body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
            XCTAssertNoThrow(try store.beginInboundAttachment(messageID: id, byteCount: 1_000, mimeType: "image/jpeg", sha256: digest, chunkCount: 1), "slot \(index)")
        }

        let blockedID = UUID().uuidString
        try store.saveMessage(ChatMessage(id: blockedID, conversationID: conversationA, senderIdentityID: senderA, body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
        XCTAssertThrowsError(try store.beginInboundAttachment(messageID: blockedID, byteCount: 1_000, mimeType: "image/jpeg", sha256: digest, chunkCount: 1))

        let otherID = UUID().uuidString
        try store.saveMessage(ChatMessage(id: otherID, conversationID: conversationB, senderIdentityID: senderB, body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))
        XCTAssertNoThrow(try store.beginInboundAttachment(messageID: otherID, byteCount: 1_000, mimeType: "image/jpeg", sha256: digest, chunkCount: 1))
    }

    func testCompletedInboundAttachmentDuplicateManifestStaysCompletedWithoutTemporaryState() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let messageID = UUID().uuidString
        let conversation = try store.createConversation(localIdentityID: "local-complete", peerIdentityID: "peer-complete", title: "Peer")
        try store.saveMessage(ChatMessage(id: messageID, conversationID: conversation, senderIdentityID: "peer-complete", body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))

        let clear = Data((0..<80_000).map { UInt8($0 % 251) })
        let digest = Data(SHA256.hash(data: clear))
        let chunks = [Data(clear.prefix(48 * 1_024)), Data(clear.dropFirst(48 * 1_024))]
        _ = try store.beginInboundAttachment(messageID: messageID, byteCount: clear.count, mimeType: "image/jpeg", sha256: digest, chunkCount: chunks.count)
        _ = try store.storeInboundAttachmentChunk(messageID: messageID, index: 0, chunkCount: chunks.count, clearData: chunks[0])
        let finished = try store.storeInboundAttachmentChunk(messageID: messageID, index: 1, chunkCount: chunks.count, clearData: chunks[1])
        XCTAssertTrue(finished.completed)
        XCTAssertEqual(finished.nextChunk, chunks.count)
        XCTAssertEqual(try store.cleanupCompletedInboundTransferMetadata(), 0)

        let duplicate = try store.beginInboundAttachment(messageID: messageID, byteCount: clear.count, mimeType: "image/jpeg", sha256: digest, chunkCount: chunks.count)
        XCTAssertTrue(duplicate.completed)
        XCTAssertEqual(duplicate.nextChunk, chunks.count)
        XCTAssertEqual(store.fetchMessage(id: messageID)?.transferProgress, 1)
    }

    func testAttachmentProgressPersistenceIsQuantizedWhileCheckpointRemainsExact() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let messageID = UUID().uuidString
        let conversation = try store.createConversation(localIdentityID: "local-progress", peerIdentityID: "peer-progress", title: "Peer")
        try store.saveMessage(ChatMessage(id: messageID, conversationID: conversation, senderIdentityID: "peer-progress", body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0))

        let chunkCount = 64
        let digest = Data(repeating: 0xAB, count: 32)
        _ = try store.beginInboundAttachment(messageID: messageID, byteCount: 64_000, mimeType: "image/jpeg", sha256: digest, chunkCount: chunkCount)
        let first = try store.storeInboundAttachmentChunk(messageID: messageID, index: 0, chunkCount: chunkCount, clearData: Data(repeating: 1, count: 1_000))
        XCTAssertEqual(first.nextChunk, 1)
        XCTAssertEqual(store.fetchMessage(id: messageID)?.transferProgress, 0)
        let second = try store.storeInboundAttachmentChunk(messageID: messageID, index: 1, chunkCount: chunkCount, clearData: Data(repeating: 2, count: 1_000))
        XCTAssertEqual(second.nextChunk, 2)
        XCTAssertEqual(store.fetchMessage(id: messageID)?.transferProgress ?? -1, 2.0 / 64.0, accuracy: 0.000_001)
    }

    func testSaveMessageUpdatesConversationPreviewInSameCommitPath() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-preview"
        let peer = "peer-preview"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Preview Peer")
        let sentAt = Date()
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "atomic preview", sentAt: sentAt, isOutgoing: true, deliveryState: .queued)

        try store.saveMessage(message)

        let summary = try XCTUnwrap(store.fetchConversations(localIdentityID: local).first)
        XCTAssertEqual(summary.lastMessage, "atomic preview")
        XCTAssertEqual(summary.id, conversation)
        XCTAssertNotNil(store.fetchMessage(id: message.id))
    }

    func testAttachmentInsertFailureRemovesEncryptedOrphanFile() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try store.saveAttachment(messageID: UUID().uuidString, data: Data(repeating: 0x5A, count: 512), mimeType: "image/jpeg"))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(at: store.attachmentsURL, includingPropertiesForKeys: nil).isEmpty)
    }

    func testContactAliasUpdatesTrustedContactAndConversationTitle() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-alias"
        let peer = "peer-alias"
        try store.trustPeer(localIdentityID: local, identityID: peer, displayName: "Original", publicKey: Data(repeating: 0x31, count: 32))
        _ = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Original")

        try store.renameContact(localIdentityID: local, identityID: peer, displayName: "Roommate")

        XCTAssertEqual(store.trustedContact(localIdentityID: local, identityID: peer)?.displayName, "Roommate")
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.title, "Roommate")
    }

    func testDeleteLocalIdentityDataRemovesScopedRowsAndAttachmentFiles() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-delete"
        let peer = "peer-delete"
        try store.trustPeer(localIdentityID: local, identityID: peer, displayName: "Peer", publicKey: Data(repeating: 0x41, count: 32))
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "[图片]", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message)
        let attachment = try store.saveAttachment(messageID: message.id, data: Data(repeating: 0x52, count: 1024), mimeType: "image/jpeg")
        XCTAssertNotNil(store.loadAttachment(id: attachment.id))

        try store.deleteLocalIdentityData(localIdentityID: local)

        XCTAssertTrue(store.fetchConversations(localIdentityID: local).isEmpty)
        XCTAssertNil(store.trustedContact(localIdentityID: local, identityID: peer))
        XCTAssertNil(store.fetchMessage(id: message.id))
        XCTAssertNil(store.loadAttachment(id: attachment.id))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(at: store.attachmentsURL, includingPropertiesForKeys: nil).isEmpty)
    }

    func testPausedAttachmentIsExcludedFromDueQueueAndResumeKeepsCheckpoint() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-pause"
        let peer = "peer-pause"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Pause Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "[图片]", sentAt: Date(), isOutgoing: true, deliveryState: .queued, transferProgress: 0)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.configureOutboundAttachment(messageID: message.id, chunkCount: 5)
        try store.acceptOutboundAttachmentCheckpoint(messageID: message.id, targetIdentityID: peer, localIdentityID: local, nextChunk: 2, chunkCount: 5)

        try store.pauseOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertTrue(store.isOutboundPaused(messageID: message.id, targetIdentityID: peer, localIdentityID: local))
        XCTAssertEqual(store.fetchMessage(id: message.id)?.deliveryState, .paused)
        XCTAssertTrue(store.dueOutboundMessageIDs(for: peer, localIdentityID: local).isEmpty)
        XCTAssertEqual(store.outboundAttachmentState(messageID: message.id, targetIdentityID: peer, localIdentityID: local)?.nextChunk, 2)

        try store.resumeOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertFalse(store.isOutboundPaused(messageID: message.id, targetIdentityID: peer, localIdentityID: local))
        XCTAssertEqual(store.fetchMessage(id: message.id)?.deliveryState, .queued)
        XCTAssertEqual(store.dueOutboundMessageIDs(for: peer, localIdentityID: local), [message.id])
        XCTAssertEqual(store.outboundAttachmentState(messageID: message.id, targetIdentityID: peer, localIdentityID: local)?.nextChunk, 2)
    }

    func testPausedAttachmentSurvivesDatabaseReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VeilLink-PauseReopen-\(UUID().uuidString)", isDirectory: true)
        let service = "studio.zeo.veillink.tests.pause-reopen.\(UUID().uuidString)"
        let keychain = KeychainStore(service: service)
        defer { keychain.remove("storage.database.key"); try? FileManager.default.removeItem(at: root) }
        let local = "local-pause-reopen"
        let peer = "peer-pause-reopen"
        var messageID = ""
        do {
            let store = try DatabaseStore(keychain: keychain, rootDirectory: root)
            let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
            let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "[图片]", sentAt: Date(), isOutgoing: true, deliveryState: .queued, transferProgress: 0)
            messageID = message.id
            try store.saveMessage(message)
            try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
            try store.configureOutboundAttachment(messageID: message.id, chunkCount: 3)
            try store.pauseOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        }
        do {
            let reopened = try DatabaseStore(keychain: keychain, rootDirectory: root)
            XCTAssertTrue(reopened.isOutboundPaused(messageID: messageID, targetIdentityID: peer, localIdentityID: local))
            XCTAssertEqual(reopened.fetchMessage(id: messageID)?.deliveryState, .paused)
            XCTAssertTrue(reopened.dueOutboundMessageIDs(for: peer, localIdentityID: local).isEmpty)
        }
    }

    func testCancelAttachmentRemovesQueueButKeepsLocalMessageAndImage() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-cancel"
        let peer = "peer-cancel"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Cancel Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "[图片]", sentAt: Date(), isOutgoing: true, deliveryState: .queued, transferProgress: 0)
        try store.saveMessage(message)
        let attachment = try store.saveAttachment(messageID: message.id, data: Data(repeating: 0x66, count: 4096), mimeType: "image/jpeg")
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.configureOutboundAttachment(messageID: message.id, chunkCount: 2)

        try store.cancelOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)

        XCTAssertEqual(store.fetchMessage(id: message.id)?.deliveryState, .cancelled)
        XCTAssertTrue(store.dueOutboundMessageIDs(for: peer, localIdentityID: local).isEmpty)
        XCTAssertNil(store.outboundAttachmentState(messageID: message.id, targetIdentityID: peer, localIdentityID: local))
        XCTAssertEqual(store.loadAttachment(id: attachment.id), Data(repeating: 0x66, count: 4096))
    }

    func testLocalMessageDeleteRepairsPreviewAndRemovesAttachmentFile() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-delete-message"
        let peer = "peer-delete-message"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let first = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "first", sentAt: Date(timeIntervalSince1970: 100), isOutgoing: true, deliveryState: .delivered)
        let second = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "[图片]", sentAt: Date(timeIntervalSince1970: 200), isOutgoing: true, deliveryState: .delivered, transferProgress: 1)
        try store.saveMessage(first)
        try store.saveMessage(second)
        let attachment = try store.saveAttachment(messageID: second.id, data: Data(repeating: 0x77, count: 1024), mimeType: "image/jpeg")
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.lastMessage, "[图片]")

        try store.deleteMessageLocally(messageID: second.id, conversationID: conversation)

        XCTAssertNil(store.fetchMessage(id: second.id))
        XCTAssertNil(store.loadAttachment(id: attachment.id))
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.lastMessage, "first")
        XCTAssertEqual(store.fetchMessages(conversationID: conversation).map(\.id), [first.id])
    }

    func testClearConversationDeletesLocalHistoryButKeepsContactAndConversation() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-clear"
        let peer = "peer-clear"
        try store.trustPeer(localIdentityID: local, identityID: peer, displayName: "Peer", publicKey: Data(repeating: 0x21, count: 32))
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let text = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "text", sentAt: Date(), isOutgoing: true, deliveryState: .delivered)
        let image = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: peer, body: "[图片]", sentAt: Date().addingTimeInterval(1), isOutgoing: false, deliveryState: .delivered, transferProgress: 1)
        try store.saveMessage(text)
        try store.saveMessage(image)
        let attachment = try store.saveAttachment(messageID: image.id, data: Data(repeating: 0x22, count: 1024), mimeType: "image/png")

        try store.clearConversationLocally(conversationID: conversation)

        XCTAssertTrue(store.fetchMessages(conversationID: conversation).isEmpty)
        XCTAssertNil(store.loadAttachment(id: attachment.id))
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.id, conversation)
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.lastMessage, "")
        XCTAssertNotNil(store.trustedContact(localIdentityID: local, identityID: peer))
    }

    func testLocalDeleteCreatesSenderScopedTombstoneForIncomingMessage() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-tombstone"
        let peer = "peer-tombstone"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: peer, body: "hello", sentAt: Date(), isOutgoing: false, deliveryState: .delivered)
        try store.saveMessage(message)

        try store.deleteMessageLocally(messageID: message.id, conversationID: conversation)

        XCTAssertNil(store.fetchMessage(id: message.id))
        XCTAssertTrue(store.isLocallyDeletedMessage(messageID: message.id, senderIdentityID: peer))
        XCTAssertFalse(store.isLocallyDeletedMessage(messageID: message.id, senderIdentityID: "different-peer"))
    }

    func testIncompleteInboundImageBlocksLocalDeleteAndConversationClear() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-incomplete-delete"
        let peer = "peer-incomplete-delete"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: peer, body: "[图片]", sentAt: Date(), isOutgoing: false, deliveryState: .delivered, transferProgress: 0)
        try store.saveMessage(message)
        _ = try store.beginInboundAttachment(messageID: message.id, byteCount: 1000, mimeType: "image/jpeg", sha256: Data(repeating: 0x33, count: 32), chunkCount: 1)

        XCTAssertTrue(store.hasIncompleteInboundAttachments(conversationID: conversation))
        XCTAssertThrowsError(try store.deleteMessageLocally(messageID: message.id, conversationID: conversation))
        XCTAssertThrowsError(try store.clearConversationLocally(conversationID: conversation))
        XCTAssertNotNil(store.fetchMessage(id: message.id))
    }

    func testReplyConversationPreviewStaysCompactAfterSaveAndDelete() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-reply-preview"
        let peer = "peer-reply-preview"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let replyBody = ReplyTextCodec.encode(quoted: "很长的旧消息", reply: "新的回复")
        let first = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: replyBody, sentAt: Date(timeIntervalSince1970: 100), isOutgoing: true, deliveryState: .delivered)
        let second = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "后来一条", sentAt: Date(timeIntervalSince1970: 200), isOutgoing: true, deliveryState: .delivered)
        try store.saveMessage(first, conversationPreview: ReplyTextCodec.previewText(for: replyBody))
        try store.saveMessage(second)
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.lastMessage, "后来一条")

        try store.deleteMessageLocally(messageID: second.id, conversationID: conversation)
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.lastMessage, "↪︎ 新的回复")
    }

    func testIncomingMessageIncrementsUnreadAndReadResetClearsIt() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-unread"
        let peer = "peer-unread"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let incoming = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: peer, body: "hello", sentAt: Date(), isOutgoing: false, deliveryState: .delivered)
        try store.saveMessage(incoming)

        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.unreadCount, 1)
        try store.markConversationRead(conversationID: conversation)
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.unreadCount, 0)
    }

    func testOutgoingMessageDoesNotIncrementUnreadCount() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-outgoing-unread"
        let peer = "peer-outgoing-unread"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let outgoing = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "hello", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(outgoing)

        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.unreadCount, 0)
    }

    func testPinnedConversationSortsBeforeMoreRecentUnpinnedConversation() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-pin"
        let older = try store.createConversation(localIdentityID: local, peerIdentityID: "peer-old", title: "Old")
        let newer = try store.createConversation(localIdentityID: local, peerIdentityID: "peer-new", title: "New")
        let oldMessage = ChatMessage(id: UUID().uuidString, conversationID: older, senderIdentityID: local, body: "old", sentAt: Date(timeIntervalSince1970: 100), isOutgoing: true, deliveryState: .delivered)
        let newMessage = ChatMessage(id: UUID().uuidString, conversationID: newer, senderIdentityID: local, body: "new", sentAt: Date(timeIntervalSince1970: 200), isOutgoing: true, deliveryState: .delivered)
        try store.saveMessage(oldMessage)
        try store.saveMessage(newMessage)
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.id, newer)

        try store.setConversationPinned(conversationID: older, pinned: true)
        let conversations = store.fetchConversations(localIdentityID: local)
        XCTAssertEqual(conversations.first?.id, older)
        XCTAssertTrue(conversations.first?.isPinned == true)
    }

    func testManualMarkUnreadCreatesAtLeastOneUnreadWithoutInflatingExistingCount() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-manual-unread"
        let peer = "peer-manual-unread"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")

        try store.markConversationUnread(conversationID: conversation)
        try store.markConversationUnread(conversationID: conversation)
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.unreadCount, 1)
    }

    func testDuplicateIncomingMessageDoesNotDoubleIncrementUnread() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-unread-idempotent"
        let peer = "peer-unread-idempotent"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let incoming = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: peer, body: "hello", sentAt: Date(), isOutgoing: false, deliveryState: .delivered)

        try store.saveMessage(incoming)
        try store.saveMessage(incoming)
        XCTAssertEqual(store.fetchConversations(localIdentityID: local).first?.unreadCount, 1)
    }

    func testPinnedConversationPersistsAcrossDatabaseReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VeilLink-PinReopen-\(UUID().uuidString)", isDirectory: true)
        let service = "studio.zeo.veillink.tests.pin-reopen.\(UUID().uuidString)"
        let keychain = KeychainStore(service: service)
        defer { keychain.remove("storage.database.key"); try? FileManager.default.removeItem(at: root) }
        let local = "local-pin-reopen"
        var conversationID = ""
        do {
            let store = try DatabaseStore(keychain: keychain, rootDirectory: root)
            conversationID = try store.createConversation(localIdentityID: local, peerIdentityID: "peer", title: "Peer")
            try store.setConversationPinned(conversationID: conversationID, pinned: true)
        }
        do {
            let reopened = try DatabaseStore(keychain: keychain, rootDirectory: root)
            let summary = try XCTUnwrap(reopened.fetchConversations(localIdentityID: local).first)
            XCTAssertEqual(summary.id, conversationID)
            XCTAssertTrue(summary.isPinned)
        }
    }

    func testAcceptedOutboundAttemptIncrementsRetryCountWithoutExtraReadPath() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-retry-opt"
        let peer = "peer-retry-opt"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "hello", sentAt: Date(), isOutgoing: true, deliveryState: .queued)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)

        try store.recordAcceptedOutboundAttempt(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 1)
        try store.recordAcceptedOutboundAttempt(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        XCTAssertEqual(store.outboundRetryCount(messageID: message.id, targetIdentityID: peer, localIdentityID: local), 2)
    }

    func testOutboundCheckpointReportsOnlyPersistedProgressStages() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let local = "local-progress-opt"
        let peer = "peer-progress-opt"
        let conversation = try store.createConversation(localIdentityID: local, peerIdentityID: peer, title: "Peer")
        let message = ChatMessage(id: UUID().uuidString, conversationID: conversation, senderIdentityID: local, body: "[图片]", sentAt: Date(), isOutgoing: true, deliveryState: .queued, transferProgress: 0)
        try store.saveMessage(message)
        try store.enqueueOutbound(messageID: message.id, targetIdentityID: peer, localIdentityID: local)
        try store.configureOutboundAttachment(messageID: message.id, chunkCount: 64)

        XCTAssertTrue(try store.acceptOutboundAttachmentCheckpoint(messageID: message.id, targetIdentityID: peer, localIdentityID: local, nextChunk: 0, chunkCount: 64))
        XCTAssertFalse(try store.acceptOutboundAttachmentCheckpoint(messageID: message.id, targetIdentityID: peer, localIdentityID: local, nextChunk: 1, chunkCount: 64))
        XCTAssertTrue(try store.acceptOutboundAttachmentCheckpoint(messageID: message.id, targetIdentityID: peer, localIdentityID: local, nextChunk: 2, chunkCount: 64))
    }

}
