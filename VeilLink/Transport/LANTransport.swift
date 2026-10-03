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

    // Large attachments must leave room for checkpoints, acknowledgements and live audio.
    static let controlReserveFrames = 8
    static let controlReserveBytes = 256 * 1_024
    static let interactiveReserveFrames = 24
    static let interactiveReserveBytes = 1 * 1_024 * 1_024

    // If Network.framework reports no send progress for this long, recycle the path so the
    // secure session can fall back to BLE and Bonjour can establish a fresh fast path.
    static let sendStallTimeout: TimeInterval = 12

    static func canEnqueue(
        priority: BLESendPriority,
        queuedFrames: Int,
        queuedBytes: Int,
        inFlightFrames: Int,
        inFlightBytes: Int,
        additionalBytes: Int,
        maximumFrames: Int,
        maximumBytes: Int
    ) -> Bool {
        guard additionalBytes > 0, maximumFrames > 0, maximumBytes > 0 else { return false }

        let reservedFrames: Int
        let reservedBytes: Int
        switch priority {
        case .control:
            reservedFrames = 0
            reservedBytes = 0
        case .realtime:
            reservedFrames = controlReserveFrames
            reservedBytes = controlReserveBytes
        case .bulk:
            reservedFrames = interactiveReserveFrames
            reservedBytes = interactiveReserveBytes
        }

        let frameBudget = max(1, maximumFrames - min(reservedFrames, maximumFrames - 1))
        let byteBudget = max(1, maximumBytes - min(reservedBytes, maximumBytes - 1))
        let totalFrames = queuedFrames + inFlightFrames + 1
        let totalBytes = queuedBytes + inFlightBytes + additionalBytes
        return totalFrames <= frameBudget && totalBytes <= byteBudget
    }

    static func reconnectDelay(attempt: Int) -> TimeInterval {
        let schedule: [TimeInterval] = [0.35, 0.80, 1.50, 3.0, 5.0]
        return schedule[min(max(attempt, 0), schedule.count - 1)]
    }
}

enum LANRefreshAction: Equatable {
    case start
    case preserveHealthyInfrastructure
    case repairMissingInfrastructure
}

enum LANInfrastructureRecoveryPolicy {
    private static let retrySchedule: [TimeInterval] = [0.35, 0.80, 1.50, 3.0, 5.0, 8.0]
    static let maximumAttempts = retrySchedule.count

    static func refreshAction(isRunning: Bool, hasListener: Bool, hasBrowser: Bool) -> LANRefreshAction {
        guard isRunning else { return .start }
        return hasListener && hasBrowser ? .preserveHealthyInfrastructure : .repairMissingInfrastructure
    }

