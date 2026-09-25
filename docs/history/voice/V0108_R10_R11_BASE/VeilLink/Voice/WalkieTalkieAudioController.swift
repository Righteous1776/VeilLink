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
    @Published private(set) var activeTalkID: String?

    var sendControl: ((VeilPTTControlPacket, [String]) -> Void)?
    var sendAudioFrame: ((VeilPTTAudioFrame, [String]) -> Void)?

    private let captureEngine = AVAudioEngine()
    private let playbackEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var recipients: [String] = []
    private var frameIndex: UInt32 = 0
    private var pendingMuLaw = Data()
    private var receivingTalkID: String?
    private var receivingPeerID: String?
    private var lastIncomingFrameIndex: UInt32?
    private let frameBytes = 640 // 80 ms @ 8 kHz, G.711 µ-law

    init() {
        playbackEngine.attach(playerNode)
        if let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8_000, channels: 1, interleaved: false) {
            playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: format)
        }
    }

    func beginTransmit(recipients: [String]) {
        let unique = Array(Set(recipients)).sorted()
        guard !unique.isEmpty, state != .transmitting else { return }
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
        if let talkID = activeTalkID {
            sendControl?(VeilPTTControlPacket(talkID: talkID, kind: .end), recipients)
        }
        pendingMuLaw.removeAll(keepingCapacity: true)
        activeTalkID = nil
        recipients = []
        meter = 0
        state = .idle
    }

    func receiveControl(_ incoming: VeilPTTIncomingControl) {
        guard state != .transmitting else { return }
        switch incoming.packet.kind {
        case .begin:
            receivingTalkID = incoming.packet.talkID
            receivingPeerID = incoming.peerIdentityID
            lastIncomingFrameIndex = nil
            state = .receiving(incoming.peerIdentityID)
            preparePlaybackIfNeeded()
        case .end:
            guard receivingTalkID == incoming.packet.talkID else { return }
            receivingTalkID = nil
            receivingPeerID = nil
            lastIncomingFrameIndex = nil
            state = .idle
        }
    }

    func receiveAudio(_ incoming: VeilPTTIncomingAudio) {
        guard state != .transmitting,
              receivingTalkID == incoming.frame.talkID,
              receivingPeerID == incoming.peerIdentityID else { return }
        if let lastIncomingFrameIndex, incoming.frame.index <= lastIncomingFrameIndex { droppedFrames += 1; return }
        if let lastIncomingFrameIndex, incoming.frame.index > lastIncomingFrameIndex + 1 {
            droppedFrames += Int(incoming.frame.index - lastIncomingFrameIndex - 1)
        }
        lastIncomingFrameIndex = incoming.frame.index
        schedulePlayback(incoming.frame.muLawBytes)
    }

    func stopAll() {
        if state == .transmitting || state == .preparing { endTransmit() }
        playerNode.stop(); playbackEngine.stop()
        receivingTalkID = nil; receivingPeerID = nil; lastIncomingFrameIndex = nil
        meter = 0; state = .idle
    }

    private func startCapture() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try session.setPreferredIOBufferDuration(0.04)
            try session.setActive(true)
            let input = captureEngine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else { throw NSError(domain: "VeilPTT", code: 1) }
            let talkID = UUID().uuidString
            activeTalkID = talkID
            frameIndex = 0
            pendingMuLaw.removeAll(keepingCapacity: true)
            sendControl?(VeilPTTControlPacket(talkID: talkID, kind: .begin), recipients)
            input.installTap(onBus: 0, bufferSize: 1_920, format: format) { [weak self] buffer, _ in
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
        let energy = data.prefix(160).reduce(0.0) { partial, byte in
            partial + abs(Double(VeilMuLaw.decode(byte))) / Double(Int16.max)
        }
        meter = Float(min(1, energy / Double(max(1, min(160, data.count))) * 5.5))
        while pendingMuLaw.count >= frameBytes {
            let frameData = Data(pendingMuLaw.prefix(frameBytes))
            pendingMuLaw.removeFirst(frameBytes)
            sendAudioFrame?(VeilPTTAudioFrame(talkID: talkID, index: frameIndex, muLawBytes: frameData), recipients)
            frameIndex &+= 1
        }
    }

    private func preparePlaybackIfNeeded() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try session.setActive(true)
            if !playbackEngine.isRunning { playbackEngine.prepare(); try playbackEngine.start() }
            if !playerNode.isPlaying { playerNode.play() }
        } catch { state = .error("扬声器启动失败") }
    }

    private func schedulePlayback(_ bytes: Data) {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8_000, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(bytes.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(bytes.count)
        for (i, byte) in bytes.enumerated() { channel[i] = Float(VeilMuLaw.decode(byte)) / Float(Int16.max) }
        preparePlaybackIfNeeded()
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
