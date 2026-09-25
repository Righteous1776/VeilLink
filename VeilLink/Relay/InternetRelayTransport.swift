import Combine
import Foundation

struct VeilRelayProviderSnapshot: Identifiable, Equatable, Sendable {
    let region: VeilRelayRegion
    var reachable: Bool
    var roundTripMilliseconds: Double?
    var lastSuccessAt: Date?
    var consecutiveFailures: Int

    var id: String { region.rawValue }
}

@MainActor
final class InternetRelayTransport: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var statusText = "远程中继未启动"
    @Published private(set) var connectedPeerCount = 0
    @Published private(set) var providerSnapshots: [VeilRelayRegion: VeilRelayProviderSnapshot] = [:]

    var onConnected: ((UUID) -> Void)?
    var onDisconnected: ((UUID) -> Void)?
    var onReceive: ((UUID, Data) -> Void)?

    private unowned let identity: IdentityManager
    private unowned let database: DatabaseStore
    private let capabilities: VeilRelayCapabilityStore
    private let settings = VeilRelaySettings.shared
    private let session: URLSession
    private var activePeers: [String: UUID] = [:]
    private var peerIDsByTransport: [UUID: String] = [:]
    private var knownPeerIdentityIDs: Set<String> = []
    private var pollTask: Task<Void, Never>?
    private var probeTask: Task<Void, Never>?
    private var isForegroundActive = true
    private var deliveredIDs: Set<String> = []
    private var deliveredOrder: [String] = []
    private let maximumDeliveredIDs = 2048

    init(identity: IdentityManager, database: DatabaseStore, capabilities: VeilRelayCapabilityStore) {
        self.identity = identity
        self.database = database
        self.capabilities = capabilities
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
        for region in VeilRelayRegion.allCases {
            providerSnapshots[region] = VeilRelayProviderSnapshot(
                region: region, reachable: false, roundTripMilliseconds: nil,
                lastSuccessAt: nil, consecutiveFailures: 0
            )
        }
    }

    func start(peerIdentityIDs: [String]) {
        knownPeerIdentityIDs = Set(peerIdentityIDs)
        guard settings.enabled else {
            stop(reason: "远程中继已关闭")
            return
        }
        guard identity.activeIdentity != nil else { return }
        isRunning = true
        statusText = "正在探测国内 / 国际中继"
        refreshPeers(peerIdentityIDs: peerIdentityIDs)
        restartLoops()
    }

    func stop(reason: String = "远程中继已停止") {
        pollTask?.cancel(); pollTask = nil
        probeTask?.cancel(); probeTask = nil
        for transportID in activePeers.values { onDisconnected?(transportID) }
        activePeers.removeAll()
        peerIDsByTransport.removeAll()
        connectedPeerCount = 0
        isRunning = false
        statusText = reason
    }

    func setForegroundActive(_ active: Bool) {
        isForegroundActive = active
        if isRunning { restartLoops() }
    }

    func refreshPeers(peerIdentityIDs: [String]) {
        knownPeerIdentityIDs = Set(peerIdentityIDs)
        guard settings.enabled, let localID = identity.activeIdentity?.id else { return }

        let desired = Set(peerIdentityIDs.filter { peerID in
            database.trustedContact(localIdentityID: localID, identityID: peerID) != nil &&
            capabilities.secret(for: peerID) != nil
        })

        for peerID in Array(activePeers.keys) where !desired.contains(peerID) {
            if let id = activePeers.removeValue(forKey: peerID) {
                peerIDsByTransport.removeValue(forKey: id)
                onDisconnected?(id)
            }
        }

        guard hasUsableProvider else {
            connectedPeerCount = activePeers.count
            return
        }
        for peerID in desired where activePeers[peerID] == nil {
            guard let secret = capabilities.secret(for: peerID),
                  let transportID = VeilRelayCrypto.transportID(pairSecret: secret, localIdentityID: localID, peerIdentityID: peerID) else { continue }
            activePeers[peerID] = transportID
            peerIDsByTransport[transportID] = peerID
            onConnected?(transportID)
        }
        connectedPeerCount = activePeers.count
        updateStatus()
    }

    func containsTransport(_ id: UUID) -> Bool {
        peerIDsByTransport[id] != nil
    }

    func disconnect(_ id: UUID) {
        guard let peerID = peerIDsByTransport.removeValue(forKey: id) else { return }
        activePeers.removeValue(forKey: peerID)
        connectedPeerCount = activePeers.count
        onDisconnected?(id)
    }

    @discardableResult
    func send(_ data: Data, to transportID: UUID, priority: BLESendPriority) -> TransportSendResult {
        guard isRunning, settings.enabled,
              let peerID = peerIDsByTransport[transportID],
              let localID = identity.activeIdentity?.id,
              let pairSecret = capabilities.secret(for: peerID),
              !data.isEmpty, data.count <= VeilRelayCrypto.maximumWireEnvelopeBytes else {
            return .temporarilyUnavailable
        }
        let providers = selectedProviders(forByteCount: data.count, priority: priority)
        guard !providers.isEmpty else { return .temporarilyUnavailable }

        let deliveryID = UUID().uuidString
        let epoch = VeilRelayCrypto.epoch()
        var requests: [(VeilRelayRegion, VeilRelayPushRequest)] = []
        do {
            for region in providers {
                let route = try VeilRelayCrypto.route(
                    pairSecret: pairSecret, senderIdentityID: localID,
                    receiverIdentityID: peerID, provider: region, epoch: epoch
                )
                let body = try VeilRelayCrypto.seal(
                    wireEnvelope: data, deliveryID: deliveryID, pairSecret: pairSecret,
                    senderIdentityID: localID, receiverIdentityID: peerID,
                    provider: region, epoch: epoch
                )
                requests.append((region, VeilRelayPushRequest(
                    version: VeilRelayCrypto.protocolVersion,
                    packetID: UUID().uuidString,
                    mailbox: route.mailboxID,
                    writeToken: route.writeToken,
                    expiresAt: Date().addingTimeInterval(settings.messageTTLSeconds),
                    body: body
                )))
            }
        } catch {
            return .unsupportedLink
        }

        Task { @MainActor [weak self] in
            await self?.sendRequests(requests, allowFallback: providers.count == 1)
        }
        return .accepted
    }

    func refreshNow() {
        guard isRunning else { return }
        Task { @MainActor [weak self] in
            await self?.probeProviders()
            await self?.pollOnce()
        }
    }

    private var hasUsableProvider: Bool {
        selectedConfiguredRegions.contains { providerSnapshots[$0]?.reachable == true }
    }

    private var selectedConfiguredRegions: [VeilRelayRegion] {
        VeilRelayRegion.allCases.filter { region in
            settings.configuration(for: region).enabled && settings.configuration(for: region).baseURL != nil
        }
    }

    private func restartLoops() {
        pollTask?.cancel()
        probeTask?.cancel()
        probeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.probeProviders()
                self.refreshPeers(peerIdentityIDs: Array(self.knownPeerIdentityIDs))
                try? await Task.sleep(nanoseconds: self.isForegroundActive ? 20_000_000_000 : 60_000_000_000)
            }
        }
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollOnce()
                let interval: UInt64 = self.isForegroundActive ? 900_000_000 : 5_000_000_000
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func selectedProviders(forByteCount count: Int, priority: BLESendPriority) -> [VeilRelayRegion] {
        let healthy = selectedConfiguredRegions.filter { providerSnapshots[$0]?.reachable == true }
        guard !healthy.isEmpty else { return [] }
        switch settings.mode {
        case .domesticOnly:
            return healthy.contains(.domestic) ? [.domestic] : []
        case .internationalOnly:
            return healthy.contains(.international) ? [.international] : []
        case .privacyFirst:
            return [bestProvider(from: healthy)]
        case .smartDual:
            if count <= 64 * 1024 && priority != .bulk && healthy.count > 1 {
                return healthy.sorted { latency(of: $0) < latency(of: $1) }
            }
            return [bestProvider(from: healthy)]
        }
    }

    private func bestProvider(from regions: [VeilRelayRegion]) -> VeilRelayRegion {
        regions.min { lhs, rhs in latency(of: lhs) < latency(of: rhs) } ?? regions[0]
    }

    private func latency(of region: VeilRelayRegion) -> Double {
        providerSnapshots[region]?.roundTripMilliseconds ?? 9_999
    }

    private func sendRequests(_ requests: [(VeilRelayRegion, VeilRelayPushRequest)], allowFallback: Bool) async {
        if requests.count >= 2 {
            let first = requests[0]
            let second = requests[1]
            async let firstResult = postJSON(first.1, region: first.0, path: "v1/push")
            async let secondResult = postJSON(second.1, region: second.0, path: "v1/push")
            let results = await (firstResult, secondResult)
            if !results.0 && !results.1 {
                markFailure(first.0)
                markFailure(second.0)
            }
            return
        }
        guard let only = requests.first else { return }
        let succeeded = await postJSON(only.1, region: only.0, path: "v1/push")
        if !succeeded, allowFallback {
            // The SessionCoordinator outbox keeps the message pending until the peer ACK arrives.
            // Marking this provider unhealthy lets the next retry choose the other region without
            // consuming a second VeilLink sequence number for the same local send attempt.
            markFailure(only.0)
        }
    }

    private func probeProviders() async {
        for region in selectedConfiguredRegions {
            guard let base = settings.configuration(for: region).baseURL else { continue }
            let start = Date()
            do {
                var request = URLRequest(url: base.appendingPathComponent("v1/health"))
                request.timeoutInterval = 5
                let (_, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                let rtt = Date().timeIntervalSince(start) * 1_000
                var snapshot = providerSnapshots[region] ?? VeilRelayProviderSnapshot(region: region, reachable: true, roundTripMilliseconds: nil, lastSuccessAt: nil, consecutiveFailures: 0)
                snapshot.reachable = true
                snapshot.roundTripMilliseconds = snapshot.roundTripMilliseconds.map { $0 * 0.70 + rtt * 0.30 } ?? rtt
                snapshot.lastSuccessAt = Date()
                snapshot.consecutiveFailures = 0
                providerSnapshots[region] = snapshot
            } catch {
                markFailure(region)
            }
        }
        updateStatus()
    }

    private func pollOnce() async {
        guard isRunning, let localID = identity.activeIdentity?.id else { return }
        for (peerID, transportID) in activePeers {
            guard let secret = capabilities.secret(for: peerID) else { continue }
            for region in selectedConfiguredRegions where providerSnapshots[region]?.reachable == true {
                for epoch in VeilRelayCrypto.inboundEpochs() {
                    do {
                        let route = try VeilRelayCrypto.route(
                            pairSecret: secret, senderIdentityID: peerID,
                            receiverIdentityID: localID, provider: region, epoch: epoch
                        )
                        _ = await register(route: route, region: region)
                        let packets = await pull(route: route, region: region)
                        var acceptedPacketIDs: [String] = []
                        for packet in packets {
                            guard packet.expiresAt > Date() else { acceptedPacketIDs.append(packet.packetID); continue }
                            do {
                                let frame = try VeilRelayCrypto.open(
                                    body: packet.body, pairSecret: secret,
                                    senderIdentityID: peerID, receiverIdentityID: localID,
                                    provider: region, epoch: epoch
                                )
                                if rememberDeliveryID(frame.deliveryID) {
                                    onReceive?(transportID, frame.wireEnvelope)
                                }
                                acceptedPacketIDs.append(packet.packetID)
                            } catch {
                                acceptedPacketIDs.append(packet.packetID)
                            }
                        }
                        if !acceptedPacketIDs.isEmpty { await acknowledge(route: route, region: region, packetIDs: acceptedPacketIDs) }
                    } catch {
                        continue
                    }
                }
            }
        }
    }

    private func register(route: VeilRelayRouteDescriptor, region: VeilRelayRegion) async -> Bool {
        await postJSON(VeilRelayRegisterRequest(
            version: VeilRelayCrypto.protocolVersion,
            mailbox: route.mailboxID,
            readToken: route.readToken,
            writeToken: route.writeToken,
            expiresAt: Date().addingTimeInterval(9 * 24 * 60 * 60)
        ), region: region, path: "v1/register")
    }

    private func pull(route: VeilRelayRouteDescriptor, region: VeilRelayRegion) async -> [VeilRelayStoredPacket] {
        guard let base = settings.configuration(for: region).baseURL else { return [] }
        var components = URLComponents(url: base.appendingPathComponent("v1/pull"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "mailbox", value: route.mailboxID)]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(route.readToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 7
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let decoded = try decoder.decode(VeilRelayPullResponse.self, from: data)
            markSuccess(region)
            return Array(decoded.packets.prefix(32))
        } catch {
            markFailure(region)
            return []
        }
    }

    private func acknowledge(route: VeilRelayRouteDescriptor, region: VeilRelayRegion, packetIDs: [String]) async {
        _ = await postJSON(VeilRelayAckRequest(
            version: VeilRelayCrypto.protocolVersion,
            mailbox: route.mailboxID,
            readToken: route.readToken,
            packetIDs: Array(packetIDs.prefix(32))
        ), region: region, path: "v1/ack")
    }

    private func postJSON<T: Encodable>(_ value: T, region: VeilRelayRegion, path: String) async -> Bool {
        guard let base = settings.configuration(for: region).baseURL else { return false }
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            request.httpBody = try encoder.encode(value)
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            markSuccess(region)
            return true
        } catch {
            markFailure(region)
            return false
        }
    }

    private func rememberDeliveryID(_ id: String) -> Bool {
        guard deliveredIDs.insert(id).inserted else { return false }
        deliveredOrder.append(id)
        if deliveredOrder.count > maximumDeliveredIDs {
            let excess = deliveredOrder.count - maximumDeliveredIDs
            for old in deliveredOrder.prefix(excess) { deliveredIDs.remove(old) }
            deliveredOrder.removeFirst(excess)
        }
        return true
    }

    private func markSuccess(_ region: VeilRelayRegion) {
        var snapshot = providerSnapshots[region] ?? VeilRelayProviderSnapshot(region: region, reachable: true, roundTripMilliseconds: nil, lastSuccessAt: nil, consecutiveFailures: 0)
        snapshot.reachable = true
        snapshot.lastSuccessAt = Date()
        snapshot.consecutiveFailures = 0
        providerSnapshots[region] = snapshot
        updateStatus()
    }

    private func markFailure(_ region: VeilRelayRegion) {
        var snapshot = providerSnapshots[region] ?? VeilRelayProviderSnapshot(region: region, reachable: false, roundTripMilliseconds: nil, lastSuccessAt: nil, consecutiveFailures: 0)
        snapshot.consecutiveFailures += 1
        if snapshot.consecutiveFailures >= 2 { snapshot.reachable = false }
        providerSnapshots[region] = snapshot
        updateStatus()
    }

    private func updateStatus() {
        let cn = providerSnapshots[.domestic]?.reachable == true
        let global = providerSnapshots[.international]?.reachable == true
        switch (cn, global) {
        case (true, true): statusText = "国内 + 国际双通道可用"
        case (true, false): statusText = "国内中继可用 · 国际待恢复"
        case (false, true): statusText = "国际中继可用 · 国内待恢复"
        case (false, false): statusText = settings.enabled ? "中继端点未配置或暂不可达" : "远程中继已关闭"
        }
    }
}