    static func retryDelay(attempt: Int) -> TimeInterval? {
        guard attempt >= 0, attempt < maximumAttempts else { return nil }
        return retrySchedule[attempt]
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
    private var readOffset = 0

    mutating func append(_ bytes: Data) throws -> [Data] {
        guard !bytes.isEmpty else { return [] }
        storage.append(bytes)

        var output: [Data] = []
        while storage.count - readOffset >= LANFrameCodec.headerBytes {
            let headerStart = storage.index(storage.startIndex, offsetBy: readOffset)
            let headerEnd = storage.index(headerStart, offsetBy: LANFrameCodec.headerBytes)
            let length: UInt32 = storage[headerStart..<headerEnd].withUnsafeBytes { raw in
                raw.loadUnaligned(as: UInt32.self).bigEndian
            }
            let payloadBytes = Int(length)
            guard payloadBytes > 0, payloadBytes <= LANFrameCodec.maximumPayloadBytes else {
                reset()
                throw LANFrameError.invalidLength
            }
            let total = LANFrameCodec.headerBytes + payloadBytes
            guard storage.count - readOffset >= total else { break }
            let payloadStart = headerEnd
            let payloadEnd = storage.index(payloadStart, offsetBy: payloadBytes)
            output.append(Data(storage[payloadStart..<payloadEnd]))
            readOffset += total
        }
        compactIfNeeded()
        bufferedByteCount = storage.count - readOffset
        return output
    }

    mutating func reset() {
        storage.removeAll(keepingCapacity: false)
        readOffset = 0
        bufferedByteCount = 0
    }

    private mutating func compactIfNeeded() {
        guard readOffset > 0 else { return }
        if readOffset == storage.count {
            storage.removeAll(keepingCapacity: true)
            readOffset = 0
        } else if readOffset >= 64 * 1_024 || readOffset * 2 >= storage.count {
            let unreadStart = storage.index(storage.startIndex, offsetBy: readOffset)
            storage.removeSubrange(storage.startIndex..<unreadStart)
            readOffset = 0
        }
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
    var sendProgressGeneration: UInt64 = 0
    var sendStallWorkItem: DispatchWorkItem?

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
    private var listenerRecoveryAttempts = 0
    private var browserRecoveryAttempts = 0
    private var listenerRecoveryWorkItem: DispatchWorkItem?
    private var browserRecoveryWorkItem: DispatchWorkItem?
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
        queue.async { [weak self] in self?.refreshLocked() }
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
            guard LANDataPlanePolicy.canEnqueue(
                priority: priority,
                queuedFrames: link.outbound.pendingCount,
                queuedBytes: link.outbound.pendingBytes,
                inFlightFrames: link.inFlightSends,
                inFlightBytes: link.inFlightBytes,
                additionalBytes: frame.count,
                maximumFrames: maximumQueuedFrames,
                maximumBytes: maximumQueuedBytes
            ) else {
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
        guard !running else {
            ensureInfrastructureLocked(resetRecoveryBudget: false)
            return
        }
        running = true
        resetInfrastructureRecoveryLocked()
        publishRunning(true, status: "正在寻找同一局域网中的 VeilLink")
        ensureInfrastructureLocked(resetRecoveryBudget: false)
    }

    private func refreshLocked() {
        switch LANInfrastructureRecoveryPolicy.refreshAction(
            isRunning: running,
            hasListener: listener != nil,
            hasBrowser: browser != nil
        ) {
        case .start:
            startLocked()
        case .preserveHealthyInfrastructure:
            // Foreground/app-refresh probes must not cancel live connections or discard their
            // priority queues. Network.framework already keeps healthy listener/browser objects
            // current, so there is nothing destructive to refresh here.
            break
        case .repairMissingInfrastructure:
            ensureInfrastructureLocked(resetRecoveryBudget: true)
        }
    }

    private func ensureInfrastructureLocked(resetRecoveryBudget: Bool) {
        guard running else { return }
        if listener == nil {
            if resetRecoveryBudget {
                listenerRecoveryWorkItem?.cancel()
                listenerRecoveryWorkItem = nil
                listenerRecoveryAttempts = 0
            }
            startListenerLocked()
        }
        if browser == nil {
            if resetRecoveryBudget {
                browserRecoveryWorkItem?.cancel()
                browserRecoveryWorkItem = nil
                browserRecoveryAttempts = 0
            }
            startBrowserLocked()
        }
    }

    private func startListenerLocked() {
        guard running, listener == nil else { return }
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
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self, let listener else { return }
                self.handleListenerStateLocked(state, source: listener)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.registerLocked(connection: connection, role: .incoming, endpointKey: "incoming:\(UUID().uuidString)")
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            scheduleListenerRecoveryLocked()
        }
    }

    private func startBrowserLocked() {
        guard running, browser == nil else { return }
        let browser = NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: nil),
            using: makeParameters()
        )
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, let browser else { return }
            self.handleBrowserStateLocked(state, source: browser)
        }
        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            guard let self, let browser, self.browser === browser else { return }
            self.handleBrowseResultsLocked(results)
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    private func stopLocked(publishStopped: Bool = true) {
        guard running || listener != nil || browser != nil || !links.isEmpty else { return }
        running = false
        resetInfrastructureRecoveryLocked()
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
        let ids = Array(links.keys)
        for link in links.values {
            link.sendStallWorkItem?.cancel()
            link.connection.cancel()
        }
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

    private func handleListenerStateLocked(_ state: NWListener.State, source: NWListener) {
        guard listener === source else { return }
        switch state {
        case .ready:
            listenerRecoveryAttempts = 0
            listenerRecoveryWorkItem?.cancel()
            listenerRecoveryWorkItem = nil
            publishRunning(true, status: "LAN Turbo 已就绪 · 正在发现同网设备")
        case .failed(_):
            listener = nil
            source.cancel()
            publishRunning(running, status: "LAN Turbo 监听失败 · BLE 仍可用")
            scheduleListenerRecoveryLocked()
        case .cancelled:
            break
        default:
            break
        }
    }

    private func handleBrowserStateLocked(_ state: NWBrowser.State, source: NWBrowser) {
        guard browser === source else { return }
        switch state {
        case .ready:
            browserRecoveryAttempts = 0
            browserRecoveryWorkItem?.cancel()
            browserRecoveryWorkItem = nil
        case .failed(_):
            browser = nil
            source.cancel()
            publishMain { [weak self] in
                self?.statusText = "局域网发现不可用 · BLE 仍可用"
            }
            scheduleBrowserRecoveryLocked()
        default:
            break
        }
    }

    private func scheduleListenerRecoveryLocked() {
        guard running, listener == nil, listenerRecoveryWorkItem == nil else { return }
        guard let delay = LANInfrastructureRecoveryPolicy.retryDelay(attempt: listenerRecoveryAttempts) else {
            publishRunning(true, status: "LAN Turbo 监听恢复次数已达上限 · 可手动刷新")
            return
        }
        listenerRecoveryAttempts += 1
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.listenerRecoveryWorkItem = nil
            self.startListenerLocked()
        }
        listenerRecoveryWorkItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func scheduleBrowserRecoveryLocked() {
        guard running, browser == nil, browserRecoveryWorkItem == nil else { return }
        guard let delay = LANInfrastructureRecoveryPolicy.retryDelay(attempt: browserRecoveryAttempts) else {
            publishRunning(true, status: "LAN Turbo 发现恢复次数已达上限 · 可手动刷新")
            return
        }
        browserRecoveryAttempts += 1
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.browserRecoveryWorkItem = nil
            self.startBrowserLocked()
        }
        browserRecoveryWorkItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func resetInfrastructureRecoveryLocked() {
        listenerRecoveryWorkItem?.cancel()
        listenerRecoveryWorkItem = nil
        browserRecoveryWorkItem?.cancel()
        browserRecoveryWorkItem = nil
        listenerRecoveryAttempts = 0
        browserRecoveryAttempts = 0
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
        guard running, endpointToLink[key] == nil, discoveredEndpoints[key] != nil else { return }
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
                current.sendStallWorkItem?.cancel()
                current.sendStallWorkItem = nil
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
        armSendStallWatchdogLocked(link)
    }

    private func armSendStallWatchdogLocked(_ link: LANLink) {
        guard link.inFlightSends > 0, link.sendStallWorkItem == nil else { return }
        link.sendProgressGeneration &+= 1
        let generation = link.sendProgressGeneration

        let item = DispatchWorkItem { [weak self, weak link] in
            guard let self, let link,
                  let current = self.links[link.id], current === link,
                  current.sendProgressGeneration == generation,
                  current.inFlightSends > 0 else { return }
            current.connection.cancel()
            self.removeLinkLocked(current.id)
        }
        link.sendStallWorkItem = item
        queue.asyncAfter(deadline: .now() + LANDataPlanePolicy.sendStallTimeout, execute: item)
    }

    private func removeLinkLocked(_ id: UUID) {
        guard let link = links.removeValue(forKey: id) else { return }
        link.sendStallWorkItem?.cancel()
        link.sendStallWorkItem = nil
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
