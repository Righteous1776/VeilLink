import AVFoundation
import Combine
import CoreBluetooth
import Foundation

struct BLEQueueAdmissionPolicy {
    private static func reservedCapacity(
        priority: BLESendPriority,
        maximumPackets: Int,
        maximumBytes: Int
    ) -> (packets: Int, bytes: Int) {
        guard priority != .control else { return (0, 0) }
        return (
            min(512, max(0, maximumPackets) / 8),
            min(96 * 1_024, max(0, maximumBytes) / 8)
        )
    }

    static func canEnqueue(
        pendingPackets: Int,
        pendingBytes: Int,
        additionalPackets: Int,
        additionalBytes: Int,
        priority: BLESendPriority,
        maximumPackets: Int,
        maximumBytes: Int
    ) -> Bool {
        guard pendingPackets >= 0,
              pendingBytes >= 0,
              additionalPackets >= 0,
              additionalBytes >= 0 else { return false }
        let reserve = reservedCapacity(
            priority: priority,
            maximumPackets: maximumPackets,
            maximumBytes: maximumBytes
        )
        let packetLimit = max(0, maximumPackets - reserve.packets)
        let byteLimit = max(0, maximumBytes - reserve.bytes)
        let (nextPackets, packetOverflow) = pendingPackets.addingReportingOverflow(additionalPackets)
        let (nextBytes, byteOverflow) = pendingBytes.addingReportingOverflow(additionalBytes)
        return !packetOverflow
            && !byteOverflow
            && nextPackets <= packetLimit
            && nextBytes <= byteLimit
    }
}

enum BLEQueueDirection {
    case central
    case peripheral
}

struct BLEQueueProgressState {
    private var central: [UUID: TimeInterval] = [:]
    private var peripheral: [UUID: TimeInterval] = [:]

    mutating func beginIfNeeded(_ direction: BLEQueueDirection, peerID: UUID, at timestamp: TimeInterval) {
        switch direction {
        case .central:
            if central[peerID] == nil { central[peerID] = timestamp }
        case .peripheral:
            if peripheral[peerID] == nil { peripheral[peerID] = timestamp }
        }
    }

    mutating func recordProgress(_ direction: BLEQueueDirection, peerID: UUID, at timestamp: TimeInterval) {
        switch direction {
        case .central: central[peerID] = timestamp
        case .peripheral: peripheral[peerID] = timestamp
        }
    }

    func lastProgress(_ direction: BLEQueueDirection, peerID: UUID) -> TimeInterval? {
        switch direction {
        case .central: return central[peerID]
        case .peripheral: return peripheral[peerID]
        }
    }

    func stalledDuration(
        peerID: UUID,
        centralPending: Bool,
        peripheralPending: Bool,
        now: TimeInterval
    ) -> TimeInterval? {
        var durations: [TimeInterval] = []
        if centralPending, let timestamp = central[peerID] {
            durations.append(max(0, now - timestamp))
        }
        if peripheralPending, let timestamp = peripheral[peerID] {
            durations.append(max(0, now - timestamp))
        }
        return durations.max()
    }

    mutating func clear(_ direction: BLEQueueDirection, peerID: UUID) {
        switch direction {
        case .central: central.removeValue(forKey: peerID)
        case .peripheral: peripheral.removeValue(forKey: peerID)
        }
    }

    mutating func clear(peerID: UUID) {
        central.removeValue(forKey: peerID)
        peripheral.removeValue(forKey: peerID)
    }

    mutating func clearAll() {
        central.removeAll(keepingCapacity: false)
        peripheral.removeAll(keepingCapacity: false)
    }
}

struct OutboundPacketQueue {
    private var packets: [Data] = []
    private var head = 0
    private var queuedBytes = 0

    var pendingCount: Int { packets.count - head }
    var pendingBytes: Int { queuedBytes }
    var first: Data? { head < packets.count ? packets[head] : nil }
    var isEmpty: Bool { pendingCount == 0 }

    @discardableResult
    mutating func appendEncodedPayload(_ data: Data, maximumPacketSize: Int) -> Bool {
        if head > 0 && (head >= 256 || head * 2 >= packets.count) {
            packets.removeFirst(head)
            head = 0
        }
        guard let plan = BLEFragment.appendEncodedPackets(
            data,
            maximumPacketSize: maximumPacketSize,
            to: &packets
        ) else { return false }
        queuedBytes += plan.encodedByteCount
        return true
    }

    @discardableResult
    mutating func removeFirst() -> Data? {
        guard head < packets.count else { return nil }
        let value = packets[head]
        queuedBytes -= value.count
        head += 1
        if head == packets.count {
            packets.removeAll(keepingCapacity: true)
            head = 0
            queuedBytes = 0
        }
        return value
    }
}

private struct PeerOutboundQueue {
    private var control = OutboundPacketQueue()
    private var realtime = OutboundPacketQueue()
    private var bulk = OutboundPacketQueue()

    var pendingCount: Int { control.pendingCount + realtime.pendingCount + bulk.pendingCount }
    var pendingBytes: Int { control.pendingBytes + realtime.pendingBytes + bulk.pendingBytes }
    var controlPendingCount: Int { control.pendingCount }
    var realtimePendingCount: Int { realtime.pendingCount }
    var isEmpty: Bool { control.isEmpty && realtime.isEmpty && bulk.isEmpty }

    @discardableResult
    mutating func appendEncodedPayload(
        _ data: Data,
        maximumPacketSize: Int,
        priority: BLESendPriority
    ) -> Bool {
        switch priority {
        case .control:
            return control.appendEncodedPayload(data, maximumPacketSize: maximumPacketSize)
        case .realtime:
            return realtime.appendEncodedPayload(data, maximumPacketSize: maximumPacketSize)
        case .bulk:
            return bulk.appendEncodedPayload(data, maximumPacketSize: maximumPacketSize)
        }
    }

    mutating func removeFirst() -> Data? {
        if let packet = control.removeFirst() { return packet }
        if let packet = realtime.removeFirst() { return packet }
        return bulk.removeFirst()
    }

    var first: Data? { control.first ?? realtime.first ?? bulk.first }
}

/// Audio routing does not create independent Bluetooth radio channels.
/// Reduce optional scan/RSSI work during HFP/A2DP/LE headset activity while
/// preserving CoreBluetooth's authenticated connections and queue watchdog.
enum BLEAudioCoexistencePolicy {
    static func allowsDuplicateDiscoveries(foreground: Bool, bluetoothAudioActive: Bool) -> Bool {
        foreground && !bluetoothAudioActive
    }

