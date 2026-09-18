import SwiftUI

struct AgentChatView: View {
    @ObservedObject var coordinator: AgentCoordinator
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            transcript
            if let error = coordinator.lastError, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(VeilTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            composer
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(coordinator.session.messages) { message in
                        AgentMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: coordinator.session.messages.count) { _ in
                if let id = coordinator.session.messages.last?.id {
                    withAnimation(VeilRenderProfile.allowsPersistentAnimations ? VeilMotion.reveal : nil) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("仅在本机输入…", text: $draft)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundColor(VeilTheme.text)
                .padding(.horizontal, 12)
                .frame(minHeight: 42)
                .background(VeilTheme.elevated.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .disabled(coordinator.isGenerating)

            if coordinator.isGenerating {
                Button {
                    coordinator.stopGeneration()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 42, height: 42)
                        .foregroundColor(VeilTheme.danger)
                        .background(VeilTheme.danger.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(VeilPressStyle())
                .accessibilityLabel("停止本地生成")
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 42, height: 42)
                        .foregroundColor(Color.black.opacity(0.88))
                        .background(VeilTheme.goldBright)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(VeilPressStyle())
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.38 : 1)
                .accessibilityLabel("发送给本地智能体")
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        coordinator.send(text)
    }
}

private struct AgentMessageBubble: View {
    let message: AgentMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 42) }
            Text(message.text.isEmpty ? "…" : message.text)
                .font(.system(size: 14.5, weight: .regular, design: .rounded))
                .foregroundColor(message.role == .user ? Color.black.opacity(0.88) : VeilTheme.text)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                    ? AnyShapeStyle(VeilTheme.goldBright)
                    : AnyShapeStyle(VeilTheme.incomingBubbleGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(message.role == .user ? Color.clear : VeilTheme.hairline, lineWidth: 1)
                )
            if message.role == .assistant { Spacer(minLength: 42) }
        }
        .frame(maxWidth: .infinity)
    }
}
