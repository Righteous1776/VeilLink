import Combine
import Foundation
#if canImport(Network)
import Network
#endif

enum LANTurboRole: String, Codable, Sendable {
    case incoming
    case outgoing
}

struct LANTurboLinkSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: LANTurboRole
    let endpointDescription: String
    let isReady: Bool
    let pendingFrames: Int
    let pendingBytes: Int
}

enum LANFrameError: Error, Equatable {
    case payloadTooLarge
    case invalidLength
}

enum LANDataPlanePolicy {
    // Four 48 KiB chunks per acknowledgement window gives the TCP path a real
    // pipeline without inflating iPhone 7 memory or changing Wire Protocol v4.
    static let attachmentBurstWindow = 4

    static func reconnectDelay(attempt: Int) -> TimeInterval {
        let schedule: [TimeInterval] = [0.35, 0.80, 1.50, 3.0, 5.0]
        return schedule[min(max(attempt, 0), schedule.count - 1)]
    }
}

enum LANFrameCodec {
    static let maximumPayloadBytes = 96_000
    static let headerBytes = 4

    static func encode(_ payload: Data) throws -> Data {
        guard payload.count > 0, payload.count <= maximumPayloadBytes else {
            throw LANFrameError.payloadTooLarge
        }
        var length = UInt32(payload.count).bigEndian
        var framed = Data(bytes: &length, count: headerBytes)
        framed.append(payload)
        return framed
    }
}

struct LANFrameDecoder {
    private(set) var bufferedByteCount = 0
    private var storage = Data()

    mutating func append(_ bytes: Data) throws -> [Data] {
        guard !bytes.isEmpty else { return [] }
        storage.append(bytes)
        bufferedByteCount = storage.count

        var output: [Data] = []
        while storage.count >= LANFrameCodec.headerBytes {
            let length: UInt32 = storage.prefix(LANFrameCodec.headerBytes).withUnsafeBytes { raw in
                raw.loadUnaligned(as: UInt32.self).bigEndian
            }
            let payloadBytes = Int(length)
            guard payloadBytes > 0, payloadBytes <= LANFrameCodec.maximumPayloadBytes else {
                storage.removeAll(keepingCapacity: false)
                bufferedByteCount = 0
                throw LANFrameError.invalidLength
            }
            let total = LANFrameCodec.headerBytes + payloadBytes
            guard storage.count >= total else { break }
            output.append(Data(storage[LANFrameCodec.headerBytes..<total]))
            storage.removeSubrange(0..<total)
        }
        bufferedByteCount = storage.count
        return output
    }

    mutating func reset() {
        storage.removeAll(keepingCapacity: false)
        bufferedByteCount = 0
    }
}

#if canImport(Network)
private struct LANPriorityQueue {
    private var control: [Data] = []
    private var realtime: [Data] = []
    private var bulk: [Data] = []
    private var controlHead = 0
    private var realtimeHead = 0
    private var bulkHead = 0
    private(set) var pendingBytes = 0

    var pendingCount: Int {
        (control.count - controlHead) + (realtime.count - realtimeHead) + (bulk.count - bulkHead)
    }

    mutating func append(_ frame: Data, priority: BLESendPriority) {
        compactIfNeeded()
        switch priority {
        case .control: control.append(frame)
        case .realtime: realtime.append(frame)
        case .bulk: bulk.append(frame)
        }
        pendingBytes += frame.count
    }

    mutating func popFirst() -> Data? {
        let value: Data?
        if controlHead < control.count {
            value = control[controlHead]
            controlHead += 1
        } else if realtimeHead < realtime.count {
            value = realtime[realtimeHead]
            realtimeHead += 1
        } else if bulkHead < bulk.count {
            value = bulk[bulkHead]
            bulkHead += 1
        } else {
            value = nil
        }
        if let value { pendingBytes -= value.count }
        compactIfNeeded()
        return value
    }

    private mutating func compactIfNeeded() {
        if controlHead > 0 && (controlHead >= 64 || controlHead * 2 >= control.count) {
            control.removeFirst(controlHead)
            controlHead = 0
        }
        if realtimeHead > 0 && (realtimeHead >= 64 || realtimeHead * 2 >= realtime.count) {
            realtime.removeFirst(realtimeHead)
            realtimeHead = 0
        }
        if bulkHead > 0 && (bulkHead >= 32 || bulkHead * 2 >= bulk.count) {
            bulk.removeFirst(bulkHead)
            bulkHead = 0
        }
    }
}

