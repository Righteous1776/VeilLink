import Foundation

enum VeilPTTControlKind: UInt8, Codable, Sendable { case begin = 1, end = 2 }

struct VeilPTTControlPacket: Codable, Equatable, Sendable {
    let talkID: String
    let kind: VeilPTTControlKind
    let sampleRate: Int
    let frameDurationMilliseconds: Int

    init(talkID: String, kind: VeilPTTControlKind, sampleRate: Int = 8_000, frameDurationMilliseconds: Int = 80) {
        self.talkID = talkID
        self.kind = kind
        self.sampleRate = sampleRate
        self.frameDurationMilliseconds = frameDurationMilliseconds
    }
}

struct VeilPTTAudioFrame: Equatable, Sendable {
    let talkID: String
    let index: UInt32
    let muLawBytes: Data
}

struct VeilPTTIncomingControl: Sendable {
    let peerIdentityID: String
    let packet: VeilPTTControlPacket
}

struct VeilPTTIncomingAudio: Sendable {
    let peerIdentityID: String
    let frame: VeilPTTAudioFrame
}

enum VeilPTTCodecError: Error { case invalid }

enum VeilPTTCodec {
    private static let version: UInt8 = 1

    static func encodeControl(_ packet: VeilPTTControlPacket) throws -> Data {
        guard UUID(uuidString: packet.talkID) != nil,
              packet.sampleRate == 8_000,
              (40...160).contains(packet.frameDurationMilliseconds) else { throw VeilPTTCodecError.invalid }
        return try JSONEncoder().encode(packet)
    }

    static func decodeControl(_ data: Data) throws -> VeilPTTControlPacket {
        let packet = try JSONDecoder().decode(VeilPTTControlPacket.self, from: data)
        guard UUID(uuidString: packet.talkID) != nil,
              packet.sampleRate == 8_000,
              (40...160).contains(packet.frameDurationMilliseconds) else { throw VeilPTTCodecError.invalid }
        return packet
    }

    static func encodeAudio(_ frame: VeilPTTAudioFrame) throws -> Data {
        guard let uuid = UUID(uuidString: frame.talkID),
              !frame.muLawBytes.isEmpty,
              frame.muLawBytes.count <= 1_280 else { throw VeilPTTCodecError.invalid }
        var out = Data([version])
        var tuple = uuid.uuid
        withUnsafeBytes(of: &tuple) { out.append(contentsOf: $0) }
        var index = frame.index.bigEndian
        withUnsafeBytes(of: &index) { out.append(contentsOf: $0) }
        out.append(frame.muLawBytes)
        return out
    }

    static func decodeAudio(_ data: Data) throws -> VeilPTTAudioFrame {
        guard data.count > 21, data[0] == version else { throw VeilPTTCodecError.invalid }
        let b = [UInt8](data[1..<17])
        let tuple: uuid_t = (b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15])
        var index: UInt32 = 0
        for byte in data[17..<21] { index = (index << 8) | UInt32(byte) }
        let bytes = Data(data.dropFirst(21))
        guard !bytes.isEmpty, bytes.count <= 1_280 else { throw VeilPTTCodecError.invalid }
        return VeilPTTAudioFrame(talkID: UUID(uuid: tuple).uuidString, index: index, muLawBytes: bytes)
    }
}

enum VeilMuLaw {
    private static let bias = 0x84
    private static let clip = 32635

    static func encode(_ sample: Int16) -> UInt8 {
        var value = Int(sample)
        let sign = value < 0 ? 0x80 : 0
        if value < 0 { value = -value }
        value = min(value, clip) + bias
        var exponent = 7
        var mask = 0x4000
        while exponent > 0 && (value & mask) == 0 { exponent -= 1; mask >>= 1 }
        let mantissa = (value >> (exponent + 3)) & 0x0F
        return UInt8(~(sign | (exponent << 4) | mantissa) & 0xFF)
    }

    static func decode(_ byte: UInt8) -> Int16 {
        let u = Int(~byte & 0xFF)
        let sign = u & 0x80
        let exponent = (u >> 4) & 0x07
        let mantissa = u & 0x0F
        var sample = ((mantissa << 3) + bias) << exponent
        sample -= bias
        if sign != 0 { sample = -sample }
        return Int16(max(Int(Int16.min), min(Int(Int16.max), sample)))
    }
}
