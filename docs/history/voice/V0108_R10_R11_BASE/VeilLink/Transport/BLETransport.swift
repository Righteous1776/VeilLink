import Combine
import CoreBluetooth
import Foundation

private struct OutboundPacketQueue {
    private var packets: [Data] = []
    private var head = 0
    private var queuedBytes = 0

    var pendingCount: Int { packets.count - head }
    var pendingBytes: Int { queuedBytes }
    var first: Data? { head < packets.count ? packets[head] : nil }
    var isEmpty: Bool { pendingCount == 0 }

    mutating func append(contentsOf newPackets: [Data]) {
        guard !newPackets.isEmpty else { return }
        if head > 0 && (head >= 256 || head * 2 >= packets.count) {
            packets.removeFirst(head)
            head = 0
        }
        packets.append(contentsOf: newPackets)
        queuedBytes += newPackets.reduce(0) { $0 + $1.count }
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
    private var bulk = OutboundPacketQueue()

    var pendingCount: Int { control.pendingCount + bulk.pendingCount }
    var pendingBytes: Int { control.pendingBytes + bulk.pendingBytes }
    var isEmpty: Bool { control.isEmpty && bulk.isEmpty }

    mutating func append(contentsOf packets: [Data], priority: BLESendPriority) {
        switch priority {
        case .control: control.append(contentsOf: packets)
        case .bulk: bulk.append(contentsOf: packets)
        }
    }

    mutating func removeFirst() -> Data? {
        if let packet = control.removeFirst() { return packet }
        return bulk.removeFirst()
    }

    var first: Data? { control.first ?? bulk.first }
}

@MainActor
final class BLETransport: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "5D0F88D4-21A2-4DC4-A1E8-A2DF8C9AC001")
    static let dataUUID = CBUUID(string: "5D0F88D4-21A2-4DC4-A1E8-A2DF8C9AC002")

    @Published private(set) var statusText = "正在初始化蓝牙"
    @Published private(set) var isRunning = false
    @Published private(set) var discoveredRSSI: [UUID: Int] = [:]

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
    private var reconnectWorkItems: [UUID: DispatchWorkItem] = [:]
    private var centralDrainWorkItems: [UUID: DispatchWorkItem] = [:]
    private var peripheralDrainWorkItems: [UUID: DispatchWorkItem] = [:]
    private var smoothedRSSI: [UUID: Double] = [:]
    private var lastRSSIPublishAt: [UUID: TimeInterval] = [:]
    private var lastQueueProgressAt: [UUID: TimeInterval] = [:]
    private var rssiPollTask: Task<Void, Never>?
    private var connectionEvents = ConnectionEventGate()

    private let maxFragmentsPerMessage = 16_384
    private let performanceProfile: DevicePerformanceProfile
    private let assembler: BLEFragmentAssembler

    private var maxQueuedPacketsPerPeer: Int { performanceProfile.bleQueuePacketLimit }
    private var maxQueuedBytesPerPeer: Int { performanceProfile.bleQueueByteLimit }

    override init() {
        let profile = VeilDevicePerformance.current
        performanceProfile = profile
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
    }

    func start() {
        isRunning = true
        startRSSIPolling()
        beginScanningIfPossible()
        beginAdvertisingIfPossible()
    }

    func stop() {
        isRunning = false
        centralManager.stopScan()
        peripheralManager.stopAdvertising()
        for peripheral in remotePeripherals.values where peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        wantedConnections.removeAll()
        reconnectAttempts.removeAll()
        reconnectWorkItems.values.forEach { $0.cancel() }
        reconnectWorkItems.removeAll()
        centralDrainWorkItems.values.forEach { $0.cancel() }
        centralDrainWorkItems.removeAll()
        peripheralDrainWorkItems.values.forEach { $0.cancel() }
        peripheralDrainWorkItems.removeAll()
        rssiPollTask?.cancel()
        rssiPollTask = nil

        connectionEvents.drainConnectedIDs().forEach { onDisconnected?($0) }
        remoteCharacteristics.removeAll()
        centralOutboundQueues.removeAll()
        peripheralOutboundQueues.removeAll()
        statusText = "蓝牙发现已暂停"
    }

    func disconnect(_ id: UUID) {
        wantedConnections.remove(id)
        tearDownTransportState(for: id)
        if let peripheral = remotePeripherals[id], peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        _ = subscribedCentrals.removeValue(forKey: id)
        publishDisconnected(id)
    }

    /// Drops the current link while preserving the user's intent to stay connected.
    /// Used by the security/session watchdog when a connection becomes stale.
    func recover(_ id: UUID) {
        wantedConnections.insert(id)
        tearDownTransportState(for: id, keepReconnectAttempt: true)
        if let peripheral = remotePeripherals[id] {
            if peripheral.state == .connected || peripheral.state == .connecting {
                centralManager.cancelPeripheralConnection(peripheral)
            } else if peripheral.state == .disconnected {
                scheduleReconnect(peripheral, immediate: true)
            }
        }
        publishDisconnected(id)
    }

    private func tearDownTransportState(for id: UUID, keepReconnectAttempt: Bool = false) {
        if !keepReconnectAttempt { reconnectAttempts.removeValue(forKey: id) }
        reconnectWorkItems.removeValue(forKey: id)?.cancel()
        centralDrainWorkItems.removeValue(forKey: id)?.cancel()
        peripheralDrainWorkItems.removeValue(forKey: id)?.cancel()
        centralOutboundQueues.removeValue(forKey: id)
        peripheralOutboundQueues.removeValue(forKey: id)
        remoteCharacteristics.removeValue(forKey: id)
        lastQueueProgressAt.removeValue(forKey: id)
    }

    func connect(to id: UUID) {
        wantedConnections.insert(id)
        reconnectAttempts[id] = 0
        reconnectWorkItems.removeValue(forKey: id)?.cancel()
        guard isRunning,
              let peripheral = remotePeripherals[id],
              peripheral.state == .disconnected else { return }
        centralManager.connect(
            peripheral,
            options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
        )
    }

    @discardableResult
    func send(_ data: Data, to transportID: UUID, priority: BLESendPriority = .bulk) -> TransportSendResult {
        if let peripheral = remotePeripherals[transportID],
           let characteristic = remoteCharacteristics[transportID],
           peripheral.state == .connected {
            let maximum = peripheral.maximumWriteValueLength(for: .withoutResponse)
            guard let plan = BLEFragment.fragmentationPlan(payloadByteCount: data.count, maximumPacketSize: maximum),
                  plan.fragmentCount <= maxFragmentsPerMessage else { return .unsupportedLink }
            let existing = centralOutboundQueues[transportID]
            guard (existing?.pendingCount ?? 0) + plan.fragmentCount <= maxQueuedPacketsPerPeer,
                  (existing?.pendingBytes ?? 0) + plan.encodedByteCount <= maxQueuedBytesPerPeer else {
                return .temporarilyUnavailable
            }
            let packets = BLEFragment.split(data, maximumPacketSize: maximum).map(\.encoded)
            centralOutboundQueues[transportID, default: PeerOutboundQueue()].append(contentsOf: packets, priority: priority)
            if lastQueueProgressAt[transportID] == nil { lastQueueProgressAt[transportID] = Date().timeIntervalSinceReferenceDate }
            drainCentralQueue(peripheral: peripheral, characteristic: characteristic)
            return .accepted
        }

        guard let central = subscribedCentrals[transportID],
              let localCharacteristic else { return .temporarilyUnavailable }
        let maximum = central.maximumUpdateValueLength
        guard let plan = BLEFragment.fragmentationPlan(payloadByteCount: data.count, maximumPacketSize: maximum),
              plan.fragmentCount <= maxFragmentsPerMessage else { return .unsupportedLink }
        let existing = peripheralOutboundQueues[transportID]
        guard (existing?.pendingCount ?? 0) + plan.fragmentCount <= maxQueuedPacketsPerPeer,
              (existing?.pendingBytes ?? 0) + plan.encodedByteCount <= maxQueuedBytesPerPeer else {
            return .temporarilyUnavailable
        }
        let packets = BLEFragment.split(data, maximumPacketSize: maximum).map(\.encoded)
        peripheralOutboundQueues[transportID, default: PeerOutboundQueue()].append(contentsOf: packets, priority: priority)
        if lastQueueProgressAt[transportID] == nil { lastQueueProgressAt[transportID] = Date().timeIntervalSinceReferenceDate }
        drainPeripheralQueue(for: transportID, characteristic: localCharacteristic)
        return .accepted
    }

    private func drainCentralQueue(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let id = peripheral.identifier
        centralDrainWorkItems.removeValue(forKey: id)?.cancel()
        guard var queue = centralOutboundQueues[id] else { return }
        let tuning = linkTuning(for: id)
        var sent = 0
        while sent < tuning.packetBurstLimit, peripheral.canSendWriteWithoutResponse, let packet = queue.removeFirst() {
            peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
            sent += 1
            lastQueueProgressAt[id] = Date().timeIntervalSinceReferenceDate
        }
        if queue.isEmpty {
            centralOutboundQueues.removeValue(forKey: id)
            lastQueueProgressAt.removeValue(forKey: id)
        } else {
            centralOutboundQueues[id] = queue
            if peripheral.canSendWriteWithoutResponse {
                scheduleCentralDrain(for: id, after: tuning.interBurstDelay)
            }
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
        var sent = 0
        while sent < tuning.packetBurstLimit, let packet = queue.first {
            guard peripheralManager.updateValue(packet, for: characteristic, onSubscribedCentrals: [central]) else {
                peripheralOutboundQueues[centralID] = queue
                return
            }
            _ = queue.removeFirst()
            sent += 1
            lastQueueProgressAt[centralID] = Date().timeIntervalSinceReferenceDate
        }
        if queue.isEmpty {
            peripheralOutboundQueues.removeValue(forKey: centralID)
            lastQueueProgressAt.removeValue(forKey: centralID)
        } else {
            peripheralOutboundQueues[centralID] = queue
            schedulePeripheralDrain(for: centralID, after: tuning.interBurstDelay)
        }
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
                  let characteristic = self.remoteCharacteristics[id] else { return }
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

    private func publishConnected(_ id: UUID) {
        guard connectionEvents.markConnected(id) else { return }
        onConnected?(id)
    }

    private func publishDisconnected(_ id: UUID) {
        guard connectionEvents.markDisconnected(id) else { return }
        onDisconnected?(id)
    }

    private func scheduleReconnect(_ peripheral: CBPeripheral, immediate: Bool = false) {
        let id = peripheral.identifier
        guard isRunning,
              wantedConnections.contains(id),
              peripheral.state == .disconnected else { return }

        reconnectWorkItems[id]?.cancel()
        let attempt = (reconnectAttempts[id] ?? 0) + 1
        reconnectAttempts[id] = attempt
        let baseDelay = immediate ? 0 : BLELinkReliabilityPolicy.reconnectDelay(attempt: attempt)
        let jitter = immediate ? 0 : Double.random(in: 0...min(1.0, baseDelay * 0.12))
        let delay = baseDelay + jitter
        statusText = attempt <= 2 ? "蓝牙链路恢复中" : "蓝牙链路较弱，持续重连中"

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

    private func beginScanningIfPossible() {
        guard isRunning, centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
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
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, self.isRunning else { continue }
                for peripheral in self.remotePeripherals.values where peripheral.state == .connected {
                    peripheral.readRSSI()
                }
                self.recoverStalledTransportQueuesIfNeeded()
            }
        }
    }

    private func recoverStalledTransportQueuesIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        for id in Array(centralOutboundQueues.keys) {
            guard let queue = centralOutboundQueues[id], !queue.isEmpty else { continue }
            let tuning = linkTuning(for: id)
            let timeout: TimeInterval = tuning.quality == .weak ? 16 : (tuning.quality == .marginal ? 13 : 10)
            guard now - (lastQueueProgressAt[id] ?? now) >= timeout else { continue }
            centralOutboundQueues.removeValue(forKey: id)
            lastQueueProgressAt.removeValue(forKey: id)
            statusText = "检测到蓝牙发送停滞，正在自动恢复链路"
            if wantedConnections.contains(id) { recover(id) }
        }
        for id in Array(peripheralOutboundQueues.keys) {
            guard let queue = peripheralOutboundQueues[id], !queue.isEmpty else { continue }
            let tuning = linkTuning(for: id)
            let timeout: TimeInterval = tuning.quality == .weak ? 16 : (tuning.quality == .marginal ? 13 : 10)
            guard now - (lastQueueProgressAt[id] ?? now) >= timeout else { continue }
            // A peripheral cannot force-disconnect one subscribed central. Drop only the stale
            // transport frame; the persistent application outbox/checkpoint logic will resend it.
            peripheralOutboundQueues.removeValue(forKey: id)
            peripheralDrainWorkItems.removeValue(forKey: id)?.cancel()
            lastQueueProgressAt.removeValue(forKey: id)
            statusText = "检测到蓝牙发送停滞，已切换到应用层重传"
        }
    }

    private func observeRSSI(_ sample: Int, for id: UUID, forcePublish: Bool = false) {
        guard let next = BLELinkReliabilityPolicy.smoothedRSSI(previous: smoothedRSSI[id], sample: sample) else { return }
        smoothedRSSI[id] = next
        let rounded = Int(next.rounded())
        let now = Date().timeIntervalSinceReferenceDate
        let previousPublished = discoveredRSSI[id]
        if forcePublish || previousPublished == nil || abs((previousPublished ?? rounded) - rounded) >= 2 || now - (lastRSSIPublishAt[id] ?? 0) >= 0.75 {
            discoveredRSSI[id] = rounded
            lastRSSIPublishAt[id] = now
            onDiscovered?(id, rounded)
        }
    }
}

