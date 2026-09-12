import XCTest
@testable import VeilLink

final class BLETransportSafetyTests: XCTestCase {
    func testFragmentationPlanAcceptsExactUInt16BoundaryAtLegacyATTSize() {
        let packetSize = 20
        let payloadBytes = (packetSize - BLEFragment.headerSize) * BLEFragment.maximumFragmentCount
        let plan = BLEFragment.fragmentationPlan(
            payloadByteCount: payloadBytes,
            maximumPacketSize: packetSize
        )

        XCTAssertEqual(plan?.fragmentCount, BLEFragment.maximumFragmentCount)
        XCTAssertEqual(
            plan?.encodedByteCount,
            payloadBytes + BLEFragment.maximumFragmentCount * BLEFragment.headerSize
        )
    }

    func testFragmentationPlanRejectsOneByteBeyondUInt16Boundary() {
        let packetSize = 20
        let payloadBytes = (packetSize - BLEFragment.headerSize) * BLEFragment.maximumFragmentCount + 1

        XCTAssertNil(
            BLEFragment.fragmentationPlan(
                payloadByteCount: payloadBytes,
                maximumPacketSize: packetSize
            )
        )
    }

    func testProtocol4EnvelopeFitsTransportFragmentCapAtLegacyATTSize() {
        let maximumProtocol4EnvelopeBytes = 96_000
        let legacyPlan = BLEFragment.fragmentationPlan(
            payloadByteCount: maximumProtocol4EnvelopeBytes,
            maximumPacketSize: 20
        )
        XCTAssertNotNil(legacyPlan)
        XCTAssertLessThanOrEqual(legacyPlan?.fragmentCount ?? .max, 16_384)

        let undersizedPlan = BLEFragment.fragmentationPlan(
            payloadByteCount: maximumProtocol4EnvelopeBytes,
            maximumPacketSize: 19
        )
        XCTAssertGreaterThan(undersizedPlan?.fragmentCount ?? 0, 16_384)
    }

    func testAssemblerEvictsOlderPartialWhenGlobalBufferBudgetIsReached() {
        let source = UUID()
        let firstMessage = Data(repeating: 0x11, count: 120)
        let secondMessage = Data(repeating: 0x22, count: 120)
        let firstFragments = BLEFragment.split(firstMessage, maximumPacketSize: 64)
        let secondFragments = BLEFragment.split(secondMessage, maximumPacketSize: 64)
        let assembler = BLEFragmentAssembler(
            maxConcurrentMessages: 4,
            maxFragmentsPerMessage: 16,
            maxAssembledBytes: 120,
            maxPacketBytes: 64,
            maxTotalBufferedBytes: 120
        )

        XCTAssertNil(assembler.ingest(source: source, packet: firstFragments[0].encoded))
        XCTAssertNil(assembler.ingest(source: source, packet: firstFragments[1].encoded))
        XCTAssertNil(assembler.ingest(source: source, packet: secondFragments[0].encoded))

        var recovered: Data?
        for fragment in secondFragments.dropFirst() {
            recovered = assembler.ingest(source: source, packet: fragment.encoded) ?? recovered
        }
        XCTAssertEqual(recovered, secondMessage)
    }
    func testAssemblerLimitsConcurrentPartialsPerSourceWithoutBlockingAnotherSource() {
        let sourceA = UUID()
        let sourceB = UUID()
        let first = BLEFragment.split(Data(repeating: 0x31, count: 120), maximumPacketSize: 64)
        let second = BLEFragment.split(Data(repeating: 0x32, count: 120), maximumPacketSize: 64)
        let other = BLEFragment.split(Data(repeating: 0x44, count: 120), maximumPacketSize: 64)
        let assembler = BLEFragmentAssembler(
            maxConcurrentMessages: 4,
            maxConcurrentMessagesPerSource: 1,
            maxFragmentsPerMessage: 16,
            maxAssembledBytes: 256,
            maxPacketBytes: 64,
            maxTotalBufferedBytes: 512
        )

        XCTAssertNil(assembler.ingest(source: sourceA, packet: first[0].encoded))
        XCTAssertNil(assembler.ingest(source: sourceA, packet: second[0].encoded)) // evicts A's first partial

        var recoveredOther: Data?
        for fragment in other {
            recoveredOther = assembler.ingest(source: sourceB, packet: fragment.encoded) ?? recoveredOther
        }
        XCTAssertEqual(recoveredOther, Data(repeating: 0x44, count: 120))

        var recoveredFirst: Data?
        for fragment in first.dropFirst() {
            recoveredFirst = assembler.ingest(source: sourceA, packet: fragment.encoded) ?? recoveredFirst
        }
        XCTAssertNil(recoveredFirst)
    }

    func testConnectionEventGateDeduplicatesCallbacksAndAllowsReconnect() {
        var gate = ConnectionEventGate()
        let id = UUID()

        XCTAssertTrue(gate.markConnected(id))
        XCTAssertFalse(gate.markConnected(id))
        XCTAssertEqual(gate.count, 1)
        XCTAssertTrue(gate.markDisconnected(id))
        XCTAssertFalse(gate.markDisconnected(id))
        XCTAssertTrue(gate.markConnected(id))
    }

    func testConnectionEventGateDrainsOnlyLiveConnections() {
        var gate = ConnectionEventGate()
        let first = UUID()
        let second = UUID()
        XCTAssertTrue(gate.markConnected(first))
        XCTAssertTrue(gate.markConnected(second))
        XCTAssertTrue(gate.markDisconnected(first))

        XCTAssertEqual(Set(gate.drainConnectedIDs()), [second])
        XCTAssertEqual(gate.count, 0)
    }

}