private final class LANLink {
    let id: UUID
    let connection: NWConnection
    let role: LANTurboRole
    let endpointKey: String
    var decoder = LANFrameDecoder()
    var outbound = LANPriorityQueue()
    var isReady = false
    var inFlightSends = 0
    var inFlightBytes = 0

    init(id: UUID, connection: NWConnection, role: LANTurboRole, endpointKey: String) {
        self.id = id
        self.connection = connection
        self.role = role
        self.endpointKey = endpointKey
    }
}

/// Same-LAN / same-hotspot high-speed transport.
///
/// Security intentionally remains above this layer. LANTransport only frames opaque VeilLink
/// envelopes over TCP; SessionCoordinator still performs signed identity handshakes, Curve25519
/// key agreement, replay protection and ChaCha20-Poly1305 encryption independently per link.
final class LANTransport: ObservableObject, @unchecked Sendable {
    static let serviceType = "_veillink._tcp"

    @Published private(set) var statusText = "局域网高速通道未启动"
    @Published private(set) var isRunning = false
    @Published private(set) var discoveredServiceCount = 0
    @Published private(set) var connectedPeerCount = 0
    @Published private(set) var linkSnapshots: [UUID: LANTurboLinkSnapshot] = [:]
    @Published private(set) var totalPayloadBytesSent: UInt64 = 0
    @Published private(set) var totalPayloadBytesReceived: UInt64 = 0
    @Published private(set) var lastDataPlaneActivityAt: Date?
    @Published var peerToPeerBoostEnabled = true

    var onConnected: ((UUID) -> Void)?
    var onDisconnected: ((UUID) -> Void)?
    var onReceive: ((UUID, Data) -> Void)?

    private let queue = DispatchQueue(label: "studio.zeo.veillink.lan-turbo", qos: .userInitiated)
    private let serviceInstanceName: String
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var links: [UUID: LANLink] = [:]
    private var endpointToLink: [String: UUID] = [:]
    private var discoveredEndpoints: [String: NWEndpoint] = [:]
    private var reconnectAttempts: [String: Int] = [:]
    private var reconnectWorkItems: [String: DispatchWorkItem] = [:]
    private var sentPayloadBytes: UInt64 = 0
    private var receivedPayloadBytes: UInt64 = 0
    private var running = false

    private var maximumQueuedFrames: Int {
        VeilDevicePerformance.current.transferVisualComplexity == .minimal ? 256 : 1_024
    }

    private var maximumQueuedBytes: Int {
        VeilRenderProfile.usesLegacyCompositorPath ? 8 * 1_024 * 1_024 : 32 * 1_024 * 1_024
    }

    private var maximumInFlightSends: Int {
        VeilRenderProfile.usesLegacyCompositorPath ? 2 : 6
    }

    init() {
        // Ephemeral per app process: enough for deterministic one-connection election while
        // avoiding a stable Bonjour identifier that could track a device across LAN sessions.
        serviceInstanceName = "VeilLink-" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
    }

    func start() {
        queue.async { [weak self] in self?.startLocked() }
    }

