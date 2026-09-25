import SwiftUI

enum VeilChatComposerMode { case text, voice }

struct VeilHoldToTalkComposer: View {
    @ObservedObject var recorder: VeilVoiceMessageRecorder
    let onRecorded: (VeilVoiceRecording) -> Void
    @State private var pressed = false
    @State private var cancelling = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: cancelling ? "xmark" : (recorder.isRecording ? "waveform" : "mic.fill"))
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
            if recorder.isRecording {
                Text(String(format: "%.1fs", recorder.elapsedSeconds))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .foregroundColor(cancelling ? VeilTheme.danger : VeilTheme.text)
        .padding(.horizontal, 15)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(VeilAppearanceController.shared.isInstrument
                      ? LinearGradient(colors: [VeilAppearanceController.shared.palette.keycapTop, VeilAppearanceController.shared.palette.keycapBottom], startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [VeilTheme.panelSoft, VeilTheme.panel], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(cancelling ? VeilTheme.danger.opacity(0.55) : VeilTheme.hairline, lineWidth: 1))
        .offset(y: pressed ? 2 : 0)
        .shadow(color: Color.black.opacity(pressed ? 0.10 : 0.30), radius: pressed ? 2 : 5, x: 0, y: pressed ? 1 : 4)
        .contentShape(RoundedRectangle(cornerRadius: 13))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    cancelling = value.translation.height < -72
                    guard !pressed else { return }
                    pressed = true
                    recorder.begin { _ in }
                }
                .onEnded { value in
                    let shouldCancel = value.translation.height < -72
                    pressed = false
                    cancelling = false
                    if let recording = recorder.finish(cancelled: shouldCancel) { onRecorded(recording) }
                }
        )
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.78), value: pressed)
        .accessibilityLabel(recorder.isRecording ? "松开发送语音" : "按住说话")
    }

    private var label: String {
        if cancelling { return "松开取消" }
        if recorder.isRecording { return "松开发送 · 上滑取消" }
        return "按住说话"
    }
}

struct VeilVoiceMessageBubble: View {
    let message: ChatMessage
    let attachment: ChatAttachment
    let database: DatabaseStore
    @StateObject private var player = VeilVoicePlaybackController()

    private var metadata: VeilVoiceMessageMetadata? { VoiceMessageCodec.decode(message.body) }

    var body: some View {
        Button {
            guard let data = database.loadAttachment(id: attachment.id) else { return }
            player.toggle(data: data)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                HStack(alignment: .center, spacing: 2.4) {
                    ForEach(0..<9, id: \.self) { index in
                        Capsule()
                            .fill(message.isOutgoing ? Color.black.opacity(0.70) : VeilTheme.gold)
                            .frame(width: 2.2, height: barHeight(index))
                    }
                }
                .frame(width: 50, height: 22)
                Text(metadata?.compactDuration ?? "语音")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 14)
            .frame(minWidth: 118, minHeight: 44)
            .background(MessageVoiceSurface(outgoing: message.isOutgoing))
            .foregroundColor(message.isOutgoing ? Color.black.opacity(0.88) : VeilTheme.text)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(message.isOutgoing ? Color.white.opacity(0.12) : VeilTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomLeading) {
            GeometryReader { proxy in
                Capsule()
                    .fill(message.isOutgoing ? Color.black.opacity(0.30) : VeilTheme.gold.opacity(0.55))
                    .frame(width: proxy.size.width * player.progress, height: 2)
                    .offset(y: proxy.size.height - 2)
            }
            .allowsHitTesting(false)
        }
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [7, 13, 18, 10, 20, 14, 8, 17, 11]
        return pattern[index % pattern.count]
    }
}

private struct MessageVoiceSurface: View {
    let outgoing: Bool
    var body: some View {
        Group {
            if outgoing { VeilTheme.goldGradient }
            else { VeilTheme.incomingBubbleGradient }
        }
    }
}
