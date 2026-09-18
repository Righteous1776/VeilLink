import Foundation

struct VFLY1Header: Equatable, Sendable {
    static let magic = Data([0x56, 0x46, 0x4C, 0x59, 0x31, 0, 0, 0]) // VFLY1\0\0\0
    static let formatVersion: UInt32 = 1
    static let endianMarker: UInt32 = 0x01020304
    static let weightFloat32: UInt32 = 1
    static let byteCount = 136

    let version: UInt32
    let headerSize: UInt32
    let endian: UInt32
    let weightEncoding: UInt32
    let neuronCount: UInt32
    let edgeCount: UInt32
    let groupCount: UInt32
    let membershipCount: UInt32
    let offsetsOffset: UInt64
    let targetsOffset: UInt64
    let weightsOffset: UInt64
    let groupOffsetsOffset: UInt64
    let groupNeuronsOffset: UInt64
    let metadataOffset: UInt64
    let metadataLength: UInt64
    let payloadLength: UInt64
    let payloadSHA256: Data

    static func parse(_ data: Data) throws -> VFLY1Header {
        guard data.count >= byteCount, data.prefix(8) == magic else { throw VFLY1Error.invalidHeader }
        var reader = VFLY1DataReader(data: data, offset: 8)
        let header = VFLY1Header(
            version: try reader.u32(),
            headerSize: try reader.u32(),
            endian: try reader.u32(),
            weightEncoding: try reader.u32(),
            neuronCount: try reader.u32(),
            edgeCount: try reader.u32(),
            groupCount: try reader.u32(),
            membershipCount: try reader.u32(),
            offsetsOffset: try reader.u64(),
            targetsOffset: try reader.u64(),
            weightsOffset: try reader.u64(),
            groupOffsetsOffset: try reader.u64(),
            groupNeuronsOffset: try reader.u64(),
            metadataOffset: try reader.u64(),
            metadataLength: try reader.u64(),
            payloadLength: try reader.u64(),
            payloadSHA256: try reader.bytes(count: 32)
        )
        guard header.version == formatVersion,
              header.headerSize == UInt32(byteCount),
              header.endian == endianMarker,
              header.weightEncoding == weightFloat32,
              header.neuronCount > 0 else { throw VFLY1Error.unsupportedFormat }
        return header
    }
}

enum VFLY1Error: LocalizedError, Equatable {
    case invalidHeader
    case unsupportedFormat
    case truncated
    case invalidSection
    case invalidMetadata
    case hashMismatch
    case graphRejected
    case incompatibleTier

    var errorDescription: String? {
        switch self {
        case .invalidHeader: return "VFLY1 文件头无效。"
        case .unsupportedFormat: return "VFLY1 格式或编码版本不受支持。"
        case .truncated: return "VFLY1 文件不完整。"
        case .invalidSection: return "VFLY1 分区越界或计数不一致。"
        case .invalidMetadata: return "VFLY1 元数据无效。"
        case .hashMismatch: return "VFLY1 载荷 SHA-256 校验失败。"
        case .graphRejected: return "VFLY1 图无法通过 VeilFly 原生图验证。"
        case .incompatibleTier: return "该设备不允许加载此 VFLY 图档位。"
        }
    }
}

struct VFLY1Metadata: Codable, Equatable, Sendable {
    let format: String
    let formatVersion: Int
    let graphID: String
    let tier: String
    let datasetID: String
    let datasetLicense: String
    let primaryReference: String?
    let primaryReferenceRevision: String?
    let sourceBrainSHA256: String?
    let sourceWeightsSHA256: String?
    let recipe: String?
    let notes: String?
    let neuronCount: Int
    let edgeCount: Int
    let weightEncoding: String
    let groupNames: [String]
    let groupKinds: [String]
    let groupMemberCount: Int

    enum CodingKeys: String, CodingKey {
        case format
        case formatVersion = "format_version"
        case graphID = "graph_id"
        case tier
        case datasetID = "dataset_id"
        case datasetLicense = "dataset_license"
        case primaryReference = "primary_reference"
        case primaryReferenceRevision = "primary_reference_revision"
        case sourceBrainSHA256 = "source_brain_sha256"
        case sourceWeightsSHA256 = "source_weights_sha256"
        case recipe, notes
        case neuronCount = "neuron_count"
        case edgeCount = "edge_count"
        case weightEncoding = "weight_encoding"
        case groupNames = "group_names"
        case groupKinds = "group_kinds"
        case groupMemberCount = "group_member_count"
    }
}

struct VFLY1Group: Equatable, Sendable {
    enum Kind: String, Sendable { case sensory, readout, other }
    let name: String
    let kind: Kind
    let neuronIndices: [UInt32]
}

struct VFLY1Artifact: Sendable {
    let metadata: VFLY1Metadata
    let graph: MaleCNSNativeGraph
    let groups: [VFLY1Group]

    func group(named name: String) -> VFLY1Group? { groups.first { $0.name == name } }
    var sensoryGroups: [VFLY1Group] { groups.filter { $0.kind == .sensory } }
    var readoutGroups: [VFLY1Group] { groups.filter { $0.kind == .readout } }

    func nativeReadoutMap(names: [String]? = nil) throws -> MaleCNSNativeReadoutMap {
        let allowed = names.map(Set.init)
        let selected = readoutGroups.filter { allowed?.contains($0.name) ?? true }
        guard !selected.isEmpty else { throw VFLY1Error.invalidMetadata }
        return try MaleCNSNativeReadoutMap(
            groups: selected.map { MaleCNSNativeReadoutGroup(name: $0.name, neuronIndices: $0.neuronIndices) },
            neuronCount: graph.neuronCount
        )
    }
}

struct VFLY1DataReader {
    let data: Data
    var offset: Int

    mutating func bytes(count: Int) throws -> Data {
        guard count >= 0, offset >= 0, offset + count <= data.count else { throw VFLY1Error.truncated }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func u32() throws -> UInt32 {
        let b = try bytes(count: 4)
        return b.enumerated().reduce(UInt32(0)) { value, pair in value | (UInt32(pair.element) << UInt32(pair.offset * 8)) }
    }

    mutating func u64() throws -> UInt64 {
        let b = try bytes(count: 8)
        return b.enumerated().reduce(UInt64(0)) { value, pair in value | (UInt64(pair.element) << UInt64(pair.offset * 8)) }
    }
}
