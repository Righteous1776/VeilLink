import Foundation
import Combine

#if canImport(Speech) && canImport(AVFoundation)
@preconcurrency import Speech
@preconcurrency import AVFoundation

@MainActor
final class AgentVoiceController: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var statusText = "语音待命"
    @Published private(set) var finalizedTranscript: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let synthesizer = AVSpeechSynthesizer()

    func startListening() async {
        guard !isListening else { return }
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard authorization == .authorized else {
            statusText = "没有语音识别权限"
            return
        }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            statusText = "本机没有可用的离线中文语音识别"
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            recognitionRequest = request
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            transcript = ""
            finalizedTranscript = nil
            isListening = true
            statusText = "本地听写中"
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                let hasError = error != nil
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if isFinal, let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.finalizedTranscript = text
                    }
                    if hasError || isFinal { self.stopListening() }
                }
            }
        } catch {
            statusText = "无法启动本地语音：\(error.localizedDescription)"
            stopListening()
        }
    }

    func stopListening() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if statusText == "本地听写中" { statusText = "语音待命" }
    }

    func consumeFinalizedTranscript() { finalizedTranscript = nil }

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.47
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
#else
@MainActor
final class AgentVoiceController: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var statusText = "当前平台没有语音运行时"
    @Published private(set) var finalizedTranscript: String?
    func startListening() async {}
    func stopListening() {}
    func consumeFinalizedTranscript() { finalizedTranscript = nil }

    func speak(_ text: String) {}
    func stopSpeaking() {}
}
#endif
