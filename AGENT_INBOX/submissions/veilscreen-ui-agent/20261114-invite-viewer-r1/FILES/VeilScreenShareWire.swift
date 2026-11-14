import Foundation

/// Transient, authenticated session data only. Never put these packets in the chat database.
/// Encryption/authentication is applied by SessionCoordinator BEFORE BLE framing.
enum VeilScreenShareWireError: Error, Equatable {
    case invalidPacket
    case sizeLimit
    case badSession
}

enum VeilScreenShareAction: UInt8, Codable {
    case invite = 1
    case accept = 2
    case decline = 3
    case ready = 4
    case stop = 5
    case readyAck = 6
}

struct VeilScreenShareControl: Equatable {
    static let version: UInt8 = 1
    let sessionID: UUID
    let action: VeilScreenShareAction

    func encode() -> Data {
        var result = Data([Self.version, action.rawValue])
        var bytes = sessionID.uuid
        withUnsafeBytes(of: &bytes) { result.append(contentsOf: $0) }
        return result
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count == 18, data[0] == version,
              let action = VeilScreenShareAction(rawValue: data[1]) else {
            throw VeilScreenShareWireError.invalidPacket
        }
        return Self(sessionID: uuid(from: data[2..<18]), action: action)
    }
}

private func uuid(from bytes: Data.SubSequence) -> UUID {
    let b = Array(bytes)
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                       b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
}

/// Small enough to cap memory and avoid starving the existing chat/control queues.
/// All image bytes are encrypted by the current trusted peer session, never stored.
struct VeilScreenShareChunk: Equatable {
    static let version: UInt8 = 2 // R1; R0 packets are deliberately not silently decoded
    static let headerBytes = 33
    static let maximumChunkBytes = 384
    static let maximumFrameBytes = 32 * 1024
    static let maximumChunkCount = 86 // ceil(32768/384)

    let sessionID: UUID
    let frameID: UInt64
    let index: UInt16
    let total: UInt16
    let width: UInt16
    let height: UInt16
    let bytes: Data

    func encode() throws -> Data {
        guard total > 0, total <= Self.maximumChunkCount,
              index < total, width >= 64, height >= 64,
              width <= 2048, height <= 2048,
              !bytes.isEmpty, bytes.count <= Self.maximumChunkBytes else {
            throw VeilScreenShareWireError.invalidPacket
        }
        var result = Data([Self.version])
        var id = sessionID.uuid
        withUnsafeBytes(of: &id) { result.append(contentsOf: $0) }
        result.appendBE(frameID)
        result.appendBE(index)
        result.appendBE(total)
        result.appendBE(width)
        result.appendBE(height)
        result.append(bytes)
        return result
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count > headerBytes, data.count <= headerBytes + maximumChunkBytes,
              data[0] == version else { throw VeilScreenShareWireError.invalidPacket }
        let value = Self(sessionID: uuid(from: data[1..<17]),
                         frameID: data.readBEUInt64(at: 17),
                         index: data.readBEUInt16(at: 25),
                         total: data.readBEUInt16(at: 27),
                         width: data.readBEUInt16(at: 29),
                         height: data.readBEUInt16(at: 31),
                         bytes: Data(data.dropFirst(headerBytes)))
        _ = try value.encode() // validate lengths, dimensions and indices
        return value
    }

    static func split(image: Data, sessionID: UUID, frameID: UInt64,
                      width: Int, height: Int) throws -> [Self] {
        guard !image.isEmpty, image.count <= maximumFrameBytes,
              (64...2048).contains(width), (64...2048).contains(height) else {
            throw VeilScreenShareWireError.sizeLimit
        }
        let total = (image.count + maximumChunkBytes - 1) / maximumChunkBytes
        guard total <= maximumChunkCount else { throw VeilScreenShareWireError.sizeLimit }
        return (0..<total).map { i in
            let start = i * maximumChunkBytes
            return Self(sessionID: sessionID, frameID: frameID,
                        index: UInt16(i), total: UInt16(total),
                        width: UInt16(width), height: UInt16(height),
                        bytes: Data(image[start..<min(start + maximumChunkBytes, image.count)]))
        }
    }
}

