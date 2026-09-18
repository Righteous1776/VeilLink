import SwiftUI

struct AgentVideoChatView: View {
    @ObservedObject var coordinator: AgentCoordinator
    @StateObject private var camera: AgentCameraController
    @StateObject private var voice = AgentVoiceController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var voiceDraft = ""
    @State private var autoSpeakReplies = true
    @State private var lastSpokenAssistantID: String?

    init(coordinator: AgentCoordinator) {
        self.coordinator = coordinator
        _camera = StateObject(wrappedValue: AgentCameraController(profile: coordinator.capabilityProfile))
    }

    var body: some View {
        VStack(spacing: 10) {
            cameraPanel
            visualSummary
            AgentChatView(coordinator: coordinator)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .background(VeilAmbientBackground())
        .navigationTitle("灵核 · 视频")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        if voice.isListening {
                            voice.stopListening()
                            let text = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty { coordinator.send(text) }
                        } else {
                            await voice.startListening()
                        }
                    }
                } label: {
                    Image(systemName: voice.isListening ? "mic.fill" : "mic")
                }
                .accessibilityLabel(voice.isListening ? "停止本地语音输入" : "开始本地语音输入")

                Button {
                    autoSpeakReplies.toggle()
                    if !autoSpeakReplies { voice.stopSpeaking() }
                } label: {
                    Image(systemName: autoSpeakReplies ? "speaker.wave.2.fill" : "speaker.slash")
                }
                .accessibilityLabel(autoSpeakReplies ? "关闭自动朗读" : "开启自动朗读")
            }
        }
        .onAppear {
            coordinator.setComputeFocus(.videoChat)
            camera.applyComputeBudget(coordinator.computePlan.vision)
            lastSpokenAssistantID = coordinator.session.messages.last(where: { $0.role == .assistant })?.id
            camera.start()
        }
        .onDisappear {
            camera.stop()
            voice.stopListening()
            voice.stopSpeaking()
            coordinator.clearVisualContext()
            coordinator.setComputeFocus(.languageChat)
        }
        .onReceive(camera.$latestContext) { context in
            coordinator.updateVisualContext(context)
        }
        .onChange(of: coordinator.computePlan) { plan in
            camera.applyComputeBudget(plan.vision)
        }
        .onReceive(voice.$transcript) { value in
            voiceDraft = value
        }
        .onReceive(voice.$finalizedTranscript) { finalized in
            guard let finalized else { return }
            let text = finalized.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            coordinator.send(text)
            voice.consumeFinalizedTranscript()
        }
        .onChange(of: coordinator.runtimeState) { state in
            guard state == .ready, autoSpeakReplies,
                  let last = coordinator.session.messages.last(where: { $0.role == .assistant }),
                  !last.text.isEmpty, last.id != lastSpokenAssistantID else { return }
            lastSpokenAssistantID = last.id
            voice.speak(last.text)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                camera.start()
            } else {
                camera.stop()
                voice.stopListening()
                voice.stopSpeaking()
                coordinator.clearVisualContext()
            }
        }
    }

    private var cameraPanel: some View {
        ZStack(alignment: .bottomLeading) {
            AgentCameraPreview(controller: camera)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(VeilTheme.hairline, lineWidth: 1)
                )

            HStack(spacing: 6) {
                Circle()
                    .fill(camera.isRunning ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(camera.statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                if voice.isListening {
                    Text("· 本地听写")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
            .padding(9)
        }
    }

    @ViewBuilder
    private var visualSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let context = camera.latestContext {
                Text(context.compactPromptDescription)
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(3)
            } else {
                Text("摄像头帧只在本机做低频分析；原始视频不会进入 BLE，也不会上传。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
            }
            if voice.isListening || !voiceDraft.isEmpty {
                Text(voiceDraft.isEmpty ? "正在听…" : voiceDraft)
                    .font(.caption.monospaced())
                    .foregroundColor(VeilTheme.text)
                    .lineLimit(2)
            } else if voice.statusText != "语音待命" {
                Text(voice.statusText)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.gold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(VeilTheme.panel.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import UIKit

private struct AgentCameraPreview: UIViewRepresentable {
    let controller: AgentCameraController

    func makeUIView(context: Context) -> AgentPreviewUIView {
        let view = AgentPreviewUIView()
        view.previewLayer.session = controller.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: AgentPreviewUIView, context: Context) {
        uiView.previewLayer.session = controller.session
    }
}

private final class AgentPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
#else
private struct AgentCameraPreview: View {
    let controller: AgentCameraController
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black.opacity(0.6))
            .overlay(Text("当前平台无摄像头预览").font(.caption).foregroundColor(.white))
    }
}
#endif