    static func shouldPollRSSI(
        foreground: Bool, bluetoothAudioActive: Bool,
        elapsed: TimeInterval, interval: TimeInterval
    ) -> Bool {
        foreground && !bluetoothAudioActive && elapsed >= interval
    }
}

@MainActor
final class BLETransport: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "5D0F88D4-21A2-4DC4-A1E8-A2DF8C9AC001")
    static let dataUUID = CBUUID(string: "5D0F88D4-21A2-4DC4-A1E8-A2DF8C9AC002")

    @Published private(set) var statusText = "正在初始化蓝牙"
    @Published private(set) var isRunning = false
    @Published private(set) var discoveredRSSI: [UUID: Int] = [:]
    @Published private(set) var connectedPeerCount = 0
    @Published private(set) var linkSnapshots: [UUID: BLEPeerLinkSnapshot] = [:]

    var onDiscovered: ((UUID, Int) -> Void)?
    var onConnected: ((UUID) -> Void)?
    var onDisconnected: ((UUID) -> Void)?
    var onReceive: ((UUID, Data) -> Void)?

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var localCharacteristic: CBMutableCharacteristic?
    private var remotePeripherals: [UUID: CBPeripheral] = [:]
    private var remoteCharacteristics: [UUID: CBCharacteristic] = [:]
    private var subscribedCentrals: [UUID: CBCentral] = [:]
    private var peripheralOutboundQueues: [UUID: PeerOutboundQueue] = [:]
    private var centralOutboundQueues: [UUID: PeerOutboundQueue] = [:]
    private var wantedConnections: Set<UUID> = []
    private var reconnectAttempts: [UUID: Int] = [:]
    private var reconnectStableSinceUptime: [UUID: TimeInterval] = [:]
    private var reconnectWorkItems: [UUID: DispatchWorkItem] = [:]
    private var centralDrainWorkItems: [UUID: DispatchWorkItem] = [:]
    private var peripheralDrainWorkItems: [UUID: DispatchWorkItem] = [:]
    private var smoothedRSSI: [UUID: Double] = [:]
    private var lastRSSIPublishAt: [UUID: TimeInterval] = [:]
    private var lastSeenAt: [UUID: TimeInterval] = [:]
    private var queueProgress = BLEQueueProgressState()
    private var centralStallProbeAt: [UUID: TimeInterval] = [:]
    private var peripheralStallProbeAt: [UUID: TimeInterval] = [:]
    private var gattHandshakeWatchdog = BLEGattHandshakeWatchdog()
    private var rssiPollTask: Task<Void, Never>?
    private var lastRSSIMaintenanceAt: TimeInterval = 0
    private var connectionEvents = ConnectionEventGate()
    private var foregroundActive = true
    private var bluetoothAudioActive = false
    private var lastScanAllowsDuplicates: Bool?
    private var audioRouteSubscription: AnyCancellable?
    private var linkSnapshotRefreshWorkItem: DispatchWorkItem?
    private var lastLinkSnapshotPublishAt: TimeInterval = 0
    private var lastQueuePressureUptime: TimeInterval = -100

    private func flight(_ phase: String, id: UUID? = nil,
                        values: [String: Int] = [:], level: DiagnosticLogLevel = .debug) {
        var fields: [String: String] = ["payload_recorded": "false"]
        if let id { fields["transport_id"] = id.uuidString }
        for (key, value) in values { fields[key] = String(value) }
        DiagnosticLogStore.shared.log(level, .bluetooth, event: "ble.flight." + phase, metadata: fields)
    }

    private func reportQueuePressure(id: UUID, bytes: Int, packets: Int, pending: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastQueuePressureUptime >= 5 else { return }
        lastQueuePressureUptime = now
        flight("queue_pressure", id: id,
               values: ["payload_bytes": bytes, "pending_packets": packets, "pending_bytes": pending],
               level: .warning)
    }

    private let maxFragmentsPerMessage = 16_384
    private let passiveDiscoveryRetention: TimeInterval = 15
    private let performanceProfile: DevicePerformanceProfile
    private let maintenanceTuning: VeilRuntimeMaintenanceTuning
    private let assembler: BLEFragmentAssembler
    private let connectionIntentStore: BLEConnectionIntentStore

    private var maxQueuedPacketsPerPeer: Int { performanceProfile.bleQueuePacketLimit }
    private var maxQueuedBytesPerPeer: Int { performanceProfile.bleQueueByteLimit }

    override init() {
        let profile = VeilDevicePerformance.current
        let intentStore = BLEConnectionIntentStore()
        connectionIntentStore = intentStore
        wantedConnections = intentStore.load()
        performanceProfile = profile
        maintenanceTuning = VeilRuntimeMaintenanceTuning.resolved(performanceLabel: profile.label)
        // Protocol 4 envelopes remain capped at 96 KB. The total in-flight reassembly budget is
        // device-specific so SE1/7 do not reserve the same memory as an iPhone 13 Pro.
        assembler = BLEFragmentAssembler(
            maxConcurrentMessages: profile.bleReassemblyMessageLimit,
            maxConcurrentMessagesPerSource: profile.bleReassemblyPerSourceLimit,
            maxFragmentsPerMessage: 16_384,
            maxAssembledBytes: 96_000,
            maxTotalBufferedBytes: profile.bleReassemblyByteLimit
        )
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "VeilLink.Central.v2"]
        )
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [CBPeripheralManagerOptionRestoreIdentifierKey: "VeilLink.Peripheral.v2"]
        )
        audioRouteSubscription = NotificationCenter.default.publisher(
            for: AVAudioSession.routeChangeNotification
        ).sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshBluetoothAudioRoute() }
        }
        refreshBluetoothAudioRoute()
    }

    private func refreshBluetoothAudioRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        let active = (route.inputs + route.outputs).contains { port in
            switch port.portType {
            case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE: return true
            default: return false
            }
        }
        guard bluetoothAudioActive != active else { return }
        bluetoothAudioActive = active
        if isRunning { beginScanningIfPossible() }
    }

    func start() {
        flight("start", level: .info)
        isRunning = true
        refreshBluetoothAudioRoute()
        startRSSIPolling()
        beginScanningIfPossible()
        beginAdvertisingIfPossible()
        restoreWantedPeripheralsIfPossible()
        publishLinkSnapshots(force: true)
    }

    func setForegroundActive(_ active: Bool) {
        foregroundActive = active
        guard isRunning else { return }
        // Keep UUID-filtered background discovery, but allow the OS to coalesce
        // repeated advertisements rather than consuming audio/radio airtime.
        beginScanningIfPossible()
        if active { refreshBluetoothAudioRoute(); refreshLinks() }
    }

    func refreshLinks() {
        guard isRunning else {
            start()
            return
        }
        beginScanningIfPossible()
        beginAdvertisingIfPossible()
        if BLELinkReliabilityPolicy.shouldForegroundRestore(
            isRunning: isRunning,
            foreground: foregroundActive,
            wantedCount: wantedConnections.count
        ) {
            // A background/foreground transition does not necessarily cause
            // a new CBCentralManager state update. Rehydrate only disconnected
            // wanted peers; don't reissue discoverServices on a live GATT link.
            restoreWantedPeripheralsIfPossible(reconnectDisconnectedOnly: true)
        }
        recoverStalledTransportQueuesIfNeeded()
        if foregroundActive && !bluetoothAudioActive {
            for peripheral in remotePeripherals.values where peripheral.state == .connected {
                peripheral.readRSSI()
            }
        }
        publishLinkSnapshots(force: true)
    }

    func stop(preserveConnectionIntent: Bool = false) {
        isRunning = false
        centralManager.stopScan()
        lastScanAllowsDuplicates = nil
        peripheralManager.stopAdvertising()
        for peripheral in remotePeripherals.values where peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        if !preserveConnectionIntent {
            wantedConnections.removeAll()
            connectionIntentStore.clear()
        }
        reconnectAttempts.removeAll()
        reconnectStableSinceUptime.removeAll()
        reconnectWorkItems.values.forEach { $0.cancel() }
        reconnectWorkItems.removeAll()
        centralDrainWorkItems.values.forEach { $0.cancel() }
        centralDrainWorkItems.removeAll()
        peripheralDrainWorkItems.values.forEach { $0.cancel() }
        peripheralDrainWorkItems.removeAll()
        rssiPollTask?.cancel()
        rssiPollTask = nil
        assembler.resetAll()
        remotePeripherals.removeAll(keepingCapacity: false)
        subscribedCentrals.removeAll(keepingCapacity: false)
        discoveredRSSI.removeAll(keepingCapacity: false)
        smoothedRSSI.removeAll(keepingCapacity: false)
        lastRSSIPublishAt.removeAll(keepingCapacity: false)
        lastSeenAt.removeAll(keepingCapacity: false)

        connectionEvents.drainConnectedIDs().forEach { onDisconnected?($0) }
        connectedPeerCount = 0
        remoteCharacteristics.removeAll()
        centralOutboundQueues.removeAll()
        peripheralOutboundQueues.removeAll()
        queueProgress.clearAll()
        centralStallProbeAt.removeAll()
        peripheralStallProbeAt.removeAll()
        gattHandshakeWatchdog.resetAll()
        statusText = "蓝牙发现已暂停"
        publishLinkSnapshots(force: true)
    }

    func disconnect(_ id: UUID) {
        flight("disconnect_requested", id: id, level: .info)
        if wantedConnections.remove(id) != nil {
            connectionIntentStore.save(wantedConnections)
        }
        tearDownTransportState(for: id)
        if let peripheral = remotePeripherals[id], peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        _ = subscribedCentrals.removeValue(forKey: id)
        publishDisconnected(id)
        publishLinkSnapshots(force: true)
    }

    /// Drops the current link while preserving the user's intent to stay connected.
    /// Used by the security/session watchdog when a connection becomes stale.
    func recover(_ id: UUID) {
        flight("recover_requested", id: id, level: .warning)
        if wantedConnections.insert(id).inserted {
            connectionIntentStore.save(wantedConnections)
        }
        resetReconnectAttemptIfStable(id, nowUptime: ProcessInfo.processInfo.systemUptime)
        tearDownTransportState(for: id, keepReconnectAttempt: true)
        if let peripheral = remotePeripherals[id] {
            if peripheral.state == .connected || peripheral.state == .connecting {
                centralManager.cancelPeripheralConnection(peripheral)
            } else if peripheral.state == .disconnected {
                scheduleReconnect(peripheral, immediate: true)
            }
        }
        publishDisconnected(id)
        publishLinkSnapshots(force: true)
    }

    private func tearDownTransportState(for id: UUID, keepReconnectAttempt: Bool = false) {
        if !keepReconnectAttempt { reconnectAttempts.removeValue(forKey: id) }
        reconnectStableSinceUptime.removeValue(forKey: id)
        reconnectWorkItems.removeValue(forKey: id)?.cancel()
        centralDrainWorkItems.removeValue(forKey: id)?.cancel()
        peripheralDrainWorkItems.removeValue(forKey: id)?.cancel()
        centralOutboundQueues.removeValue(forKey: id)
        peripheralOutboundQueues.removeValue(forKey: id)
        remoteCharacteristics.removeValue(forKey: id)
        queueProgress.clear(peerID: id)
        centralStallProbeAt.removeValue(forKey: id)
        peripheralStallProbeAt.removeValue(forKey: id)
        gattHandshakeWatchdog.disconnected(id)
        assembler.reset(source: id)
    }

    func connect(to id: UUID) {
        flight("connect_requested", id: id, level: .info)
        if wantedConnections.insert(id).inserted {
            connectionIntentStore.save(wantedConnections)
        }
        reconnectAttempts[id] = 0
        reconnectStableSinceUptime.removeValue(forKey: id)
        reconnectWorkItems.removeValue(forKey: id)?.cancel()
        guard isRunning,
              let peripheral = remotePeripherals[id],
              peripheral.state == .disconnected else { return }
        centralManager.connect(
            peripheral,
            options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
        )
        publishLinkSnapshots()
    }

    func linkSnapshot(for id: UUID) -> BLEPeerLinkSnapshot? {
        guard knownLinkIDs().contains(id) else { return nil }
        return makeLinkSnapshot(for: id)
    }

    func transportStage(for id: UUID) -> BLETransportStage {
        makeLinkSnapshot(for: id).transportStage
    }

    func diagnosticsReport() -> String {
        BLELinkDiagnosticsFormatter.report(
            generatedAt: Date(),
            isRunning: isRunning,
            statusText: statusText,
            connectedPeerCount: connectedPeerCount,
            snapshots: knownLinkIDs().map(makeLinkSnapshot(for:))
        )
    }

    @discardableResult
    func send(_ data: Data, to transportID: UUID, priority: BLESendPriority = .bulk) -> TransportSendResult {
        if let peripheral = remotePeripherals[transportID],
           let characteristic = remoteCharacteristics[transportID],
           peripheral.state == .connected,
           characteristic.isNotifying {
            let maximum = peripheral.maximumWriteValueLength(for: .withoutResponse)
            guard let plan = BLEFragment.fragmentationPlan(payloadByteCount: data.count, maximumPacketSize: maximum),
                  plan.fragmentCount <= maxFragmentsPerMessage else { return .unsupportedLink }
            let existing = centralOutboundQueues[transportID]
            guard BLEQueueAdmissionPolicy.canEnqueue(
                pendingPackets: existing?.pendingCount ?? 0,
                pendingBytes: existing?.pendingBytes ?? 0,
                additionalPackets: plan.fragmentCount,
                additionalBytes: plan.encodedByteCount,
                priority: priority,
                maximumPackets: maxQueuedPacketsPerPeer,
                maximumBytes: maxQueuedBytesPerPeer
            ) else {
                reportQueuePressure(id: transportID, bytes: data.count,
                                    packets: existing?.pendingCount ?? 0,
                                    pending: existing?.pendingBytes ?? 0)
                return .temporarilyUnavailable
            }
            guard centralOutboundQueues[transportID, default: PeerOutboundQueue()].appendEncodedPayload(
                data,
                maximumPacketSize: maximum,
                priority: priority
            ) else { return .unsupportedLink }
            queueProgress.beginIfNeeded(
                .central,
                peerID: transportID,
                at: Date().timeIntervalSinceReferenceDate
            )
            drainCentralQueue(peripheral: peripheral, characteristic: characteristic)
            return .accepted
        }

        guard let central = subscribedCentrals[transportID],
              let localCharacteristic else { return .temporarilyUnavailable }
        let maximum = central.maximumUpdateValueLength
        guard let plan = BLEFragment.fragmentationPlan(payloadByteCount: data.count, maximumPacketSize: maximum),
              plan.fragmentCount <= maxFragmentsPerMessage else { return .unsupportedLink }
        let existing = peripheralOutboundQueues[transportID]
        guard BLEQueueAdmissionPolicy.canEnqueue(
            pendingPackets: existing?.pendingCount ?? 0,
            pendingBytes: existing?.pendingBytes ?? 0,
            additionalPackets: plan.fragmentCount,
            additionalBytes: plan.encodedByteCount,
            priority: priority,
            maximumPackets: maxQueuedPacketsPerPeer,
            maximumBytes: maxQueuedBytesPerPeer
        ) else {
            reportQueuePressure(id: transportID, bytes: data.count,
                                packets: existing?.pendingCount ?? 0,
                                pending: existing?.pendingBytes ?? 0)
            return .temporarilyUnavailable
        }
        guard peripheralOutboundQueues[transportID, default: PeerOutboundQueue()].appendEncodedPayload(
            data,
            maximumPacketSize: maximum,
            priority: priority
        ) else { return .unsupportedLink }
        queueProgress.beginIfNeeded(
            .peripheral,
            peerID: transportID,
            at: Date().timeIntervalSinceReferenceDate
        )
        drainPeripheralQueue(for: transportID, characteristic: localCharacteristic)
        return .accepted
    }

    private func drainCentralQueue(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let id = peripheral.identifier
        centralDrainWorkItems.removeValue(forKey: id)?.cancel()
        guard var queue = centralOutboundQueues[id] else { return }
        let tuning = linkTuning(for: id)
        let burstLimit = VeilConcurrentFabricPolicy.bleDrainBurst(
            configuredLimit: tuning.packetBurstLimit,
            realtimePending: queue.realtimePendingCount > 0
        )
        var sent = 0
        while sent < burstLimit, peripheral.canSendWriteWithoutResponse, let packet = queue.removeFirst() {
            peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
            sent += 1
            queueProgress.recordProgress(.central, peerID: id, at: Date().timeIntervalSinceReferenceDate)
        }
        if queue.isEmpty {
            centralOutboundQueues.removeValue(forKey: id)
            centralStallProbeAt.removeValue(forKey: id)
            queueProgress.clear(.central, peerID: id)
        } else {
            centralOutboundQueues[id] = queue
            // `peripheralIsReady` is the primary CoreBluetooth resume signal. Keep one bounded
            // safety probe as well so a missed callback cannot strand the queue forever.
            let retryDelay = peripheral.canSendWriteWithoutResponse
                ? tuning.interBurstDelay
                : max(0.15, tuning.interBurstDelay)
            scheduleCentralDrain(for: id, after: retryDelay)
        }
    }

    private func drainPeripheralQueue(for centralID: UUID, characteristic: CBMutableCharacteristic) {
        peripheralDrainWorkItems.removeValue(forKey: centralID)?.cancel()
        guard let central = subscribedCentrals[centralID] else {
            peripheralOutboundQueues.removeValue(forKey: centralID)
            return
        }
        guard var queue = peripheralOutboundQueues[centralID] else { return }
        let tuning = linkTuning(for: centralID)
        let burstLimit = VeilConcurrentFabricPolicy.bleDrainBurst(
            configuredLimit: tuning.packetBurstLimit,
            realtimePending: queue.realtimePendingCount > 0
        )
        var sent = 0
        while sent < burstLimit, let packet = queue.first {
            guard peripheralManager.updateValue(packet, for: characteristic, onSubscribedCentrals: [central]) else {
                peripheralOutboundQueues[centralID] = queue
                // Ready callback is primary; the bounded fallback prevents a lost
                // callback from stranding the existing data indefinitely.
                schedulePeripheralDrain(for: centralID, after: max(0.4, tuning.interBurstDelay))
                return
            }
            _ = queue.removeFirst()
            sent += 1
            queueProgress.recordProgress(.peripheral, peerID: centralID, at: Date().timeIntervalSinceReferenceDate)
        }
        if queue.isEmpty {
            peripheralOutboundQueues.removeValue(forKey: centralID)
            peripheralStallProbeAt.removeValue(forKey: centralID)
            queueProgress.clear(.peripheral, peerID: centralID)
        } else {
            peripheralOutboundQueues[centralID] = queue
            schedulePeripheralDrain(for: centralID, after: tuning.interBurstDelay)
        }
        if sent > 0 || queue.isEmpty { publishLinkSnapshots() }
    }

    private func knownLinkIDs() -> Set<UUID> {
        let now = Date().timeIntervalSinceReferenceDate
        pruneStaleDiscoveryState(now: now)

        let recentDiscovered = Set(lastSeenAt.compactMap { entry in
            now - entry.value <= passiveDiscoveryRetention ? entry.key : nil
        })
        let liveRemote = Set(remotePeripherals.compactMap { entry -> UUID? in
            let state = entry.value.state
            if state == .connected || state == .connecting || wantedConnections.contains(entry.key) {
                return entry.key
            }
            return recentDiscovered.contains(entry.key) ? entry.key : nil
        })

        return liveRemote
            .union(subscribedCentrals.keys)
            .union(wantedConnections)
            .union(centralOutboundQueues.keys)
            .union(peripheralOutboundQueues.keys)
            .union(recentDiscovered)
    }

    private func pruneStaleDiscoveryState(now: TimeInterval) {
        let protectedIDs = Set(subscribedCentrals.keys)
            .union(wantedConnections)
            .union(centralOutboundQueues.keys)
            .union(peripheralOutboundQueues.keys)

        let staleIDs = lastSeenAt.compactMap { entry -> UUID? in
            guard now - entry.value > passiveDiscoveryRetention,
                  !protectedIDs.contains(entry.key) else { return nil }
            if let peripheral = remotePeripherals[entry.key],
               peripheral.state == .connected || peripheral.state == .connecting {
                return nil
            }
            return entry.key
        }

        for id in staleIDs {
            lastSeenAt.removeValue(forKey: id)
            discoveredRSSI.removeValue(forKey: id)
            smoothedRSSI.removeValue(forKey: id)
            lastRSSIPublishAt.removeValue(forKey: id)
            reconnectAttempts.removeValue(forKey: id)
            reconnectStableSinceUptime.removeValue(forKey: id)
            if remotePeripherals[id]?.state == .disconnected {
                remotePeripherals.removeValue(forKey: id)
            }
        }
    }

    private func makeLinkSnapshot(for id: UUID) -> BLEPeerLinkSnapshot {
        let physicalCentralConnected = isRunning && remotePeripherals[id]?.state == .connected
        let centralReady = physicalCentralConnected && remoteCharacteristics[id]?.isNotifying == true
        let peripheralReady = isRunning && subscribedCentrals[id] != nil
        let transportStage: BLETransportStage
        if centralReady || peripheralReady { transportStage = .gattReady }
        else if physicalCentralConnected { transportStage = .phyConnected }
        else if knownLinkIDs().contains(id) { transportStage = .discovered }
        else { transportStage = .unavailable }
        let role: BLEPeerLinkRole
        switch (centralReady, peripheralReady) {
        case (true, true): role = .dual
        case (true, false): role = .central
        case (false, true): role = .peripheral
        case (false, false): role = .unavailable
        }
        let centralQueue = centralOutboundQueues[id]
        let peripheralQueue = peripheralOutboundQueues[id]
        let pendingPackets = (centralQueue?.pendingCount ?? 0) + (peripheralQueue?.pendingCount ?? 0)
        let pendingBytes = (centralQueue?.pendingBytes ?? 0) + (peripheralQueue?.pendingBytes ?? 0)
        let controlPending = (centralQueue?.controlPendingCount ?? 0) + (peripheralQueue?.controlPendingCount ?? 0)
        var packetSizes: [Int] = []
        if let peripheral = remotePeripherals[id], peripheral.state == .connected {
            packetSizes.append(peripheral.maximumWriteValueLength(for: .withoutResponse))
        }
        if let central = subscribedCentrals[id] { packetSizes.append(central.maximumUpdateValueLength) }
        let rssi = smoothedRSSI[id].map { Int($0.rounded()) } ?? discoveredRSSI[id]
        let stalledFor = queueProgress.stalledDuration(
            peerID: id,
            centralPending: centralQueue?.isEmpty == false,
            peripheralPending: peripheralQueue?.isEmpty == false,
            now: Date().timeIntervalSinceReferenceDate
        )
        return BLEPeerLinkSnapshot(
            id: id,
            isConnected: centralReady || peripheralReady,
            isWanted: wantedConnections.contains(id),
            reconnectAttempt: reconnectAttempts[id] ?? 0,
            rssi: rssi,
            quality: BLELinkReliabilityPolicy.quality(rssi: rssi),
            pendingPackets: pendingPackets,
            pendingBytes: pendingBytes,
            controlPendingPackets: controlPending,
            maximumPacketSize: packetSizes.max(),
            role: role,
            transportStage: transportStage,
            stalledFor: stalledFor
        )
    }

    private func publishLinkSnapshots(force: Bool = false) {
        let now = Date().timeIntervalSinceReferenceDate
        let minimumInterval: TimeInterval = 0.35
        let remaining = minimumInterval - (now - lastLinkSnapshotPublishAt)
        if !force, remaining > 0 {
            guard linkSnapshotRefreshWorkItem == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.linkSnapshotRefreshWorkItem = nil
                self.publishLinkSnapshots(force: true)
            }
            linkSnapshotRefreshWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
            return
        }
        linkSnapshotRefreshWorkItem?.cancel()
        linkSnapshotRefreshWorkItem = nil
        lastLinkSnapshotPublishAt = now
        linkSnapshots = Dictionary(uniqueKeysWithValues: knownLinkIDs().map { ($0, makeLinkSnapshot(for: $0)) })
    }

    private func linkTuning(for id: UUID) -> BLELinkTuning {
        BLELinkReliabilityPolicy.tuning(
            rssi: smoothedRSSI[id].map { Int($0.rounded()) } ?? discoveredRSSI[id],
            machineIdentifier: VeilDevicePerformance.machineIdentifier
        )
    }

    private func scheduleCentralDrain(for id: UUID, after delay: TimeInterval) {
        guard centralDrainWorkItems[id] == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.centralDrainWorkItems.removeValue(forKey: id)
            guard self.isRunning,
                  let peripheral = self.remotePeripherals[id],
                  peripheral.state == .connected,
                  let characteristic = self.remoteCharacteristics[id],
                  characteristic.isNotifying else { return }
            self.drainCentralQueue(peripheral: peripheral, characteristic: characteristic)
        }
        centralDrainWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
    }

    private func schedulePeripheralDrain(for id: UUID, after delay: TimeInterval) {
        guard peripheralDrainWorkItems[id] == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.peripheralDrainWorkItems.removeValue(forKey: id)
            guard self.isRunning, let characteristic = self.localCharacteristic else { return }
            self.drainPeripheralQueue(for: id, characteristic: characteristic)
        }
        peripheralDrainWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
    }

    private func hasReadyDataChannel(_ id: UUID) -> Bool {
        let centralReady = isRunning
            && remotePeripherals[id]?.state == .connected
            && remoteCharacteristics[id]?.isNotifying == true
        let peripheralReady = isRunning && subscribedCentrals[id] != nil
        return centralReady || peripheralReady
    }

    private func reconcileConnectionEvent(_ id: UUID) {
        if hasReadyDataChannel(id) { publishConnected(id) }
        else { publishDisconnected(id) }
    }

    private func publishConnected(_ id: UUID) {
        let firstConnectionEvent = connectionEvents.markConnected(id)
        connectedPeerCount = connectionEvents.count
        statusText = "蓝牙数据通道已就绪"
        publishLinkSnapshots(force: true)
        if firstConnectionEvent {
            flight("data_ready", id: id, level: .info)
            onConnected?(id)
        }
    }

    private func publishDisconnected(_ id: UUID) {
        let didDisconnect = connectionEvents.markDisconnected(id)
        connectedPeerCount = connectionEvents.count
        publishLinkSnapshots(force: true)
        if didDisconnect {
            flight("data_disconnected", id: id, level: .warning)
            onDisconnected?(id)
        }
    }

    private func scheduleReconnect(_ peripheral: CBPeripheral, immediate: Bool = false) {
        let id = peripheral.identifier
        guard isRunning,
              wantedConnections.contains(id),
              peripheral.state == .disconnected else { return }

        reconnectWorkItems[id]?.cancel()
        resetReconnectAttemptIfStable(id, nowUptime: ProcessInfo.processInfo.systemUptime)
        reconnectStableSinceUptime.removeValue(forKey: id)
        let attempt = (reconnectAttempts[id] ?? 0) + 1
        reconnectAttempts[id] = attempt
        let baseDelay = immediate ? 0 : BLELinkReliabilityPolicy.reconnectDelay(attempt: attempt)
        let jitter = immediate ? 0 : Double.random(in: 0...min(1.0, baseDelay * 0.12))
        let delay = baseDelay + jitter
        flight("reconnect_scheduled", id: id,
               values: ["attempt": attempt, "delay_ms": Int(delay * 1_000)], level: .warning)
        statusText = attempt <= 2 ? "蓝牙链路恢复中" : "蓝牙链路较弱，持续重连中"
        publishLinkSnapshots()

        let work = DispatchWorkItem { [weak self, weak peripheral] in
            guard let self else { return }
            self.reconnectWorkItems.removeValue(forKey: id)
            guard let peripheral,
                  self.isRunning,
                  self.wantedConnections.contains(id),
                  peripheral.state == .disconnected else { return }
            self.centralManager.connect(
                peripheral,
                options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
            )
        }
        reconnectWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func persistWantedConnectionIntent() {
        connectionIntentStore.save(wantedConnections)
    }

    /// Rehydrates the persisted "I want to stay connected to this peripheral" state.
    /// Explicit disconnect/pause clears the store; process relaunch and diagnostic churn do not.
    private func restoreWantedPeripheralsIfPossible(
        reconnectDisconnectedOnly: Bool = false
    ) {
        guard isRunning,
              centralManager.state == .poweredOn,
              !wantedConnections.isEmpty else { return }
        let restored = centralManager.retrievePeripherals(withIdentifiers: Array(wantedConnections))
        for peripheral in restored {
            let id = peripheral.identifier
            remotePeripherals[id] = peripheral
            peripheral.delegate = self
            switch peripheral.state {
            case .disconnected:
                // A restored scan result can arrive while an existing retry
                // timer is waiting. Never cancel/reset its exponential backoff.
                if BLELinkReliabilityPolicy.shouldScheduleRestoredReconnect(
                    isDisconnected: true,
                    hasPendingRetry: reconnectWorkItems[id] != nil
                ) {
                    scheduleReconnect(peripheral, immediate: true)
                }
            case .connected:
                if reconnectDisconnectedOnly { break }
                if remoteCharacteristics[id]?.isNotifying != true {
                    gattHandshakeWatchdog.physicalLinkConnected(
                        id, uptime: ProcessInfo.processInfo.systemUptime
                    )
                }
                if remoteCharacteristics[id] == nil {
                    peripheral.discoverServices([Self.serviceUUID])
                }
                peripheral.readRSSI()
            default:
                break
            }
        }
        publishLinkSnapshots()
    }

    private func beginScanningIfPossible() {
        guard isRunning, centralManager.state == .poweredOn else { return }
        let duplicates = BLEAudioCoexistencePolicy.allowsDuplicateDiscoveries(
            foreground: foregroundActive, bluetoothAudioActive: bluetoothAudioActive
        )
        guard !centralManager.isScanning || lastScanAllowsDuplicates != duplicates else { return }
        if centralManager.isScanning { centralManager.stopScan() }
        centralManager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: duplicates]
        )
        lastScanAllowsDuplicates = duplicates
        statusText = "正在发现附近设备"
    }

    private func beginAdvertisingIfPossible() {
        guard isRunning, peripheralManager.state == .poweredOn else { return }
        if localCharacteristic == nil {
            let characteristic = CBMutableCharacteristic(
                type: Self.dataUUID,
                properties: [.write, .writeWithoutResponse, .notify],
                value: nil,
                permissions: [.writeable]
            )
            let service = CBMutableService(type: Self.serviceUUID, primary: true)
            service.characteristics = [characteristic]
            localCharacteristic = characteristic
            peripheralManager.removeAllServices()
            peripheralManager.add(service)
        } else {
            advertise()
        }
    }

    private func advertise() {
        guard isRunning, !peripheralManager.isAdvertising else { return }
        // The 128-bit service UUID is sufficient for discovery. Omitting the local name keeps
        // the legacy advertisement compact, reducing airtime/collision pressure on crowded 2.4 GHz.
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]
        ])
    }

    private func startRSSIPolling() {
        rssiPollTask?.cancel()
        rssiPollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let interval = self.currentMaintenanceIntervalNanoseconds()
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled, self.isRunning else { continue }
                let now = Date().timeIntervalSinceReferenceDate
                if BLEAudioCoexistencePolicy.shouldPollRSSI(
                    foreground: self.foregroundActive,
                    bluetoothAudioActive: self.bluetoothAudioActive,
                    elapsed: now - self.lastRSSIMaintenanceAt,
                    interval: self.maintenanceTuning.rssiPollInterval
                ) {
                    for peripheral in self.remotePeripherals.values where peripheral.state == .connected {
                        peripheral.readRSSI()
                    }
                    self.lastRSSIMaintenanceAt = now
                }
                // Never stop connection recovery, queued payload progress, or GATT watchdog.
                self.recoverStalledTransportQueuesIfNeeded()
            }
        }
    }

    private func currentMaintenanceIntervalNanoseconds() -> UInt64 {
        let hasQueuedPackets = centralOutboundQueues.values.contains { !$0.isEmpty }
            || peripheralOutboundQueues.values.contains { !$0.isEmpty }
        let hasConnectedPeer = remotePeripherals.values.contains { $0.state == .connected }
            || !subscribedCentrals.isEmpty
        return VeilConcurrentFabricPolicy.maintenanceInterval(
            tuning: maintenanceTuning,
            foreground: foregroundActive,
            queued: hasQueuedPackets,
            connected: hasConnectedPeer
        )
    }

    private func recoverStalledTransportQueuesIfNeeded() {
        recoverStalledGATTHandshakesIfNeeded()
        let uptime = ProcessInfo.processInfo.systemUptime
        for id in Array(reconnectStableSinceUptime.keys) {
            resetReconnectAttemptIfStable(id, nowUptime: uptime)
        }
        let now = Date().timeIntervalSinceReferenceDate
        for id in Array(centralOutboundQueues.keys) {
            guard let queue = centralOutboundQueues[id], !queue.isEmpty else { continue }
            let tuning = linkTuning(for: id)
            let timeout: TimeInterval = tuning.quality == .weak ? 16 : (tuning.quality == .marginal ? 13 : 10)
            let stalled = now - (queueProgress.lastProgress(.central, peerID: id) ?? now)
            let peripheral = remotePeripherals[id]
            let characteristic = remoteCharacteristics[id]
            guard BLELinkReliabilityPolicy.shouldProbeStalledQueue(
                channelReady: peripheral?.state == .connected && characteristic?.isNotifying == true,
                pendingPackets: queue.pendingCount,
                stalledFor: stalled,
                secondsSinceLastProbe: centralStallProbeAt[id].map { now - $0 } ?? 2,
                stallThreshold: timeout
            ), let peripheral, let characteristic else { continue }
            centralStallProbeAt[id] = now
            statusText = "蓝牙发送暂时停滞，保持连接并重试队列"
            // No queue-stall-derived disconnect or loss of pending fragments.
            drainCentralQueue(peripheral: peripheral, characteristic: characteristic)
        }
        for id in Array(peripheralOutboundQueues.keys) {
            guard let queue = peripheralOutboundQueues[id], !queue.isEmpty else { continue }
            let tuning = linkTuning(for: id)
            let timeout: TimeInterval = tuning.quality == .weak ? 16 : (tuning.quality == .marginal ? 13 : 10)
            let stalled = now - (queueProgress.lastProgress(.peripheral, peerID: id) ?? now)
            guard BLELinkReliabilityPolicy.shouldProbeStalledQueue(
                channelReady: subscribedCentrals[id] != nil && localCharacteristic != nil,
                pendingPackets: queue.pendingCount,
                stalledFor: stalled,
                secondsSinceLastProbe: peripheralStallProbeAt[id].map { now - $0 } ?? 2,
                stallThreshold: timeout
            ), let localCharacteristic else { continue }
            peripheralStallProbeAt[id] = now
            statusText = "蓝牙外围发送暂时停滞，保持订阅并重试队列"
            drainPeripheralQueue(for: id, characteristic: localCharacteristic)
        }
        publishLinkSnapshots()
    }

    private func markDataChannelReady(_ id: UUID) {
        guard (reconnectAttempts[id] ?? 0) > 0 else {
            reconnectStableSinceUptime.removeValue(forKey: id)
            return
        }
        reconnectStableSinceUptime[id] = ProcessInfo.processInfo.systemUptime
    }

    private func markPeerTraffic(_ id: UUID) {
        reconnectAttempts[id] = 0
        reconnectStableSinceUptime.removeValue(forKey: id)
    }

    private func resetReconnectAttemptIfStable(_ id: UUID, nowUptime: TimeInterval) {
        guard BLELinkReliabilityPolicy.shouldResetReconnectAttempt(
            stableSince: reconnectStableSinceUptime[id],
            now: nowUptime
        ) else { return }
        reconnectAttempts[id] = 0
        reconnectStableSinceUptime.removeValue(forKey: id)
    }

    /// The PHY can connect while service discovery/notify subscription never completes.
    /// A monotonic timeout avoids indefinite PHY_CONNECTED and makes this failure diagnosable.
    private func recoverStalledGATTHandshakesIfNeeded() {
        let expired = gattHandshakeWatchdog.timedOutPeerIDs(
            uptime: ProcessInfo.processInfo.systemUptime
        )
        for id in expired {
            gattHandshakeWatchdog.disconnected(id)
            guard isRunning,
                  wantedConnections.contains(id),
                  let peripheral = remotePeripherals[id],
                  peripheral.state == .connected,
                  remoteCharacteristics[id]?.isNotifying != true else { continue }
            statusText = "蓝牙数据通道握手超时，正在重新建立连接"
            DiagnosticLogStore.shared.log(
                .warning, .bluetooth,
                event: "ble.gatt_handshake_timeout",
                metadata: ["phase": "notification_wait", "attempt": String(reconnectAttempts[id] ?? 0)]
            )
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    private func failGATTHandshake(_ peripheral: CBPeripheral, phase: String) {
        statusText = "蓝牙数据通道握手失败，准备退避重连"
        DiagnosticLogStore.shared.log(
            .warning, .bluetooth,
            event: "ble.gatt_handshake_failure",
            metadata: ["phase": phase, "attempt": String(reconnectAttempts[peripheral.identifier] ?? 0)]
        )
        centralManager.cancelPeripheralConnection(peripheral)
    }

    private func observeRSSI(_ sample: Int, for id: UUID, forcePublish: Bool = false) {
        guard let next = BLELinkReliabilityPolicy.smoothedRSSI(previous: smoothedRSSI[id], sample: sample) else { return }
        smoothedRSSI[id] = next
        let rounded = Int(next.rounded())
        let now = Date().timeIntervalSinceReferenceDate
        lastSeenAt[id] = now
        let previousPublished = discoveredRSSI[id]
        if forcePublish || previousPublished == nil || abs((previousPublished ?? rounded) - rounded) >= 2 || now - (lastRSSIPublishAt[id] ?? 0) >= 0.75 {
            discoveredRSSI[id] = rounded
            lastRSSIPublishAt[id] = now
            onDiscovered?(id, rounded)
            publishLinkSnapshots()
        }
    }
}

extension BLETransport: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            beginScanningIfPossible()
            restoreWantedPeripheralsIfPossible()
        case .poweredOff: statusText = "蓝牙已关闭"
        case .unauthorized: statusText = "没有蓝牙权限"
        case .unsupported: statusText = "此设备不支持低功耗蓝牙"
        default: statusText = "蓝牙暂不可用"
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let id = peripheral.identifier
        remotePeripherals[id] = peripheral
        observeRSSI(RSSI.intValue, for: id)
        if wantedConnections.contains(id), peripheral.state == .disconnected, reconnectWorkItems[id] == nil {
            scheduleReconnect(peripheral, immediate: true)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard isRunning, wantedConnections.contains(peripheral.identifier) else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        // Do not reset reconnectAttempts at PHY_CONNECTED: the attempt only
        // succeeds after GATT notifications are active. Otherwise a broken
        // service/subscription loops forever at the first 0.75-second retry.
        gattHandshakeWatchdog.physicalLinkConnected(
            peripheral.identifier, uptime: ProcessInfo.processInfo.systemUptime
        )
        reconnectWorkItems.removeValue(forKey: peripheral.identifier)?.cancel()
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        peripheral.readRSSI()
        statusText = "蓝牙物理链路已连接，正在发现数据通道"
        flight("physical_connected", id: peripheral.identifier, level: .info)
        publishLinkSnapshots(force: true)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier
        gattHandshakeWatchdog.disconnected(id)
        centralDrainWorkItems.removeValue(forKey: id)?.cancel()
        remoteCharacteristics.removeValue(forKey: id)
        centralOutboundQueues.removeValue(forKey: id)
        centralStallProbeAt.removeValue(forKey: id)
        queueProgress.clear(.central, peerID: id)
        reconcileConnectionEvent(id)
        if !hasReadyDataChannel(id) {
            assembler.reset(source: id)
            statusText = "连接失败，准备重试"
        } else {
            statusText = "中央角色连接失败，备用数据通道仍可用"
        }
        flight("connect_failed", id: id,
               values: ["error_code": (error as NSError?)?.code ?? 0], level: .warning)
        scheduleReconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier
        gattHandshakeWatchdog.disconnected(id)
        centralDrainWorkItems.removeValue(forKey: id)?.cancel()
        remoteCharacteristics.removeValue(forKey: id)
        centralOutboundQueues.removeValue(forKey: id)
        centralStallProbeAt.removeValue(forKey: id)
        queueProgress.clear(.central, peerID: id)
        reconcileConnectionEvent(id)
        if !hasReadyDataChannel(id) {
            assembler.reset(source: id)
            statusText = "连接已断开，等待重连"
        } else {
            statusText = "中央角色已断开，备用数据通道仍可用"
        }
        flight("physical_disconnected", id: id,
               values: ["error_code": (error as NSError?)?.code ?? 0], level: .warning)
        scheduleReconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        var didChangeIntent = false
        for peripheral in restored {
            remotePeripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            if peripheral.state == .connected {
                gattHandshakeWatchdog.physicalLinkConnected(
                    peripheral.identifier, uptime: ProcessInfo.processInfo.systemUptime
                )
                if wantedConnections.insert(peripheral.identifier).inserted {
                    didChangeIntent = true
                }
                peripheral.discoverServices([Self.serviceUUID])
            }
        }
        if didChangeIntent { connectionIntentStore.save(wantedConnections) }
    }
}

