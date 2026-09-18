#if canImport(CryptoKit)
import CryptoKit
#endif
import Foundation

/// Loads one build-time compiled MaleCNS derivative. Large raw Feather/NPZ files are never parsed
/// inside the iOS app. The whole-file Data mapping is read-only; graph arrays are copied once into
/// stable Swift COW storage used by the C kernel and shared across rollout workers.
enum VFLY1Loader {
    static func load(url: URL, verifyPayloadHash: Bool = true) throws -> VFLY1Artifact {
        let data: Data
        do { data = try Data(contentsOf: url, options: [.mappedIfSafe]) }
        catch { throw VFLY1Error.truncated }
        return try load(data: data, verifyPayloadHash: verifyPayloadHash)
    }

    static func load(data: Data, verifyPayloadHash: Bool = true) throws -> VFLY1Artifact {
        let header = try VFLY1Header.parse(data)
        guard UInt64(data.count) == UInt64(header.headerSize) + header.payloadLength else { throw VFLY1Error.truncated }
        if verifyPayloadHash {
#if canImport(CryptoKit)
            let payload = data.suffix(from: Int(header.headerSize))
            let digest = Data(SHA256.hash(data: payload))
            guard digest == header.payloadSHA256 else { throw VFLY1Error.hashMismatch }
#else
            // Build-host CI verifies the exact same payload hash in `verify_vfly.py`. iOS 15+
            // always has CryptoKit; Linux shape checks may request `verifyPayloadHash: false`.
            throw VFLY1Error.unsupportedFormat
#endif
        }

        let neuronCount = Int(header.neuronCount)
        let edgeCount = Int(header.edgeCount)
        let groupCount = Int(header.groupCount)
        let membershipCount = Int(header.membershipCount)
        let offsets = try u32Array(data, at: header.offsetsOffset, count: neuronCount + 1)
        let targets = try u32Array(data, at: header.targetsOffset, count: edgeCount)
        let weights = try f32Array(data, at: header.weightsOffset, count: edgeCount)
        let groupOffsets = try u32Array(data, at: header.groupOffsetsOffset, count: groupCount + 1)
        let groupNeurons = try u32Array(data, at: header.groupNeuronsOffset, count: membershipCount)
        let metadataData = try slice(data, at: header.metadataOffset, byteCount: Int(header.metadataLength))
        let metadata: VFLY1Metadata
        do { metadata = try JSONDecoder().decode(VFLY1Metadata.self, from: metadataData) }
        catch { throw VFLY1Error.invalidMetadata }

        guard metadata.format == "VFLY1", metadata.formatVersion == Int(header.version),
              metadata.neuronCount == neuronCount, metadata.edgeCount == edgeCount,
              metadata.groupNames.count == groupCount, metadata.groupKinds.count == groupCount,
              metadata.groupMemberCount == membershipCount,
              offsets.first == 0, offsets.last == header.edgeCount,
              groupOffsets.first == 0, groupOffsets.last == header.membershipCount else {
            throw VFLY1Error.invalidMetadata
        }
        guard zip(offsets, offsets.dropFirst()).allSatisfy({ pair in pair.0 <= pair.1 }),
              zip(groupOffsets, groupOffsets.dropFirst()).allSatisfy({ pair in pair.0 <= pair.1 }),
              targets.allSatisfy({ Int($0) < neuronCount }),
              groupNeurons.allSatisfy({ Int($0) < neuronCount }) else { throw VFLY1Error.invalidSection }

        let graph: MaleCNSNativeGraph
        do { graph = try MaleCNSNativeGraph(neuronCount: neuronCount, offsets: offsets, targets: targets, weights: weights) }
        catch { throw VFLY1Error.graphRejected }

        var groups: [VFLY1Group] = []
        groups.reserveCapacity(groupCount)
        for index in 0..<groupCount {
            let start = Int(groupOffsets[index]), end = Int(groupOffsets[index + 1])
            guard start <= end, end <= groupNeurons.count else { throw VFLY1Error.invalidSection }
            let kind = VFLY1Group.Kind(rawValue: metadata.groupKinds[index]) ?? .other
            groups.append(VFLY1Group(name: metadata.groupNames[index], kind: kind, neuronIndices: Array(groupNeurons[start..<end])))
        }
        return VFLY1Artifact(metadata: metadata, graph: graph, groups: groups)
    }

    private static func slice(_ data: Data, at offset: UInt64, byteCount: Int) throws -> Data {
        guard offset <= UInt64(Int.max), byteCount >= 0 else { throw VFLY1Error.invalidSection }
        let start = Int(offset)
        guard start >= VFLY1Header.byteCount, start <= data.count, byteCount <= data.count - start else { throw VFLY1Error.invalidSection }
        return data.subdata(in: start..<(start + byteCount))
    }

    private static func u32Array(_ data: Data, at offset: UInt64, count: Int) throws -> [UInt32] {
        let bytes = try slice(data, at: offset, byteCount: try checkedBytes(count: count, stride: 4))
        var result = [UInt32](); result.reserveCapacity(count)
        for i in 0..<count {
            let b = i * 4
            result.append(UInt32(bytes[b]) | UInt32(bytes[b+1]) << 8 | UInt32(bytes[b+2]) << 16 | UInt32(bytes[b+3]) << 24)
        }
        return result
    }

    private static func f32Array(_ data: Data, at offset: UInt64, count: Int) throws -> [Float] {
        try u32Array(data, at: offset, count: count).map { Float(bitPattern: $0) }
    }

    private static func checkedBytes(count: Int, stride: Int) throws -> Int {
        guard count >= 0, stride > 0, count <= Int.max / stride else { throw VFLY1Error.invalidSection }
        return count * stride
    }
}
