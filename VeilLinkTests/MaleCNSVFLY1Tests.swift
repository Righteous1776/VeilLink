import CryptoKit
import XCTest
@testable import VeilLink

final class MaleCNSVFLY1Tests: XCTestCase {
    func testVFLY1LoaderAndNativeStimulusPath() throws {
        let data = makeFixture()
        let artifact = try VFLY1Loader.load(data: data)
        XCTAssertEqual(artifact.metadata.datasetID, "male-cns:v1.0")
        XCTAssertEqual(artifact.graph.neuronCount, 4)
        XCTAssertEqual(artifact.graph.targets.count, 3)
        XCTAssertEqual(artifact.group(named: "sensory.LC4.L")?.neuronIndices, [0])
        XCTAssertEqual(artifact.group(named: "readout.escape_L")?.neuronIndices, [3])

        let runtime = try MaleCNSGraphRuntime(artifact: artifact, preferredReadouts: ["readout.escape_L"])
        runtime.applyComputeBudget(MaleCNSComputeBudget(
            tier: .lite, workerCount: 1, neuralStepBudget: 4,
            episodeMilliseconds: 100, rolloutCount: 1, stateSampleStride: 1
        ))
        let result = try runtime.run(stimulus: .looming(side: .left, strength: 1.1), requestedSteps: 4)
        XCTAssertEqual(result.summary.executedSteps, 4)
        XCTAssertEqual(result.readout.names, ["readout.escape_L"])
        XCTAssertGreaterThan(result.readout.spikeCounts[0], 0)
    }


    func testDeviceTierRejectsReferenceGraphAndLegacyRejectsCore() {
        XCTAssertEqual(MaleCNSGraphManager.allowedGraphTiers(for: .legacyA10), [.lite])
        XCTAssertEqual(MaleCNSGraphManager.allowedGraphTiers(for: .balanced), [.core, .lite])
        XCTAssertEqual(MaleCNSGraphManager.allowedGraphTiers(for: .high), [.core, .lite])
        XCTAssertFalse(MaleCNSGraphManager.allowedGraphTiers(for: .legacyA10).contains(.core))
        XCTAssertFalse(MaleCNSGraphManager.allowedGraphTiers(for: .high).contains(.reference))
    }

    func testPayloadHashFailureClosesArtifact() throws {
        var data = makeFixture()
        data[data.count - 1] ^= 0x01
        XCTAssertThrowsError(try VFLY1Loader.load(data: data)) { error in
            XCTAssertEqual(error as? VFLY1Error, .hashMismatch)
        }
    }

    private func makeFixture() -> Data {
        let offsets: [UInt32] = [0, 1, 2, 3, 3]
        let targets: [UInt32] = [1, 2, 3]
        let weights: [Float] = [1, 1, 1]
        let groupOffsets: [UInt32] = [0, 1, 2]
        let groupNeurons: [UInt32] = [0, 3]
        let metadata: [String: Any] = [
            "format": "VFLY1", "format_version": 1,
            "graph_id": "xctest-vfly", "tier": "lite",
            "dataset_id": "male-cns:v1.0", "dataset_license": "CC BY 4.0",
            "neuron_count": 4, "edge_count": 3, "weight_encoding": "float32-le",
            "group_names": ["sensory.LC4.L", "readout.escape_L"],
            "group_kinds": ["sensory", "readout"], "group_member_count": 2,
        ]
        let metadataData = try! JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
        var payload = Data()
        func appendU32(_ values: [UInt32]) { for value in values { var x = value.littleEndian; Swift.withUnsafeBytes(of: &x) { payload.append(contentsOf: $0) } } }
        appendU32(offsets)
        appendU32(targets)
        for value in weights { var x = value.bitPattern.littleEndian; Swift.withUnsafeBytes(of: &x) { payload.append(contentsOf: $0) } }
        appendU32(groupOffsets)
        appendU32(groupNeurons)
        payload.append(metadataData)

        let offsetsPos = UInt64(VFLY1Header.byteCount)
        let targetsPos = offsetsPos + UInt64(offsets.count * 4)
        let weightsPos = targetsPos + UInt64(targets.count * 4)
        let groupOffsetsPos = weightsPos + UInt64(weights.count * 4)
        let groupNeuronsPos = groupOffsetsPos + UInt64(groupOffsets.count * 4)
        let metadataPos = groupNeuronsPos + UInt64(groupNeurons.count * 4)
        let hash = Data(SHA256.hash(data: payload))
        var out = Data(VFLY1Header.magic)
        func headerU32(_ value: UInt32) { var x = value.littleEndian; Swift.withUnsafeBytes(of: &x) { out.append(contentsOf: $0) } }
        func headerU64(_ value: UInt64) { var x = value.littleEndian; Swift.withUnsafeBytes(of: &x) { out.append(contentsOf: $0) } }
        [UInt32(1), UInt32(VFLY1Header.byteCount), VFLY1Header.endianMarker, VFLY1Header.weightFloat32, 4, 3, 2, 2].forEach(headerU32)
        [offsetsPos, targetsPos, weightsPos, groupOffsetsPos, groupNeuronsPos, metadataPos, UInt64(metadataData.count), UInt64(payload.count)].forEach(headerU64)
        out.append(hash)
        XCTAssertEqual(out.count, VFLY1Header.byteCount)
        out.append(payload)
        return out
    }
}
