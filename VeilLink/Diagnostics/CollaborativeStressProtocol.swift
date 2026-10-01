import CryptoKit
import Foundation

/// Ephemeral, diagnostics-only protocol layered on top of an already authenticated VeilLink
/// secure session. Frames are never intended to enter the normal conversations/messages store.
enum CollaborativeStressFrameKind: String, Codable, CaseIterable, Sendable {
    case invite
    case accept
    case decline
    case start
    case stop
    case ping
    case pong
    case textBurst
    case bulkBegin
    case bulkReady
    case bulkReceipt
    case gameReset
    case gamePacket
    case localComplete
}

enum CollaborativeStressPayloadKind: String, Codable, CaseIterable, Sendable {
    case syntheticImage
    case synthesizedVoice
}

struct CollaborativeStressScenario: Codable, Equatable, Sendable {
    var textBurstCount = 120
    var textPayloadBytes = 2_048
    var imageTransferCount = 2
    var imagePayloadBytes = 384 * 1_024
    var voiceTransferCount = 1
    var voicePayloadBytes = 128 * 1_024
    var gameMoveCount = 36
    var interFrameDelayMilliseconds = 18
    var enableText = true
    var enableImages = true
    var enableVoice = true
    var enableGame = true

    static let maximumTextPayloadBytes = 6 * 1_024
    static let maximumBulkPayloadBytes = 2 * 1_024 * 1_024

    var normalized: CollaborativeStressScenario {
        var value = self
        value.textBurstCount = min(2_000, max(0, value.textBurstCount))
        value.textPayloadBytes = min(Self.maximumTextPayloadBytes, max(128, value.textPayloadBytes))
        value.imageTransferCount = min(16, max(0, value.imageTransferCount))
        value.imagePayloadBytes = min(Self.maximumBulkPayloadBytes, max(16 * 1_024, value.imagePayloadBytes))
        value.voiceTransferCount = min(8, max(0, value.voiceTransferCount))
        value.voicePayloadBytes = min(512 * 1_024, max(16 * 1_024, value.voicePayloadBytes))
        value.gameMoveCount = min(240, max(0, value.gameMoveCount))
        value.interFrameDelayMilliseconds = min(1_000, max(8, value.interFrameDelayMilliseconds))
        return value
    }
}

struct CollaborativeStressFrame: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let sessionID: String
    let epoch: UInt64
    let ordinal: UInt64
    let kind: CollaborativeStressFrameKind
    let sentAt: Date
    let scenario: CollaborativeStressScenario?
    let payloadText: String?
    let payloadKind: CollaborativeStressPayloadKind?
    let transferID: String?
    let wireMessageID: String?
    let byteCount: Int?
    let chunkCount: Int?
    let sha256Hex: String?
    let gameWire: String?
    let success: Bool?
    let metadata: [String: String]

    init(
        sessionID: String,
        epoch: UInt64,
        ordinal: UInt64,
        kind: CollaborativeStressFrameKind,
        scenario: CollaborativeStressScenario? = nil,
        payloadText: String? = nil,
        payloadKind: CollaborativeStressPayloadKind? = nil,
        transferID: String? = nil,
        wireMessageID: String? = nil,
        byteCount: Int? = nil,
        chunkCount: Int? = nil,
        sha256Hex: String? = nil,
        gameWire: String? = nil,
        success: Bool? = nil,
        metadata: [String: String] = [:],
        sentAt: Date = Date()
    ) {
        version = Self.currentVersion
        self.sessionID = sessionID
        self.epoch = epoch
        self.ordinal = ordinal
        self.kind = kind
        self.sentAt = sentAt
        self.scenario = scenario
        self.payloadText = payloadText
        self.payloadKind = payloadKind
        self.transferID = transferID
        self.wireMessageID = wireMessageID
        self.byteCount = byteCount
        self.chunkCount = chunkCount
        self.sha256Hex = sha256Hex
        self.gameWire = gameWire
        self.success = success
        self.metadata = metadata
    }
}

