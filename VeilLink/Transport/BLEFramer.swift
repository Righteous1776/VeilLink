import Foundation

struct BLEFragment {
    // Transport framing v2. A compact 64-bit frame ID keeps the header below the
    // legacy 20-byte ATT payload so text/control traffic still works on small MTUs.
    static let headerSize = 14
    static let indexOffset = 10
    static let totalOffset = 12
    static let maximumFragmentCount = Int(UInt16.max)

    let frameID: UInt64
    let index: UInt16
    let total: UInt16
    let payload: Data

    var encoded: Data {
        var result = Data([0x56, 0x02])
        var bigFrameID = frameID.bigEndian
        var bigIndex = index.bigEndian
        var bigTotal = total.bigEndian
        withUnsafeBytes(of: &bigFrameID) { result.append(contentsOf: $0) }
        withUnsafeBytes(of: &bigIndex) { result.append(contentsOf: $0) }
        withUnsafeBytes(of: &bigTotal) { result.append(contentsOf: $0) }
        result.append(payload)
        return result
    }

    init?(data: Data) {
        guard data.count >= Self.headerSize, data[0] == 0x56, data[1] == 0x02 else { return nil }
        var decodedFrameID: UInt64 = 0
        for byte in data[2..<10] { decodedFrameID = (decodedFrameID << 8) | UInt64(byte) }
        frameID = decodedFrameID
        index = UInt16(data[Self.indexOffset]) << 8 | UInt16(data[Self.indexOffset + 1])
        total = UInt16(data[Self.totalOffset]) << 8 | UInt16(data[Self.totalOffset + 1])
        payload = Data(data.dropFirst(Self.headerSize))
    }

    private init(frameID: UInt64, index: UInt16, total: UInt16, payload: Data) {
        self.frameID = frameID
        self.index = index
        self.total = total
        self.payload = payload
    }

    static func fragmentationPlan(payloadByteCount: Int, maximumPacketSize: Int) -> (fragmentCount: Int, encodedByteCount: Int)? {
        guard payloadByteCount >= 0, maximumPacketSize > headerSize else { return nil }
        let chunkSize = maximumPacketSize - headerSize
        let count = payloadByteCount == 0 ? 1 : 1 + (payloadByteCount - 1) / chunkSize
        guard count <= maximumFragmentCount else { return nil }
        let (headerBytes, overflow) = count.multipliedReportingOverflow(by: headerSize)
        guard !overflow else { return nil }
        let (encodedBytes, totalOverflow) = payloadByteCount.addingReportingOverflow(headerBytes)
        guard !totalOverflow else { return nil }
        return (count, encodedBytes)
    }

    static func split(_ data: Data, maximumPacketSize: Int) -> [BLEFragment] {
        guard let plan = fragmentationPlan(payloadByteCount: data.count, maximumPacketSize: maximumPacketSize) else { return [] }
        let chunkSize = maximumPacketSize - headerSize
        let count = plan.fragmentCount
        let frameID = UInt64.random(in: 1...UInt64.max)
        return (0..<count).map { index in
            let start = min(index * chunkSize, data.count)
            let end = min(start + chunkSize, data.count)
            return BLEFragment(
                frameID: frameID,
                index: UInt16(index),
                total: UInt16(count),
                payload: Data(data[start..<end])
            )
        }
    }

    /// Produces the exact v2 wire packets without first allocating a second array of fragment
    /// payload objects. The wire format and fragmentation plan are identical to `split`.
    static func encodedPackets(_ data: Data, maximumPacketSize: Int) -> [Data] {
        var packets: [Data] = []
        guard appendEncodedPackets(data, maximumPacketSize: maximumPacketSize, to: &packets) != nil else { return [] }
        return packets
    }

    /// Appends final wire packets directly to caller-owned storage. BLETransport uses this to
    /// encode into its persistent priority queue, avoiding a temporary `[Data]` allocation and
    /// a second array traversal for every encrypted envelope or attachment chunk.
    @discardableResult
    static func appendEncodedPackets(
        _ data: Data,
        maximumPacketSize: Int,
        to packets: inout [Data]
    ) -> (fragmentCount: Int, encodedByteCount: Int)? {
        guard let plan = fragmentationPlan(payloadByteCount: data.count, maximumPacketSize: maximumPacketSize) else { return nil }
        let chunkSize = maximumPacketSize - headerSize
        let count = plan.fragmentCount
        let frameID = UInt64.random(in: 1...UInt64.max)
        packets.reserveCapacity(packets.count + count)

        for index in 0..<count {
            let start = min(index * chunkSize, data.count)
            let end = min(start + chunkSize, data.count)
            var packet = Data(capacity: headerSize + end - start)
            packet.append(contentsOf: [0x56, 0x02])
            var bigFrameID = frameID.bigEndian
            var bigIndex = UInt16(index).bigEndian
            var bigTotal = UInt16(count).bigEndian
            withUnsafeBytes(of: &bigFrameID) { packet.append(contentsOf: $0) }
            withUnsafeBytes(of: &bigIndex) { packet.append(contentsOf: $0) }
            withUnsafeBytes(of: &bigTotal) { packet.append(contentsOf: $0) }
            packet.append(contentsOf: data[start..<end])
            packets.append(packet)
        }
        return plan
    }


}

final class BLEFragmentAssembler {
    private struct PartialKey: Hashable {
        let source: UUID
        let frameID: UInt64
    }

    private struct Partial {
        let createdAt: Date
        let source: UUID
        let total: UInt16
        var chunks: [UInt16: Data]
        var byteCount: Int
    }