@MainActor
final class VeilRelaySettings: ObservableObject {
    static let shared = VeilRelaySettings()

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Key.enabled) } }
    @Published var mode: VeilRelayMode { didSet { defaults.set(mode.rawValue, forKey: Key.mode) } }
    @Published var domesticEndpoint: String { didSet { defaults.set(domesticEndpoint, forKey: Key.domestic) } }
    @Published var internationalEndpoint: String { didSet { defaults.set(internationalEndpoint, forKey: Key.international) } }
    @Published var messageTTLHours: Double { didSet { defaults.set(messageTTLHours, forKey: Key.ttlHours) } }

    private let defaults = UserDefaults.standard
    private enum Key {
        static let enabled = "relay.internet.enabled"
        static let mode = "relay.internet.mode"
        static let domestic = "relay.internet.domestic.endpoint"
        static let international = "relay.internet.international.endpoint"
        static let ttlHours = "relay.internet.ttl.hours"
    }

    private init() {
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? false
        mode = VeilRelayMode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .smartDual
        domesticEndpoint = defaults.string(forKey: Key.domestic) ?? ""
        internationalEndpoint = defaults.string(forKey: Key.international) ?? ""
        let storedTTL = defaults.double(forKey: Key.ttlHours)
        messageTTLHours = storedTTL > 0 ? min(max(storedTTL, 1), 168) : 24
    }

    var messageTTLSeconds: TimeInterval { min(max(messageTTLHours, 1), 168) * 60 * 60 }

    func configuration(for region: VeilRelayRegion) -> VeilRelayProviderConfiguration {
        let raw = region == .domestic ? domesticEndpoint : internationalEndpoint
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: normalized).flatMap { ["https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
        return VeilRelayProviderConfiguration(region: region, baseURL: url, enabled: enabled && !normalized.isEmpty)
    }
}
