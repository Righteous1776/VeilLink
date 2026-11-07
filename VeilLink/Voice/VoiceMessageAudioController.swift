import AVFoundation
import Combine
import Foundation

enum VeilAudioLaneRole: Sendable {
    case messageCapture, messagePlayback, pttCapture, pttPlayback
}

/// A serial lease for AVAudioSession, which is shared across the entire process.
/// This does not allocate any dedicated OS thread or a separate Bluetooth radio.
enum VeilAudioLeasePolicy {
    static func allows(currentOwner: UUID?, incomingOwner: UUID) -> Bool {
        currentOwner == nil || currentOwner == incomingOwner
    }
}

@MainActor
final class VeilAudioSessionArbiter {
    static let shared = VeilAudioSessionArbiter()
    private var ownerID: UUID?
    private init() {}

    func acquire(owner: UUID, role: VeilAudioLaneRole, bufferDuration: TimeInterval? = nil) throws {
        guard VeilAudioLeasePolicy.allows(currentOwner: ownerID, incomingOwner: owner) else {
            throw NSError(domain: "VeilAudioSession", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "音频正在由另一个功能使用，请结束当前录音或播放后再试。"
            ])
        }
        let session = AVAudioSession.sharedInstance()
        switch role {
        case .messageCapture:
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        case .pttCapture, .pttPlayback:
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        case .messagePlayback:
            // Let iOS select its active output route (speaker / A2DP headphones).
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
        }
        if let bufferDuration { try session.setPreferredIOBufferDuration(bufferDuration) }
        try session.setActive(true)
        ownerID = owner
    }

    func release(owner: UUID) {
        guard ownerID == owner else { return }
        ownerID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct VeilVoiceRecording: Sendable {
    let data: Data
    let durationSeconds: Double
    let mimeType: String
}

@MainActor
final class VeilVoiceMessageRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var level: Float = 0
    @Published private(set) var elapsedSeconds: Double = 0
    @Published private(set) var lastError: String?

    var onAutomaticFinish: ((VeilVoiceRecording) -> Void)?

    private var recorder: AVAudioRecorder?
    private let audioOwner = UUID()
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var currentURL: URL?
    private var maximumTimer: Timer?
    private let tuning = VeilRealtimeAudioTuning.resolved(performanceLabel: VeilDevicePerformance.current.label)

    func begin(_ completion: @escaping (Bool) -> Void) {
        guard !isRecording else { completion(true); return }
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(startRecording())
        case .denied:
            lastError = "麦克风权限已关闭。"
            completion(false)
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted { completion(self.startRecording()) }
                    else { self.lastError = "没有获得麦克风权限。"; completion(false) }
                }
            }
        @unknown default:
            lastError = "无法确认麦克风权限状态。"
            completion(false)
        }
    }

    func finish(cancelled: Bool = false) -> VeilVoiceRecording? {
        guard isRecording else { return nil }
        defer { VeilAudioSessionArbiter.shared.release(owner: audioOwner) }
        meterTimer?.invalidate(); meterTimer = nil
        maximumTimer?.invalidate(); maximumTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        level = 0
        let elapsed = min(VoiceMessageCodec.maximumDurationSeconds, max(0, elapsedSeconds))
        elapsedSeconds = 0
        startedAt = nil
        defer { currentURL = nil }

        guard let url = currentURL else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }
        guard !cancelled, elapsed >= 0.35,
              let data = try? Data(contentsOf: url),
              !data.isEmpty,
              data.count <= VoiceMessageCodec.maximumBytes else { return nil }
        return VeilVoiceRecording(data: data, durationSeconds: elapsed, mimeType: "audio/mp4")
    }

    func cancel() { _ = finish(cancelled: true) }

    private func startRecording() -> Bool {
        do {
            try VeilAudioSessionArbiter.shared.acquire(
                owner: audioOwner, role: .messageCapture,
                bufferDuration: tuning.preferredIOBufferDuration
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("VeilVoice-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 24_000,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record() else { throw NSError(domain: "VeilVoice", code: 1) }
            self.recorder = recorder
            currentURL = url
            startedAt = Date()
            elapsedSeconds = 0
            lastError = nil
            isRecording = true
            let meterTimer = Timer(timeInterval: tuning.meterPublishInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshMeter() }
            }
            meterTimer.tolerance = min(0.02, tuning.meterPublishInterval * 0.2)
            RunLoop.main.add(meterTimer, forMode: .common)
            self.meterTimer = meterTimer
            maximumTimer = Timer.scheduledTimer(withTimeInterval: VoiceMessageCodec.maximumDurationSeconds, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let recording = self.finish(cancelled: false) else { return }
                    self.onAutomaticFinish?(recording)
                }
            }
            return true
        } catch {
            VeilAudioSessionArbiter.shared.release(owner: audioOwner)
            lastError = "录音启动失败：\(error.localizedDescription)"
            isRecording = false
            return false
        }
    }

    private func refreshMeter() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        level = max(0, min(1, pow(10, db / 28)))
        if let startedAt { elapsedSeconds = min(Date().timeIntervalSince(startedAt), VoiceMessageCodec.maximumDurationSeconds) }
    }
}

@MainActor
private final class VeilVoicePlaybackArbiter {
    static let shared = VeilVoicePlaybackArbiter()
    weak var active: VeilVoicePlaybackController?

    func claim(_ controller: VeilVoicePlaybackController) {
        if active !== controller { active?.stopFromArbiter() }
        active = controller
    }

    func release(_ controller: VeilVoicePlaybackController) {
        if active === controller { active = nil }
    }
}

@MainActor
final class VeilVoicePlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    private var player: AVAudioPlayer?
    private let audioOwner = UUID()
    private var timer: Timer?
    private let tuning = VeilRealtimeAudioTuning.resolved(performanceLabel: VeilDevicePerformance.current.label)

    func toggle(data: Data) {
        if isPlaying { stop(); return }
        do {
            VeilVoicePlaybackArbiter.shared.claim(self)
            try VeilAudioSessionArbiter.shared.acquire(
                owner: audioOwner, role: .messagePlayback
            )
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            isPlaying = player.play()
            guard isPlaying else { stop(); return }
            timer?.invalidate()
            let timer = Timer(timeInterval: tuning.playbackProgressInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            timer.tolerance = min(0.025, tuning.playbackProgressInterval * 0.25)
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop(); player = nil
        timer?.invalidate(); timer = nil
        isPlaying = false; progress = 0
        VeilVoicePlaybackArbiter.shared.release(self)
        VeilAudioSessionArbiter.shared.release(owner: audioOwner)
    }

    fileprivate func stopFromArbiter() {
        player?.stop(); player = nil
        timer?.invalidate(); timer = nil
        isPlaying = false; progress = 0
        VeilAudioSessionArbiter.shared.release(owner: audioOwner)
    }

    // Match the nonisolated AVAudioPlayerDelegate witness without passing the player across actors.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self,
                  let active = self.player,
                  ObjectIdentifier(active) == finishedID else { return }
            self.stop()
        }
    }

    private func refresh() {
        guard let player, player.duration > 0 else { stop(); return }
        progress = min(1, max(0, player.currentTime / player.duration))
    }
}