    private var partials: [PartialKey: Partial] = [:]
    private var partialCountBySource: [UUID: Int] = [:]
    private var totalBufferedBytes = 0
    private var nextPruneAt: TimeInterval = 0
    private let maxConcurrentMessages: Int
    private let maxConcurrentMessagesPerSource: Int
    private let maxFragmentsPerMessage: Int
    private let maxAssembledBytes: Int
    private let maxPacketBytes: Int
    private let maxTotalBufferedBytes: Int
    private let staleAfter: TimeInterval

    init(
        maxConcurrentMessages: Int = 64,
        maxConcurrentMessagesPerSource: Int = 8,
        maxFragmentsPerMessage: Int = 16_384,
        maxAssembledBytes: Int = 2_000_000,
        maxPacketBytes: Int = 1_024,
        maxTotalBufferedBytes: Int = 8_000_000,
        staleAfter: TimeInterval = 120
    ) {
        self.maxConcurrentMessages = max(1, maxConcurrentMessages)
        self.maxConcurrentMessagesPerSource = max(1, min(maxConcurrentMessagesPerSource, self.maxConcurrentMessages))
        self.maxFragmentsPerMessage = max(1, min(maxFragmentsPerMessage, Int(UInt16.max)))
        self.maxAssembledBytes = max(1, maxAssembledBytes)
        self.maxPacketBytes = max(BLEFragment.headerSize + 1, maxPacketBytes)
        self.maxTotalBufferedBytes = max(self.maxAssembledBytes, maxTotalBufferedBytes)
        self.staleAfter = max(1, staleAfter)
    }

    func ingest(source: UUID, packet: Data) -> Data? {
        pruneIfNeeded()
        guard packet.count <= maxPacketBytes,
              let fragment = BLEFragment(data: packet),
              fragment.frameID != 0,
              fragment.total > 0,
              Int(fragment.total) <= maxFragmentsPerMessage,
              fragment.index < fragment.total,
              !(fragment.payload.isEmpty && fragment.total > 1),
              fragment.payload.count <= maxAssembledBytes else { return nil }

        let key = PartialKey(source: source, frameID: fragment.frameID)
        if partials[key] == nil {
            while partials.count >= maxConcurrentMessages { evictOldestPartial() }
            while (partialCountBySource[source] ?? 0) >= maxConcurrentMessagesPerSource {
                evictOldestPartial(from: source)
            }
        }

        let isNewPartial = partials[key] == nil
        var partial = partials[key] ?? Partial(
            createdAt: Date(),
            source: source,
            total: fragment.total,
            chunks: [:],
            byteCount: 0
        )
        guard partial.total == fragment.total else {
            removePartial(forKey: key)
            return nil
        }

        if let existing = partial.chunks[fragment.index] {
            guard existing == fragment.payload else {
                removePartial(forKey: key)
                return nil
            }
        } else {
            let nextByteCount = partial.byteCount + fragment.payload.count
            guard nextByteCount <= maxAssembledBytes else {
                removePartial(forKey: key)
                return nil
            }
            guard makeRoomForBufferedBytes(fragment.payload.count, protecting: key) else {
                removePartial(forKey: key)
                return nil
            }
            partial.chunks[fragment.index] = fragment.payload
            partial.byteCount = nextByteCount
            totalBufferedBytes += fragment.payload.count
        }
        partials[key] = partial
        if isNewPartial { partialCountBySource[source, default: 0] += 1 }

        guard partial.chunks.count == Int(partial.total) else { return nil }
        var output = Data()
        output.reserveCapacity(partial.byteCount)
        for index in 0..<partial.total {
            guard let chunk = partial.chunks[index] else { return nil }
            output.append(chunk)
        }
        removePartial(forKey: key)
        return output
    }

    private func pruneIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now >= nextPruneAt else { return }
        nextPruneAt = now + min(5, max(1, staleAfter / 4))
        let cutoff = Date(timeIntervalSinceReferenceDate: now - staleAfter)
        let staleKeys = partials.compactMap { $0.value.createdAt <= cutoff ? $0.key : nil }
        staleKeys.forEach { removePartial(forKey: $0) }
    }

    private func makeRoomForBufferedBytes(_ additionalBytes: Int, protecting key: PartialKey) -> Bool {
        guard additionalBytes <= maxTotalBufferedBytes else { return false }
        while totalBufferedBytes + additionalBytes > maxTotalBufferedBytes {
            guard let oldest = partials
                .filter({ $0.key != key })
                .min(by: { $0.value.createdAt < $1.value.createdAt })?.key else {
                return false
            }
            removePartial(forKey: oldest)
        }
        return true
    }

    private func removePartial(forKey key: PartialKey) {
        guard let removed = partials.removeValue(forKey: key) else { return }
        totalBufferedBytes = max(0, totalBufferedBytes - removed.byteCount)
        let nextCount = max(0, (partialCountBySource[removed.source] ?? 1) - 1)
        if nextCount == 0 {
            partialCountBySource.removeValue(forKey: removed.source)
        } else {
            partialCountBySource[removed.source] = nextCount
        }
    }

    private func evictOldestPartial() {
        guard let oldest = partials.min(by: { $0.value.createdAt < $1.value.createdAt })?.key else { return }
        removePartial(forKey: oldest)
    }

    private func evictOldestPartial(from source: UUID) {
        guard let oldest = partials
            .filter({ $0.value.source == source })
            .min(by: { $0.value.createdAt < $1.value.createdAt })?.key else { return }
        removePartial(forKey: oldest)
    }
}
