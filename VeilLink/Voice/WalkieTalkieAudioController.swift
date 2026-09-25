import AVFoundation
import Combine
import Foundation

enum VeilWalkieState: Equatable {
    case idle
    case preparing
    case transmitting
    case receiving(String)
    case error(String)

    var shortLabel: String {
        switch self {
        case .idle: return "STBY"
        case .preparing: return "ARM"
        case .transmitting: return "TX"
        case .receiving: return "RX"
        case .error: return "ERR"
        }
    }
}

@MainActor
final class VeilWalkieTalkieAudioController: ObservableObject {
    @Published private(set) var state: VeilWalkieState = .idle
    @Published private(set) var meter: Float = 0
    @Published private(set) var droppedFrames = 0
    @Published private(set) var concealedFrames = 0
    @Published private(set) var lateFrames = 0
    @Published private(set) var jitterDepth = 0
    @Published private(set) var transmitDroppedFrames = 0
    @Published private(set) var activeTalkID: String?

    var sendControl: ((VeilPTTControlPacket, [String]) -> Void)?
    var sendAudioFrame: ((VeilPTTAudioFrame, [String]) -> VeilPTTSendReport)?

    private let captureEngine = AVAudioEngine()
    private let playbackEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let tuning: VeilRealtimeAudioTuning
    private var jitter: VeilPTTJitterBuffer
    private var recipients: [String] = []
    private var frameIndex: UInt32 = 0
    private var pendingMuLaw = Data()
    private var pendingMuLawOffset = 0
    private var receivingTalkID: String?
    private var receivingPeerID: String?
    private var playoutTimer: Timer?
    private var lastIncomingAt: Date?
    private var lastMeterPublishAt = Date.distantPast
    private var lastJitterPublishAt = Date.distantPast
    private let maintenanceTuning = VeilRuntimeMaintenanceTuning.resolved(performanceLabel: VeilDevicePerformance.current.label)
    private let frameBytes = 640 // 80 ms @ 8 kHz, G.711 µ-law
    private let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8_000, channels: 1, interleaved: false)
    private let silenceFrame = Data(repeating: 0xFF, count: 640)

    init() {
        let tuning = VeilRealtimeAudioTuning.resolved(performanceLabel: VeilDevicePerformance.current.label)
        self.tuning = tuning
        self.jitter = VeilPTTJitterBuffer(
            frameBytes: frameBytes,
            targetDepth: tuning.targetJitterFrames,
            maximumBufferedFrames: tuning.maximumJitterFrames,
            missingFramePatienceTicks: tuning.missingFramePatienceTicks
        )
        playbackEngine.attach(playerNode)
        if let playbackFormat {
            playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackFormat)
        }
    }

    var signalLabel: String {
        if state == .idle { return "READY" }
        let events = droppedFrames + transmitDroppedFrames
        if events == 0 { return "LOCK" }
        if events <= 2 { return "FAIR" }
        return "WEAK"
    }

    func beginTransmit(recipients: [String]) {
        let unique = Array(Set(recipients)).sorted()
        guard !unique.isEmpty, state != .transmitting else { return }
        if case .receiving = state { return } // half-duplex: current RX owns the channel
        self.recipients = unique
        state = .preparing
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted: startCapture()
        case .denied: state = .error("麦克风权限已关闭")
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    granted ? self.startCapture() : (self.state = .error("没有麦克风权限"))
                }
            }
        @unknown default: state = .error("麦克风状态未知")
        }
    }

    func endTransmit() {
        guard state == .transmitting || state == .preparing else { return }
        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()
        let pendingCount = pendingMuLaw.count - pendingMuLawOffset
        if state == .transmitting,
           let talkID = activeTalkID,
           pendingCount >= 160 {
            var tail = Data(pendingMuLaw[pendingMuLawOffset...])
            if tail.count < frameBytes { tail.append(Data(repeating: 0xFF, count: frameBytes - tail.count)) }
            let report = sendAudioFrame?(VeilPTTAudioFrame(talkID: talkID, index: frameIndex, muLawBytes: Data(tail.prefix(frameBytes))), recipients)
            transmitDroppedFrames += report?.dropped ?? 0
            frameIndex &+= 1
        }
        if let talkID = activeTalkID {
            sendControl?(VeilPTTControlPacket(talkID: talkID, kind: .end), recipients)
        }
        pendingMuLaw.removeAll(keepingCapacity: true)
        pendingMuLawOffset = 0
        activeTalkID = nil
        recipients = []
        meter = 0
        state = .idle
    }

    func receiveControl(_ incoming: VeilPTTIncomingControl) {
        guard state != .transmitting && state != .preparing else { return }
        switch incoming.packet.kind {
        case .begin:
            if let receivingTalkID, receivingTalkID != incoming.packet.talkID { return }
            receivingTalkID = incoming.packet.talkID
            receivingPeerID = incoming.peerIdentityID
            jitter.reset()
            publishJitterSnapshot(force: true)
            lastIncomingAt = Date()
            state = .receiving(incoming.peerIdentityID)
            preparePlaybackIfNeeded()
            startPlayoutTimer(frameDurationMilliseconds: incoming.packet.frameDurationMilliseconds)
        case .end:
            guard receivingTalkID == incoming.packet.talkID,
                  receivingPeerID == incoming.peerIdentityID else { return }
            jitter.markEnded()
            lastIncomingAt = Date()
            playoutTick()
        }
    }

    func receiveAudio(_ incoming: VeilPTTIncomingAudio) {
        guard state != .transmitting,
              receivingTalkID == incoming.frame.talkID,
              receivingPeerID == incoming.peerIdentityID else { return }
        _ = jitter.push(index: incoming.frame.index, bytes: incoming.frame.muLawBytes)
        lastIncomingAt = Date()
        publishJitterSnapshot()
    }

    func stopAll() {
        if state == .transmitting || state == .preparing { endTransmit() }
        playoutTimer?.invalidate(); playoutTimer = nil
        playerNode.stop(); playbackEngine.stop()
        receivingTalkID = nil; receivingPeerID = nil; lastIncomingAt = nil
        jitter.reset(); publishJitterSnapshot(force: true)
        meter = 0; state = .idle
    }

    private func startCapture() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredIOBufferDuration(tuning.preferredIOBufferDuration)
            try session.setActive(true)
            let input = captureEngine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else { throw NSError(domain: "VeilPTT", code: 1) }
            let talkID = UUID().uuidString
            activeTalkID = talkID
            frameIndex = 0
            transmitDroppedFrames = 0
            pendingMuLaw.removeAll(keepingCapacity: true)
            pendingMuLawOffset = 0
            sendControl?(VeilPTTControlPacket(talkID: talkID, kind: .begin), recipients)
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(tuning.captureBufferFrames), format: format) { [weak self] buffer, _ in
                guard let self else { return }
                let encoded = Self.downsampleAndEncode(buffer: buffer, sourceRate: format.sampleRate)
                guard !encoded.isEmpty else { return }
                Task { @MainActor [weak self] in self?.consumeCaptured(encoded) }
            }
            captureEngine.prepare()
            try captureEngine.start()
            state = .transmitting
        } catch {
            state = .error("PTT 启动失败")
            stopAll()
        }
    }

    private func consumeCaptured(_ data: Data) {
        guard state == .transmitting, let talkID = activeTalkID else { return }
        pendingMuLaw.append(data)
        let now = Date()
        if now.timeIntervalSince(lastMeterPublishAt) >= tuning.meterPublishInterval {
            let sampleCount = max(1, min(160, data.count))
            let energy = data.prefix(sampleCount).reduce(0.0) { partial, byte in
                partial + abs(Double(VeilMuLaw.decode(byte))) / Double(Int16.max)
            }
            meter = Float(min(1, energy / Double(sampleCount) * 5.5))
            lastMeterPublishAt = now
        }
        while pendingMuLaw.count - pendingMuLawOffset >= frameBytes {
            let upper = pendingMuLawOffset + frameBytes
            let frameData = Data(pendingMuLaw[pendingMuLawOffset..<upper])
            pendingMuLawOffset = upper
            let report = sendAudioFrame?(VeilPTTAudioFrame(talkID: talkID, index: frameIndex, muLawBytes: frameData), recipients)
            transmitDroppedFrames += report?.dropped ?? 0
            frameIndex &+= 1
        }
        if pendingMuLawOffset >= 4_096 || pendingMuLawOffset * 2 >= pendingMuLaw.count {
            pendingMuLaw = Data(pendingMuLaw.dropFirst(pendingMuLawOffset))
            pendingMuLawOffset = 0
        }
    }

    private func startPlayoutTimer(frameDurationMilliseconds: Int) {
        playoutTimer?.invalidate()
        let interval = max(0.04, min(0.16, Double(frameDurationMilliseconds) / 1_000.0))
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.playoutTick() }
        }
        timer.tolerance = min(0.012, interval * 0.15)
        RunLoop.main.add(timer, forMode: .common)
        playoutTimer = timer
    }

    private func playoutTick() {
        guard receivingTalkID != nil else { return }
        if let lastIncomingAt, Date().timeIntervalSince(lastIncomingAt) > 1.4 {
            jitter.markEnded()
        }
        switch jitter.nextForPlayout() {
        case .frame(let bytes):
            schedulePlayback(bytes)
        case .conceal(let count):
            schedulePlayback(count == frameBytes ? silenceFrame : Data(repeating: 0xFF, count: count))
        case .wait:
            break
        case .finished:
            finishReceiving()
        }
        publishJitterSnapshot()
    }

    private func finishReceiving() {
        playoutTimer?.invalidate(); playoutTimer = nil
        publishJitterSnapshot(force: true)
        receivingTalkID = nil
        receivingPeerID = nil
        lastIncomingAt = nil
        meter = 0
        state = .idle
    }

    private func publishJitterSnapshot(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastJitterPublishAt) >= maintenanceTuning.jitterStatsPublishInterval else { return }
        let snapshot = jitter.snapshot
        if jitterDepth != snapshot.queuedFrames { jitterDepth = snapshot.queuedFrames }
        if concealedFrames != snapshot.concealedFrames { concealedFrames = snapshot.concealedFrames }
        let newLateFrames = snapshot.lateFrames + snapshot.duplicateFrames + snapshot.overflowDrops
        if lateFrames != newLateFrames { lateFrames = newLateFrames }
        if droppedFrames != snapshot.lossLikeEvents { droppedFrames = snapshot.lossLikeEvents }
        lastJitterPublishAt = now
    }

    private func preparePlaybackIfNeeded() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredIOBufferDuration(tuning.preferredIOBufferDuration)
            try session.setActive(true)
            if !playbackEngine.isRunning { playbackEngine.prepare(); try playbackEngine.start() }
            if !playerNode.isPlaying { playerNode.play() }
        } catch { state = .error("扬声器启动失败") }
    }

    private func schedulePlayback(_ bytes: Data) {
        guard let playbackFormat,
              let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(bytes.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(bytes.count)
        for (i, byte) in bytes.enumerated() { channel[i] = Float(VeilMuLaw.decode(byte)) / Float(Int16.max) }
        if !playbackEngine.isRunning || !playerNode.isPlaying { preparePlaybackIfNeeded() }
        playerNode.scheduleBuffer(buffer)
    }

    nonisolated private static func downsampleAndEncode(buffer: AVAudioPCMBuffer, sourceRate: Double) -> Data {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return Data() }
        let count = Int(buffer.frameLength)
        let step = max(1.0, sourceRate / 8_000.0)
        var position = 0.0
        var out = Data(); out.reserveCapacity(Int(Double(count) / step) + 2)
        while Int(position) < count {
            let sample = max(-1.0, min(1.0, channel[Int(position)]))
            let pcm = Int16(sample * Float(Int16.max))
            out.append(VeilMuLaw.encode(pcm))
            position += step
        }
        return out
    }
}