enum CollaborativeStressCodec {
    static let prefix = "\u{2063}VLSTRESS1:"
    static let maximumEncodedTextBytes = 15_500
    static let bulkChunkBytes = 32 * 1_024

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    static func encode(_ frame: CollaborativeStressFrame) throws -> String {
        try validate(frame)
        let payload = try encoder.encode(frame).base64EncodedString()
        let text = prefix + payload
        guard text.lengthOfBytes(using: .utf8) <= maximumEncodedTextBytes else {
            throw CollaborativeStressError.frameTooLarge
        }
        return text
    }

    static func decode(_ text: String) -> CollaborativeStressFrame? {
        guard text.hasPrefix(prefix) else { return nil }
        let base64 = String(text.dropFirst(prefix.count))
        guard let data = Data(base64Encoded: base64),
              let frame = try? decoder.decode(CollaborativeStressFrame.self, from: data),
              (try? validate(frame)) != nil else { return nil }
        return frame
    }

    static func validate(_ frame: CollaborativeStressFrame) throws {
        guard frame.version == CollaborativeStressFrame.currentVersion,
              UUID(uuidString: frame.sessionID) != nil,
              frame.epoch > 0,
              frame.ordinal > 0,
              frame.metadata.count <= 24 else {
            throw CollaborativeStressError.invalidFrame
        }
        if let payloadText = frame.payloadText,
           payloadText.lengthOfBytes(using: .utf8) > CollaborativeStressScenario.maximumTextPayloadBytes {
            throw CollaborativeStressError.frameTooLarge
        }
        if frame.kind == .bulkBegin {
            guard let transferID = frame.transferID,
                  UUID(uuidString: transferID) != nil,
                  let wireMessageID = frame.wireMessageID,
                  UUID(uuidString: wireMessageID) != nil,
                  let byteCount = frame.byteCount,
                  byteCount > 0,
                  byteCount <= CollaborativeStressScenario.maximumBulkPayloadBytes,
                  let chunkCount = frame.chunkCount,
                  chunkCount == max(1, Int(ceil(Double(byteCount) / Double(bulkChunkBytes)))),
                  let digest = frame.sha256Hex,
                  digest.count == 64,
                  frame.payloadKind != nil else {
                throw CollaborativeStressError.invalidFrame
            }
        }
        if frame.kind == .bulkReady {
            guard let transferID = frame.transferID,
                  UUID(uuidString: transferID) != nil,
                  let wireMessageID = frame.wireMessageID,
                  UUID(uuidString: wireMessageID) != nil else {
                throw CollaborativeStressError.invalidFrame
            }
        }
    }
}

struct CollaborativeStressBulkReceipt: Codable, Equatable, Sendable {
    let sessionID: String
    let epoch: UInt64
    let transferID: String
    let wireMessageID: String
    let payloadKind: CollaborativeStressPayloadKind
    let byteCount: Int
    let chunkCount: Int
    let expectedSHA256: String
    let actualSHA256: String
    let success: Bool
    let durationMilliseconds: Int
}

final class CollaborativeStressInboundBulkAccumulator {
    let beginFrame: CollaborativeStressFrame
    private(set) var nextIndex = 0
    private(set) var data = Data()
    private let startedUptime = ProcessInfo.processInfo.systemUptime

    init(frame: CollaborativeStressFrame) throws {
        try CollaborativeStressCodec.validate(frame)
        guard frame.kind == .bulkBegin else { throw CollaborativeStressError.invalidFrame }
        beginFrame = frame
        data.reserveCapacity(frame.byteCount ?? 0)
    }