extension BLETransport: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            beginScanningIfPossible()
            for peripheral in remotePeripherals.values where wantedConnections.contains(peripheral.identifier) && peripheral.state == .disconnected {
                scheduleReconnect(peripheral, immediate: true)
            }
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
        reconnectAttempts[peripheral.identifier] = 0
        reconnectWorkItems.removeValue(forKey: peripheral.identifier)?.cancel()
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        peripheral.readRSSI()
        statusText = "已建立蓝牙链路"
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        centralDrainWorkItems.removeValue(forKey: peripheral.identifier)?.cancel()
        remoteCharacteristics.removeValue(forKey: peripheral.identifier)
        centralOutboundQueues.removeValue(forKey: peripheral.identifier)
        publishDisconnected(peripheral.identifier)
        statusText = "连接失败，准备重试"
        scheduleReconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        centralDrainWorkItems.removeValue(forKey: peripheral.identifier)?.cancel()
        remoteCharacteristics.removeValue(forKey: peripheral.identifier)
        centralOutboundQueues.removeValue(forKey: peripheral.identifier)
        publishDisconnected(peripheral.identifier)
        statusText = "连接已断开，等待重连"
        scheduleReconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        for peripheral in restored {
            remotePeripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            if peripheral.state == .connected {
                wantedConnections.insert(peripheral.identifier)
                peripheral.discoverServices([Self.serviceUUID])
            }
        }
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
        guard error == nil else {
            statusText = "服务发现失败，准备重连"
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.services?
            .filter { $0.uuid == Self.serviceUUID }
            .forEach { peripheral.discoverCharacteristics([Self.dataUUID], for: $0) }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == Self.dataUUID }) else {
            statusText = "数据通道发现失败，准备重连"
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        remoteCharacteristics[peripheral.identifier] = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, characteristic.isNotifying else {
            statusText = "数据通道订阅失败，准备重连"
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        publishConnected(peripheral.identifier)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.dataUUID,
              let value = characteristic.value,
              let assembled = assembler.ingest(source: peripheral.identifier, packet: value) else { return }
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
        publishConnected(central.identifier)
        if let localCharacteristic { drainPeripheralQueue(for: central.identifier, characteristic: localCharacteristic) }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        subscribedCentrals.removeValue(forKey: central.identifier)
        peripheralOutboundQueues.removeValue(forKey: central.identifier)
        publishDisconnected(central.identifier)
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
            if let assembled = assembler.ingest(source: request.central.identifier, packet: value) {
                onReceive?(request.central.identifier, assembled)
            }
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let localCharacteristic else { return }
        for centralID in Array(peripheralOutboundQueues.keys) {
            drainPeripheralQueue(for: centralID, characteristic: localCharacteristic)
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
