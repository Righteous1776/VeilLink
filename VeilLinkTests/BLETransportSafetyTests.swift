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

    func testQueueProgressIsIndependentByRoleAndPeer() {
        let peer = UUID()
        let otherPeer = UUID()
        var progress = BLEQueueProgressState()
        progress.beginIfNeeded(.central, peerID: peer, at: 10)
        progress.beginIfNeeded(.peripheral, peerID: peer, at: 20)
        progress.beginIfNeeded(.central, peerID: otherPeer, at: 30)
        progress.recordProgress(.central, peerID: peer, at: 40)

        XCTAssertEqual(progress.lastProgress(.central, peerID: peer), 40)
        XCTAssertEqual(progress.lastProgress(.peripheral, peerID: peer), 20)
        XCTAssertEqual(progress.lastProgress(.central, peerID: otherPeer), 30)
        XCTAssertEqual(progress.stalledDuration(peerID: peer, centralPending: true, peripheralPending: true, now: 50), 30)
        progress.clear(.central, peerID: peer)
        XCTAssertEqual(progress.stalledDuration(peerID: peer, centralPending: true, peripheralPending: true, now: 50), 30)
    }

    func testRealtimeAndBulkAdmissionPreserveControlCapacity() {
        let packets = 8_192
        let bytes = 640_000
        let reservePackets = packets / 8
        let reserveBytes = bytes / 8

        XCTAssertTrue(BLEQueueAdmissionPolicy.canEnqueue(
            pendingPackets: packets - reservePackets,
            pendingBytes: bytes - reserveBytes,
            additionalPackets: reservePackets,
            additionalBytes: reserveBytes,
            priority: .control,
            maximumPackets: packets,
            maximumBytes: bytes
        ))
        XCTAssertFalse(BLEQueueAdmissionPolicy.canEnqueue(
            pendingPackets: packets - reservePackets,
            pendingBytes: bytes - reserveBytes,
            additionalPackets: 1,
            additionalBytes: 1,
            priority: .realtime,
            maximumPackets: packets,
            maximumBytes: bytes
        ))
        XCTAssertFalse(BLEQueueAdmissionPolicy.canEnqueue(
            pendingPackets: packets - reservePackets,
            pendingBytes: bytes - reserveBytes,
            additionalPackets: 1,
            additionalBytes: 1,
            priority: .bulk,
            maximumPackets: packets,
            maximumBytes: bytes
        ))
    }

    func testSE1LegacyATTAdmissionFits48KiBEnvelopeWithoutChangingFragmentWireShape() {
        let maximumPacketSize = 20
        // The encrypted transport envelope is larger than the 48 KiB clear attachment chunk.
        let payload = Data((0..<49_218).map { UInt8(truncatingIfNeeded: $0) })
        let plan = BLEFragment.fragmentationPlan(payloadByteCount: payload.count, maximumPacketSize: maximumPacketSize)!
        let se1PacketLimit = DevicePerformancePolicy.profile(
            machineIdentifier: "iPhone8,4",
            osMajorVersion: 15
        ).bleQueuePacketLimit
        XCTAssertEqual(plan.fragmentCount, 8_203)
        XCTAssertEqual(se1PacketLimit, 9_216)
        XCTAssertLessThanOrEqual(plan.fragmentCount, se1PacketLimit - 512)
        XCTAssertLessThanOrEqual(plan.encodedByteCount, 640_000 - 640_000 / 8)
        XCTAssertTrue(BLEQueueAdmissionPolicy.canEnqueue(
            pendingPackets: 0,
            pendingBytes: 0,
            additionalPackets: plan.fragmentCount,
            additionalBytes: plan.encodedByteCount,
            priority: .bulk,
            maximumPackets: se1PacketLimit,
            maximumBytes: 640_000
        ))

        var packets: [Data] = []
        let appendedPlan = BLEFragment.appendEncodedPackets(payload, maximumPacketSize: maximumPacketSize, to: &packets)
        XCTAssertEqual(appendedPlan?.fragmentCount, plan.fragmentCount)
        XCTAssertEqual(packets.count, plan.fragmentCount)
        XCTAssertTrue(packets.allSatisfy { $0.count <= maximumPacketSize && $0.prefix(2) == Data([0x56, 0x02]) })

        let fragments = packets.compactMap(BLEFragment.init(data:))
        XCTAssertEqual(fragments.count, plan.fragmentCount)
        XCTAssertTrue(fragments.allSatisfy { Int($0.total) == plan.fragmentCount })
        XCTAssertEqual(fragments.map(\.payload).reduce(into: Data(), { $0.append($1) }), payload)
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


    func testAssemblerResetDropsPreviousTransportEpochFragments() {
        let source = UUID()
        let firstMessage = Data(repeating: 0x51, count: 120)
        let secondMessage = Data(repeating: 0x61, count: 120)
        let first = BLEFragment.split(firstMessage, maximumPacketSize: 64)
        let second = BLEFragment.split(secondMessage, maximumPacketSize: 64)
        let assembler = BLEFragmentAssembler(
            maxConcurrentMessages: 4,
            maxConcurrentMessagesPerSource: 2,
            maxFragmentsPerMessage: 16,
            maxAssembledBytes: 256,
            maxPacketBytes: 64,
            maxTotalBufferedBytes: 512
        )

        XCTAssertNil(assembler.ingest(source: source, packet: first[0].encoded))
        assembler.reset(source: source)
        var oldRecovered: Data?
        for fragment in first.dropFirst() {
            oldRecovered = assembler.ingest(source: source, packet: fragment.encoded) ?? oldRecovered
        }
        XCTAssertNil(oldRecovered)

        var newRecovered: Data?
        for fragment in second {
            newRecovered = assembler.ingest(source: source, packet: fragment.encoded) ?? newRecovered
        }
        XCTAssertEqual(newRecovered, secondMessage)
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