extension BLETransport: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        observeRSSI(RSSI.intValue, for: peripheral.identifier, forcePublish: true)
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard let characteristic = remoteCharacteristics[peripheral.identifier] else { return }
        drainCentralQueue(peripheral: peripheral, characteristic: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            // No matching service is a failed handshake, not a successful PHY link.
            failGATTHandshake(peripheral, phase: "service_discovery")
            return
        }
        peripheral.discoverCharacteristics([Self.dataUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == Self.dataUUID }),
              characteristic.properties.contains(.notify),
              characteristic.properties.contains(.writeWithoutResponse) else {
            failGATTHandshake(peripheral, phase: "characteristic_discovery")
            return
        }
        remoteCharacteristics[peripheral.identifier] = characteristic
        statusText = "蓝牙数据通道已发现，正在订阅通知"
        publishLinkSnapshots(force: true)
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.dataUUID else { return }
        guard error == nil, characteristic.isNotifying else {
            failGATTHandshake(peripheral, phase: "notify_subscription")
            return
        }
        gattHandshakeWatchdog.dataChannelReady(peripheral.identifier)
        markDataChannelReady(peripheral.identifier)
        persistWantedConnectionIntent()
        reconcileConnectionEvent(peripheral.identifier)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.dataUUID,
              let value = characteristic.value else { return }
        markPeerTraffic(peripheral.identifier)
        guard let assembled = assembler.ingest(source: peripheral.identifier, packet: value) else { return }
        onReceive?(peripheral.identifier, assembled)
    }
}