    func stop() {
        queue.async { [weak self] in self?.stopLocked() }
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopLocked(publishStopped: false)
            self.startLocked()
        }
    }

    func containsTransport(_ id: UUID) -> Bool {
        queue.sync { links[id] != nil }
    }

    func isReadyTransport(_ id: UUID) -> Bool {
        queue.sync { links[id]?.isReady == true }
    }

    var dataPlaneSummary: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        let sent = formatter.string(fromByteCount: Int64(clamping: totalPayloadBytesSent))
        let received = formatter.string(fromByteCount: Int64(clamping: totalPayloadBytesReceived))
        return "TX \(sent) · RX \(received)"
    }

    @discardableResult
    func send(_ payload: Data, to transportID: UUID, priority: BLESendPriority) -> TransportSendResult {
        queue.sync {
            guard running, let link = links[transportID], link.isReady else { return .temporarilyUnavailable }
            guard let frame = try? LANFrameCodec.encode(payload) else { return .unsupportedLink }
            guard link.outbound.pendingCount + 1 <= maximumQueuedFrames,
                  link.outbound.pendingBytes + frame.count <= maximumQueuedBytes else {
                return .temporarilyUnavailable
            }
            link.outbound.append(frame, priority: priority)
            drainLocked(link)
            publishSnapshotsLocked()
            return .accepted
        }
    }

    func disconnect(_ id: UUID) {
        queue.async { [weak self] in
            guard let self, let link = self.links[id] else { return }
            link.connection.cancel()
            self.removeLinkLocked(id)
        }
    }

    private func startLocked() {
        guard !running else { return }
        running = true
        publishRunning(true, status: "正在寻找同一局域网中的 VeilLink")

        do {
            let parameters = makeParameters()
            let listener = try NWListener(using: parameters)
            var advertisedService = NWListener.Service(
                name: serviceInstanceName,
                type: Self.serviceType,
                domain: nil,
                txtRecord: nil as Data?
            )
            advertisedService.noAutoRename = true
            listener.service = advertisedService
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                self.handleListenerStateLocked(state)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.registerLocked(connection: connection, role: .incoming, endpointKey: "incoming:\(UUID().uuidString)")
            }
            self.listener = listener
            listener.start(queue: queue)

            let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: parameters)
            browser.stateUpdateHandler = { [weak self] state in
                self?.handleBrowserStateLocked(state)
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                self?.handleBrowseResultsLocked(results)
            }
            self.browser = browser
            browser.start(queue: queue)
        } catch {
            running = false
            publishRunning(false, status: "局域网高速通道启动失败")
        }
    }

    private func stopLocked(publishStopped: Bool = true) {
        guard running || listener != nil || browser != nil || !links.isEmpty else { return }
        running = false
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
        let ids = Array(links.keys)
        for link in links.values { link.connection.cancel() }
        links.removeAll()
        endpointToLink.removeAll()
        discoveredEndpoints.removeAll()
        reconnectAttempts.removeAll()
        for item in reconnectWorkItems.values { item.cancel() }
        reconnectWorkItems.removeAll()
        publishMain { [weak self] in
            guard let self else { return }
            self.discoveredServiceCount = 0
            self.connectedPeerCount = 0
            self.linkSnapshots = [:]
            if publishStopped {
                self.isRunning = false
                self.statusText = "局域网高速通道已暂停"
            }
            for id in ids { self.onDisconnected?(id) }
        }
    }

    private func handleListenerStateLocked(_ state: NWListener.State) {
        switch state {
        case .ready:
            publishRunning(true, status: "LAN Turbo 已就绪 · 正在发现同网设备")
        case .failed(_):
            listener?.cancel()
            listener = nil
            publishRunning(running, status: "LAN Turbo 监听失败 · BLE 仍可用")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func handleBrowserStateLocked(_ state: NWBrowser.State) {
        switch state {
        case .failed(_):
            browser?.cancel()
            browser = nil
            publishMain { [weak self] in
                self?.statusText = "局域网发现不可用 · BLE 仍可用"
            }
        default:
            break
        }
    }

    private func handleBrowseResultsLocked(_ results: Set<NWBrowser.Result>) {
        guard running else { return }
        let endpoints = results.map(\.endpoint).filter { !isOwnService($0) }
        publishMain { [weak self] in self?.discoveredServiceCount = endpoints.count }

        var next: [String: NWEndpoint] = [:]
        for endpoint in endpoints where shouldInitiateConnection(to: endpoint) {
            next[endpointKey(endpoint)] = endpoint
        }
        let removed = Set(discoveredEndpoints.keys).subtracting(next.keys)
        for key in removed {
            reconnectWorkItems.removeValue(forKey: key)?.cancel()
            reconnectAttempts.removeValue(forKey: key)
        }
        discoveredEndpoints = next
        for (key, endpoint) in next where endpointToLink[key] == nil {
            connectToDiscoveredEndpointLocked(endpoint, key: key)
        }
    }

    private func connectToDiscoveredEndpointLocked(_ endpoint: NWEndpoint, key: String) {
        guard running, endpointToLink[key] == nil else { return }
        reconnectWorkItems.removeValue(forKey: key)?.cancel()
        let connection = NWConnection(to: endpoint, using: makeParameters())
        registerLocked(connection: connection, role: .outgoing, endpointKey: key)
    }

    private func scheduleReconnectLocked(endpointKey key: String) {
        guard running, endpointToLink[key] == nil, let endpoint = discoveredEndpoints[key] else { return }
        reconnectWorkItems.removeValue(forKey: key)?.cancel()
        let attempt = reconnectAttempts[key, default: 0]
        reconnectAttempts[key] = min(attempt + 1, 32)
        let delay = LANDataPlanePolicy.reconnectDelay(attempt: attempt)
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItems.removeValue(forKey: key)
            guard self.running, self.endpointToLink[key] == nil,
                  let latestEndpoint = self.discoveredEndpoints[key] else { return }
            self.connectToDiscoveredEndpointLocked(latestEndpoint, key: key)
        }
        reconnectWorkItems[key] = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func registerLocked(connection: NWConnection, role: LANTurboRole, endpointKey: String) {
        guard running, links.count < 12 else {
            connection.cancel()
            return
        }
        let id = UUID()
        let link = LANLink(id: id, connection: connection, role: role, endpointKey: endpointKey)
        links[id] = link
        if role == .outgoing { endpointToLink[endpointKey] = id }
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateLocked(id: id, state: state)
        }
        connection.start(queue: queue)
        publishSnapshotsLocked()
    }

    private func handleConnectionStateLocked(id: UUID, state: NWConnection.State) {
        guard let link = links[id] else { return }
        switch state {
        case .ready:
            guard !link.isReady else { return }
            link.isReady = true
            if link.role == .outgoing {
                reconnectAttempts.removeValue(forKey: link.endpointKey)
                reconnectWorkItems.removeValue(forKey: link.endpointKey)?.cancel()
            }
            receiveNextLocked(link)
            publishSnapshotsLocked()
            publishMain { [weak self] in
                guard let self else { return }
                self.connectedPeerCount = self.linkSnapshots.values.filter(\.isReady).count
                self.statusText = "LAN Turbo 已连接"
                self.onConnected?(id)
            }
        case .failed, .cancelled:
            removeLinkLocked(id)
        default:
            break
        }
    }

    private func receiveNextLocked(_ link: LANLink) {
        link.connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1_024) { [weak self] data, _, isComplete, error in
            guard let self, let current = self.links[link.id], current === link else { return }
            if let data, !data.isEmpty {
                do {
                    let frames = try current.decoder.append(data)
                    for frame in frames {
                        self.recordDataPlaneLocked(received: frame.count)
                        self.publishMain { [weak self] in self?.onReceive?(link.id, frame) }
                    }
                } catch {
                    current.connection.cancel()
                    self.removeLinkLocked(link.id)
                    return
                }
            }
            if error != nil || isComplete {
                current.connection.cancel()
                self.removeLinkLocked(link.id)
                return
            }
            self.receiveNextLocked(current)
        }
    }

    private func drainLocked(_ link: LANLink) {
        guard link.isReady else { return }
        while link.inFlightSends < maximumInFlightSends, let frame = link.outbound.popFirst() {
            link.inFlightSends += 1
            link.inFlightBytes += frame.count
            let sentBytes = frame.count
            link.connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                guard let self, let current = self.links[link.id], current === link else { return }
                current.inFlightSends = max(0, current.inFlightSends - 1)
                current.inFlightBytes = max(0, current.inFlightBytes - sentBytes)
                if error != nil {
                    current.connection.cancel()
                    self.removeLinkLocked(link.id)
                    return
                }
                self.recordDataPlaneLocked(sent: max(0, sentBytes - LANFrameCodec.headerBytes))
                self.drainLocked(current)
                self.publishSnapshotsLocked()
            })
        }
    }

    private func removeLinkLocked(_ id: UUID) {
        guard let link = links.removeValue(forKey: id) else { return }
        if endpointToLink[link.endpointKey] == id { endpointToLink.removeValue(forKey: link.endpointKey) }
        if link.role == .outgoing { scheduleReconnectLocked(endpointKey: link.endpointKey) }
        publishSnapshotsLocked()
        publishMain { [weak self] in
            guard let self else { return }
            self.connectedPeerCount = self.linkSnapshots.values.filter(\.isReady).count
            self.statusText = self.connectedPeerCount > 0 ? "LAN Turbo 已连接" : "LAN Turbo 已就绪 · 等待同网设备"
            self.onDisconnected?(id)
        }
    }

    private func recordDataPlaneLocked(sent: Int = 0, received: Int = 0) {
        if sent > 0 { sentPayloadBytes &+= UInt64(sent) }
        if received > 0 { receivedPayloadBytes &+= UInt64(received) }
        guard sent > 0 || received > 0 else { return }
        let sentTotal = sentPayloadBytes
        let receivedTotal = receivedPayloadBytes
        let now = Date()
        publishMain { [weak self] in
            guard let self else { return }
            self.totalPayloadBytesSent = sentTotal
            self.totalPayloadBytesReceived = receivedTotal
            self.lastDataPlaneActivityAt = now
        }
    }

    private func publishSnapshotsLocked() {
        let snapshots = Dictionary(uniqueKeysWithValues: links.values.map { link in
            (link.id, LANTurboLinkSnapshot(
                id: link.id,
                role: link.role,
                endpointDescription: link.endpointKey,
                isReady: link.isReady,
                pendingFrames: link.outbound.pendingCount + link.inFlightSends,
                pendingBytes: link.outbound.pendingBytes + link.inFlightBytes
            ))
        })
        publishMain { [weak self] in
            guard let self else { return }
            self.linkSnapshots = snapshots
            self.connectedPeerCount = snapshots.values.filter(\.isReady).count
        }
    }

    private func publishRunning(_ running: Bool, status: String) {
        publishMain { [weak self] in
            self?.isRunning = running
            self?.statusText = status
        }
    }

    private func publishMain(_ action: @escaping @Sendable () -> Void) {
        DispatchQueue.main.async(execute: action)
    }


    private func makeParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = peerToPeerBoostEnabled
        parameters.serviceClass = .responsiveData
        parameters.allowFastOpen = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        return parameters
    }

    private func isOwnService(_ endpoint: NWEndpoint) -> Bool {
        if case .service(let name, _, _, _) = endpoint { return name == serviceInstanceName }
        return false
    }

    private func shouldInitiateConnection(to endpoint: NWEndpoint) -> Bool {
        guard case .service(let name, _, _, _) = endpoint else { return true }
        // Both peers browse and listen. A deterministic service-name ordering ensures exactly
        // one side initiates, avoiding a pair of duplicate TCP sessions for the same two phones.
        return serviceInstanceName < name
    }

    private func endpointKey(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .service(let name, let type, let domain, _):
            return "service:\(name)|\(type)|\(domain)"
        default:
            return String(describing: endpoint)
        }
    }
}
#else
final class LANTransport: ObservableObject {
    static let serviceType = "_veillink._tcp"
    @Published private(set) var statusText = "当前平台不支持 LAN Turbo"
    @Published private(set) var isRunning = false
    @Published private(set) var discoveredServiceCount = 0
    @Published private(set) var connectedPeerCount = 0
    @Published private(set) var linkSnapshots: [UUID: LANTurboLinkSnapshot] = [:]
    @Published private(set) var totalPayloadBytesSent: UInt64 = 0
    @Published private(set) var totalPayloadBytesReceived: UInt64 = 0
    @Published private(set) var lastDataPlaneActivityAt: Date?
    @Published var peerToPeerBoostEnabled = true
    var onConnected: ((UUID) -> Void)?
    var onDisconnected: ((UUID) -> Void)?
    var onReceive: ((UUID, Data) -> Void)?
    func start() {}
    func stop() {}
    func refresh() {}
    func containsTransport(_ id: UUID) -> Bool { false }
    func isReadyTransport(_ id: UUID) -> Bool { false }
    var dataPlaneSummary: String { "TX 0 bytes · RX 0 bytes" }
    func send(_ payload: Data, to transportID: UUID, priority: BLESendPriority) -> TransportSendResult { .temporarilyUnavailable }
    func disconnect(_ id: UUID) {}
}
#endif
