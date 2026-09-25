import Foundation

enum WireKind: UInt8 {
    case hello = 1
    case encryptedMessage = 2
    case acknowledgement = 3
    case attachmentChunk = 4
    case attachmentCheckpoint = 5
    case pttControl = 6
    case pttAudio = 7
    case meshOverlay = 8
    case relayProvision = 9
}

struct WireEnvelope {
    let version: UInt8
    let kind: WireKind
    let payload: Data
}

struct WireAttachmentChunk: Equatable {
    let index: UInt16
    let total: UInt16
    let bytes: Data
}

struct WireAttachmentCheckpoint: Equatable {
    let nextIndex: UInt16
    let total: UInt16
}

enum WireCodecError: Error {
    case invalidEnvelope
    case invalidEncryptedPayload
    case invalidAttachmentChunk
    case invalidAttachmentCheckpoint
}

enum WireCodec {
    static let envelopeHeaderSize = 8
    static let encryptedPayloadHeaderSize = 25
    static let attachmentChunkHeaderSize = 5
    static let attachmentCheckpointSize = 5
    private static let envelopeMagic: [UInt8] = [0x56, 0x4C] // "VL"
    private static let encryptedPayloadVersion: UInt8 = 1
    private static let attachmentPayloadVersion: UInt8 = 1

    static func encodeEnvelope(version: UInt8, kind: WireKind, payload: Data) throws -> Data {
        guard payload.count <= Int(UInt32.max) else { throw WireCodecError.invalidEnvelope }
        var output = Data(envelopeMagic)
        output.append(version)
        output.append(kind.rawValue)
        var length = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &length) { output.append(contentsOf: $0) }
        output.append(payload)
        return output
    }

    static func decodeEnvelope(_ data: Data) throws -> WireEnvelope {
        guard data.count >= envelopeHeaderSize,
              data[0] == envelopeMagic[0], data[1] == envelopeMagic[1],
              let kind = WireKind(rawValue: data[3]) else {
            throw WireCodecError.invalidEnvelope
        }
        let length = Int(UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7]))
        guard length == data.count - envelopeHeaderSize else { throw WireCodecError.invalidEnvelope }
        return WireEnvelope(version: data[2], kind: kind, payload: Data(data.dropFirst(envelopeHeaderSize)))
    }

    static func encodeEncryptedPayload(_ payload: EncryptedPayload) throws -> Data {
        guard let messageID = UUID(uuidString: payload.messageID),
              messageID.uuidString == payload.messageID,
              payload.sequence > 0,
              payload.combined.count >= 28 else {
            throw WireCodecError.invalidEncryptedPayload
        }
        var output = Data([encryptedPayloadVersion])
        var uuid = messageID.uuid
        withUnsafeBytes(of: &uuid) { output.append(contentsOf: $0) }
        var sequence = payload.sequence.bigEndian
        withUnsafeBytes(of: &sequence) { output.append(contentsOf: $0) }
        output.append(payload.combined)
        return output
    }

    static func decodeEncryptedPayload(_ data: Data) throws -> EncryptedPayload {
        guard data.count >= encryptedPayloadHeaderSize + 28,
              data[0] == encryptedPayloadVersion else {
            throw WireCodecError.invalidEncryptedPayload
        }
        let uuidBytes = [UInt8](data[1..<17])
        let uuidTuple: uuid_t = (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        )
        var sequence: UInt64 = 0
        for byte in data[17..<25] { sequence = (sequence << 8) | UInt64(byte) }
        guard sequence > 0 else { throw WireCodecError.invalidEncryptedPayload }
        return EncryptedPayload(
            combined: Data(data.dropFirst(encryptedPayloadHeaderSize)),
            messageID: UUID(uuid: uuidTuple).uuidString,
            sequence: sequence
        )
    }

    static func encodeAttachmentChunk(_ chunk: WireAttachmentChunk) throws -> Data {
        guard chunk.total > 0, chunk.index < chunk.total, !chunk.bytes.isEmpty else {
            throw WireCodecError.invalidAttachmentChunk
        }
        var output = Data([attachmentPayloadVersion])
        var index = chunk.index.bigEndian
        var total = chunk.total.bigEndian
        withUnsafeBytes(of: &index) { output.append(contentsOf: $0) }
        withUnsafeBytes(of: &total) { output.append(contentsOf: $0) }
        output.append(chunk.bytes)
        return output
    }

    static func decodeAttachmentChunk(_ data: Data) throws -> WireAttachmentChunk {
        guard data.count > attachmentChunkHeaderSize,
              data[0] == attachmentPayloadVersion else {
            throw WireCodecError.invalidAttachmentChunk
        }
        let index = UInt16(data[1]) << 8 | UInt16(data[2])
        let total = UInt16(data[3]) << 8 | UInt16(data[4])
        let bytes = Data(data.dropFirst(attachmentChunkHeaderSize))
        guard total > 0, index < total, !bytes.isEmpty else {
            throw WireCodecError.invalidAttachmentChunk
        }
        return WireAttachmentChunk(index: index, total: total, bytes: bytes)
    }

    static func encodeAttachmentCheckpoint(_ checkpoint: WireAttachmentCheckpoint) throws -> Data {
        guard checkpoint.total > 0, checkpoint.nextIndex <= checkpoint.total else {
            throw WireCodecError.invalidAttachmentCheckpoint
        }
        var output = Data([attachmentPayloadVersion])
        var next = checkpoint.nextIndex.bigEndian
        var total = checkpoint.total.bigEndian
        withUnsafeBytes(of: &next) { output.append(contentsOf: $0) }
        withUnsafeBytes(of: &total) { output.append(contentsOf: $0) }
        return output
    }

    static func decodeAttachmentCheckpoint(_ data: Data) throws -> WireAttachmentCheckpoint {
        guard data.count == attachmentCheckpointSize,
              data[0] == attachmentPayloadVersion else {
            throw WireCodecError.invalidAttachmentCheckpoint
        }
        let next = UInt16(data[1]) << 8 | UInt16(data[2])
        let total = UInt16(data[3]) << 8 | UInt16(data[4])
        guard total > 0, next <= total else { throw WireCodecError.invalidAttachmentCheckpoint }
        return WireAttachmentCheckpoint(nextIndex: next, total: total)
    }
}