private extension Data {
    mutating func appendBE(_ v: UInt16) {
        append(UInt8(truncatingIfNeeded: v >> 8)); append(UInt8(truncatingIfNeeded: v))
    }
    mutating func appendBE(_ v: UInt32) {
        append(UInt8(truncatingIfNeeded: v >> 24)); append(UInt8(truncatingIfNeeded: v >> 16))
        append(UInt8(truncatingIfNeeded: v >> 8)); append(UInt8(truncatingIfNeeded: v))
    }
    mutating func appendBE(_ v: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8(truncatingIfNeeded: v >> UInt64(shift)))
        }
    }
    func readBEUInt64(at offset: Int) -> UInt64 {
        var result: UInt64 = 0
        for i in 0..<8 { result = (result << 8) | UInt64(self[offset + i]) }
        return result
    }
    func readBEUInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }
    func readBEUInt32(at offset: Int) -> UInt32 {
        UInt32(self[offset]) << 24 | UInt32(self[offset + 1]) << 16 |
            UInt32(self[offset + 2]) << 8 | UInt32(self[offset + 3])
    }
}

struct VeilScreenShareFrame: Equatable {
    let frameID: UInt64
    let width: Int
    let height: Int
    let image: Data
}

/// One in-flight frame, no disk writes, bounded allocation, short expiry.
/// Incomplete frames are discarded instead of blocking newer frames.
struct VeilScreenShareAssembler {
    private let sessionID: UUID
    private var activeID: UInt64?
    private var firstReceivedAt: TimeInterval = 0
    private var pieces: [UInt16: Data] = [:]
    private var expected: UInt16 = 0
    private var w: UInt16 = 0
    private var h: UInt16 = 0
    private var byteCount: Int = 0
    private var newestCompletedID: UInt64?

    init(sessionID: UUID) { self.sessionID = sessionID }

    mutating func receive(_ chunk: VeilScreenShareChunk, at now: TimeInterval) throws -> VeilScreenShareFrame? {
        guard chunk.sessionID == sessionID else { throw VeilScreenShareWireError.badSession }
        _ = try chunk.encode()
        if let completed = newestCompletedID, chunk.frameID <= completed { return nil }
        if let current = activeID, chunk.frameID < current { return nil }
        if activeID != chunk.frameID || now - firstReceivedAt > 7 {
            activeID = chunk.frameID; firstReceivedAt = now
            pieces.removeAll(keepingCapacity: true); byteCount = 0
            expected = chunk.total; w = chunk.width; h = chunk.height
        }
        guard chunk.total == expected, chunk.width == w, chunk.height == h else {
            throw VeilScreenShareWireError.invalidPacket
        }
        if let existing = pieces[chunk.index] {
            if existing != chunk.bytes { throw VeilScreenShareWireError.invalidPacket }
            return nil
        }
        guard byteCount + chunk.bytes.count <= VeilScreenShareChunk.maximumFrameBytes else {
            reset(); throw VeilScreenShareWireError.sizeLimit
        }
        pieces[chunk.index] = chunk.bytes
        byteCount += chunk.bytes.count
        guard pieces.count == Int(expected) else { return nil }
        var frame = Data(capacity: byteCount)
        for i in 0..<expected {
            guard let bytes = pieces[i] else { throw VeilScreenShareWireError.invalidPacket }
            frame.append(bytes)
        }
        let output = VeilScreenShareFrame(frameID: chunk.frameID,
                                          width: Int(w), height: Int(h), image: frame)
        newestCompletedID = chunk.frameID
        reset()
        return output
    }

    private mutating func reset() {
        activeID = nil; pieces.removeAll(keepingCapacity: false)
        byteCount = 0; expected = 0; w = 0; h = 0
    }
}

/// Adaptive to *measured* encrypted BLE throughput. It does not guess radio capability.
struct VeilScreenShareRateController {
    private(set) var targetWidth: Int = 320
    private(set) var interval: TimeInterval = 2
    private(set) var targetFrameBytes: Int = 8 * 1024

    mutating func update(bytesPerSecond: Double, pendingBytes: Int) {
        let kbps = max(0, bytesPerSecond) / 1024
        if pendingBytes > 8 * 1024 || kbps < 2 {
            targetWidth = 240; interval = 5; targetFrameBytes = 3 * 1024
        } else if kbps < 6 {
            targetWidth = 320; interval = 2.5; targetFrameBytes = 6 * 1024
        } else if kbps < 14 {
            targetWidth = 420; interval = 1.5; targetFrameBytes = 12 * 1024
        } else {
            targetWidth = 540; interval = 0.5; targetFrameBytes = 20 * 1024
        }
    }

    /// A 64-bit fast digest of *already downsampled* luminance to avoid re-sending still frames.
    static func digest(_ bytes: Data) -> UInt64 {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in bytes { value = (value ^ UInt64(byte)) &* 0x100000001b3 }
        return value
    }
}
