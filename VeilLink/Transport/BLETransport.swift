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
    private var peripheralOutboundQueues: [UUID: OutboundPacketQueue] = [:]
    private var centralOutboundQueues: [UUID: OutboundPacketQueue] = [:]
    private var wantedConnections: Set<UUID> = []
    private var reconnectAttempts: [UUID: Int] = [:]
    private var reconnectWorkItems: [UUID: DispatchWorkItem] = [:]
    private var connectionEvents = ConnectionEventGate()

    private let maxFragmentsPerMessage = 16_384
    private let maxQueuedPacketsPerPeer = 16_384
    private let maxQueuedBytesPerPeer = 2_500_000
    // Protocol 4 envelopes are capped at 96 KB. Keep the pre-session BLE
    // reassembly budget close to that real wire limit so untrusted nearby
    // devices cannot reserve megabytes of impossible-to-accept frame state.
    private let assembler = BLEFragmentAssembler(
        maxConcurrentMessages: 32,
        maxConcurrentMessagesPerSource: 8,
        maxFragmentsPerMessage: 16_384,
        maxAssembledBytes: 96_000,
        maxTotalBufferedBytes: 768_000
    )

    override init() {
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

        connectionEvents.drainConnectedIDs().forEach { onDisconnected?($0) }
        remoteCharacteristics.removeAll()
        centralOutboundQueues.removeAll()
        peripheralOutboundQueues.removeAll()
        statusText = "蓝牙发现已暂停"
    }

    func disconnect(_ id: UUID) {
        wantedConnections.remove(id)
        reconnectAttempts.removeValue(forKey: id)
        reconnectWorkItems.removeValue(forKey: id)?.cancel()
        centralOutboundQueues.removeValue(forKey: id)
        peripheralOutboundQueues.removeValue(forKey: id)
        remoteCharacteristics.removeValue(forKey: id)
        if let peripheral = remotePeripherals[id], peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        _ = subscribedCentrals.removeValue(forKey: id)
        publishDisconnected(id)
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
    func send(_ data: Data, to transportID: UUID) -> TransportSendResult {
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
            centralOutboundQueues[transportID, default: OutboundPacketQueue()].append(contentsOf: packets)
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
        peripheralOutboundQueues[transportID, default: OutboundPacketQueue()].append(contentsOf: packets)
        drainPeripheralQueue(for: transportID, characteristic: localCharacteristic)
        return .accepted
    }

    private func drainCentralQueue(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let id = peripheral.identifier
        guard var queue = centralOutboundQueues[id] else { return }
        while peripheral.canSendWriteWithoutResponse, let packet = queue.removeFirst() {
            peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
        }
        if queue.isEmpty {
            centralOutboundQueues.removeValue(forKey: id)
        } else {
            centralOutboundQueues[id] = queue
        }
    }

    private func drainPeripheralQueue(for centralID: UUID, characteristic: CBMutableCharacteristic) {
        guard let central = subscribedCentrals[centralID] else {
            peripheralOutboundQueues.removeValue(forKey: centralID)
            return
        }
        guard var queue = peripheralOutboundQueues[centralID] else { return }
        while let packet = queue.first {
            guard peripheralManager.updateValue(packet, for: characteristic, onSubscribedCentrals: [central]) else {
                peripheralOutboundQueues[centralID] = queue
                return
            }
            _ = queue.removeFirst()
        }
        peripheralOutboundQueues.removeValue(forKey: centralID)
    }

    private func publishConnected(_ id: UUID) {
        guard connectionEvents.markConnected(id) else { return }
        onConnected?(id)
    }

    private func publishDisconnected(_ id: UUID) {
        guard connectionEvents.markDisconnected(id) else { return }
        onDisconnected?(id)
    }

    private func scheduleReconnect(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        guard isRunning,
              wantedConnections.contains(id),
              peripheral.state == .disconnected else { return }

        let attempt = (reconnectAttempts[id] ?? 0) + 1
        reconnectAttempts[id] = attempt
        guard attempt <= 5 else {
            statusText = "自动重连已暂停，可手动再次连接"
            return
        }

        reconnectWorkItems[id]?.cancel()
        let delay = min(30.0, pow(2.0, Double(attempt)))
        let work = DispatchWorkItem { [weak self, weak peripheral] in
            guard let self,
                  let peripheral,
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
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
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
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "VeilLink"
        ])
    }
}

extension BLETransport: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: beginScanningIfPossible()
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
        remotePeripherals[peripheral.identifier] = peripheral
        discoveredRSSI[peripheral.identifier] = RSSI.intValue
        onDiscovered?(peripheral.identifier, RSSI.intValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        reconnectAttempts[peripheral.identifier] = 0
        reconnectWorkItems.removeValue(forKey: peripheral.identifier)?.cancel()
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
        statusText = "已建立蓝牙链路"
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        remoteCharacteristics.removeValue(forKey: peripheral.identifier)
        centralOutboundQueues.removeValue(forKey: peripheral.identifier)
        publishDisconnected(peripheral.identifier)
        statusText = "连接失败，准备重试"
        scheduleReconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
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