extension BLETransport: @preconcurrency CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn: beginAdvertisingIfPossible()
        case .poweredOff: statusText = "蓝牙已关闭"
        case .unauthorized: statusText = "没有蓝牙权限"
        default: break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            statusText = "蓝牙服务注册失败"
            return
        }
        advertise()
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == Self.dataUUID else { return }
        subscribedCentrals[central.identifier] = central
        reconcileConnectionEvent(central.identifier)
        if let localCharacteristic { drainPeripheralQueue(for: central.identifier, characteristic: localCharacteristic) }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        let id = central.identifier
        subscribedCentrals.removeValue(forKey: id)
        peripheralOutboundQueues.removeValue(forKey: id)
        peripheralStallProbeAt.removeValue(forKey: id)
        queueProgress.clear(.peripheral, peerID: id)
        reconcileConnectionEvent(id)
        if !hasReadyDataChannel(id) {
            assembler.reset(source: id)
            statusText = "外围角色已断开，等待数据通道恢复"
        } else {
            statusText = "外围角色已断开，中央数据通道仍可用"
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Apple calls this after updateValue(...) returned false because its TX queue was full.
        // Resume every subscribed peer with pending data instead of leaving the queue stranded.
        guard isRunning, let characteristic = localCharacteristic else { return }
        for id in Array(peripheralOutboundQueues.keys) where subscribedCentrals[id] != nil {
            drainPeripheralQueue(for: id, characteristic: characteristic)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == Self.dataUUID else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }
            guard let value = request.value else {
                peripheral.respond(to: request, withResult: .invalidPdu)
                continue
            }
            if request.characteristic.properties.contains(.write) {
                peripheral.respond(to: request, withResult: .success)
            }
            markPeerTraffic(request.central.identifier)
            if let assembled = assembler.ingest(source: request.central.identifier, packet: value) {
                onReceive?(request.central.identifier, assembled)
            }
        }
    }


    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService],
           let characteristic = services
            .flatMap({ $0.characteristics ?? [] })
            .compactMap({ $0 as? CBMutableCharacteristic })
            .first(where: { $0.uuid == Self.dataUUID }) {
            localCharacteristic = characteristic
        }
    }
}
