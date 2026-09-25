import AVFoundation
import Combine
import Foundation

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

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var currentURL: URL?
    private var maximumTimer: Timer?

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
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
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
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshMeter() }
            }
            maximumTimer = Timer.scheduledTimer(withTimeInterval: VoiceMessageCodec.maximumDurationSeconds, repeats: false) { [weak self] _ in
                Task { @MainActor in _ = self?.finish(cancelled: false) }
            }
            return true
        } catch {
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
final class VeilVoicePlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func toggle(data: Data) {
        if isPlaying { stop(); return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            isPlaying = player.play()
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop(); player = nil
        timer?.invalidate(); timer = nil
        isPlaying = false; progress = 0
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { stop() }

    private func refresh() {
        guard let player, player.duration > 0 else { stop(); return }
        progress = min(1, max(0, player.currentTime / player.duration))
    }
}