    func accept(index: Int, total: Int, bytes: Data) throws -> CollaborativeStressBulkReceipt? {
        guard let expectedCount = beginFrame.chunkCount,
              let expectedBytes = beginFrame.byteCount,
              total == expectedCount,
              index == nextIndex,
              index < total,
              !bytes.isEmpty,
              bytes.count <= CollaborativeStressCodec.bulkChunkBytes,
              data.count + bytes.count <= expectedBytes else {
            throw CollaborativeStressError.bulkSequenceMismatch
        }
        data.append(bytes)
        nextIndex += 1
        guard nextIndex == expectedCount else { return nil }
        guard data.count == expectedBytes,
              let transferID = beginFrame.transferID,
              let wireMessageID = beginFrame.wireMessageID,
              let payloadKind = beginFrame.payloadKind,
              let expectedSHA = beginFrame.sha256Hex else {
            throw CollaborativeStressError.bulkSequenceMismatch
        }
        let actual = CollaborativeStressPayloadFactory.sha256Hex(data)
        return CollaborativeStressBulkReceipt(
            sessionID: beginFrame.sessionID,
            epoch: beginFrame.epoch,
            transferID: transferID,
            wireMessageID: wireMessageID,
            payloadKind: payloadKind,
            byteCount: data.count,
            chunkCount: expectedCount,
            expectedSHA256: expectedSHA,
            actualSHA256: actual,
            success: actual == expectedSHA,
            durationMilliseconds: max(0, Int((ProcessInfo.processInfo.systemUptime - startedUptime) * 1_000))
        )
    }
}

enum CollaborativeStressPayloadFactory {
    static func text(bytes: Int, seed: UInt64) -> String {
        let count = max(1, bytes)
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)
        var state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        var output = [UInt8]()
        output.reserveCapacity(count)
        for _ in 0..<count {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            output.append(alphabet[Int(state % UInt64(alphabet.count))])
        }
        return String(bytes: output, encoding: .utf8) ?? "stress"
    }

    static func binary(bytes: Int, seed: UInt64) -> Data {
        let count = max(1, bytes)
        var state = seed == 0 ? 0xD1B54A32D192ED03 : seed
        var output = Data(capacity: count)
        for _ in 0..<count {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            output.append(UInt8(truncatingIfNeeded: state))
        }
        return output
    }

    static func syntheticVoiceWAV(bytes: Int, seed: UInt64) -> Data {
        let total = max(44 + 2_048, bytes)
        let payloadBytes = max(2_048, total - 44) & ~1
        let sampleRate: UInt32 = 16_000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * bitsPerSample / 8

        func le16(_ value: UInt16) -> [UInt8] {
            [UInt8(value & 0xff), UInt8((value >> 8) & 0xff)]
        }
        func le32(_ value: UInt32) -> [UInt8] {
            [
                UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
                UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)
            ]
        }

        var output = Data()
        output.append(contentsOf: Array("RIFF".utf8))
        output.append(contentsOf: le32(UInt32(36 + payloadBytes)))
        output.append(contentsOf: Array("WAVEfmt ".utf8))
        output.append(contentsOf: le32(16))
        output.append(contentsOf: le16(1))
        output.append(contentsOf: le16(channels))
        output.append(contentsOf: le32(sampleRate))
        output.append(contentsOf: le32(byteRate))
        output.append(contentsOf: le16(blockAlign))
        output.append(contentsOf: le16(bitsPerSample))
        output.append(contentsOf: Array("data".utf8))
        output.append(contentsOf: le32(UInt32(payloadBytes)))

        var state = seed == 0 ? 0xA0761D6478BD642F : seed
        let sampleCount = payloadBytes / 2
        for sampleIndex in 0..<sampleCount {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            let carrier = Int32((sampleIndex * 997) % 32_000) - 16_000
            let noise = Int32(Int16(bitPattern: UInt16(truncatingIfNeeded: state))) / 8
            let mixed = max(Int32(Int16.min), min(Int32(Int16.max), carrier + noise))
            let sample = UInt16(bitPattern: Int16(mixed))
            output.append(contentsOf: le16(sample))
        }
        return output
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum CollaborativeStressError: LocalizedError, Equatable {
    case invalidFrame
    case frameTooLarge
    case bulkSequenceMismatch
    case noSecurePeer
    case transportBackpressure
    case sessionMismatch

    var errorDescription: String? {
        switch self {
        case .invalidFrame: return "协同压力测试帧无效。"
        case .frameTooLarge: return "协同压力测试帧超过临时通道上限。"
        case .bulkSequenceMismatch: return "协同压力测试 bulk 分块顺序或摘要不一致。"
        case .noSecurePeer: return "目标设备没有可用的安全会话。"
        case .transportBackpressure: return "临时压力通道持续处于发送背压。"
        case .sessionMismatch: return "协同压力测试会话不匹配。"
        }
    }
}
