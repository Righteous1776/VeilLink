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

}
