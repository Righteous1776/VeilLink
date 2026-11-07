import SwiftUI

#if VERTEX_CHAT_ONLY && canImport(llama)
/// Independent, text-only sandbox. No AppModel, tool router or BLE/DB references.
@MainActor
private final class VertexTinyChatState: ObservableObject {
    @Published var messages: [AgentMessage] = []
    @Published var partial = ""
    @Published var errorText: String?
    @Published var isGenerating = false

    private var boundary: LingCoreChatOnlyBoundary?
    private var task: Task<Void, Never>?
    private var activeID: UUID?

    func send(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 512, !isGenerating else { return }
        let id = UUID()
        activeID = id
        messages.append(AgentMessage(role: .user, text: text))
        isGenerating = true
        partial = ""
        errorText = nil

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let endpoint = try self.endpoint()
                let answer = try await endpoint.reply(to: text) { [weak self] token in
                    guard let self, self.activeID == id else { return }
                    self.partial += token
                }
                guard self.activeID == id else { return }
                self.messages.append(AgentMessage(role: .assistant, text: answer))
            } catch is CancellationError {
                // Cancellation produces no synthetic assistant reply.
            } catch {
                guard self.activeID == id else { return }
                self.errorText = error.localizedDescription
            }
            guard self.activeID == id else { return }
            self.isGenerating = false
            self.partial = ""
            self.task = nil
            self.activeID = nil
        }
    }

    func stop() {
        activeID = nil
        task?.cancel()
        boundary?.cancel()
        task = nil
        isGenerating = false
        partial = ""
    }

    func clear() {
        stop()
        boundary?.clear()
        messages.removeAll()
        errorText = nil
    }

    private func endpoint() throws -> LingCoreChatOnlyBoundary {
        if let boundary { return boundary }
        let filename = "Vertex-0.6-35M-Instruct-Q4_K_M"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "gguf", subdirectory: "LocalAI")
            ?? Bundle.main.url(forResource: filename, withExtension: "gguf") else {
            throw AgentRuntimeError.unavailable("实验模型未包含在当前应用中，请使用 Vertex 原生实验构建。")
        }
        let item = LingCoreChatOnlyBoundary(runtime: Vertex35MChatRuntime(importedModelURL: url))
        boundary = item
        return item
    }
}

struct LingCoreTinyChatView: View {
    @StateObject private var chat = VertexTinyChatState()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield").foregroundColor(VeilTheme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Vertex 35M · 离线聊天").font(.headline)
                    Text("独立文本通道 · 零工具/控制权限")
                        .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
            }
            .padding(12)
            .background(VeilTheme.panel.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chat.messages) { message in
                            HStack {
                                if message.role == .user { Spacer(minLength: 40) }
                                Text(message.text.isEmpty ? "…" : message.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(message.role == .user ? .black : VeilTheme.text)
                                    .padding(12)
                                    .background(message.role == .user ? VeilTheme.goldBright : VeilTheme.elevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                                if message.role == .assistant { Spacer(minLength: 40) }
                            }
                            .id(message.id)
                        }
                        if chat.isGenerating {
                            Text(chat.partial.isEmpty ? "正在本机生成…" : chat.partial)
                                .font(.system(size: 14))
                                .foregroundColor(VeilTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: chat.messages.count) { _ in
                    if let id = chat.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }

            if let error = chat.errorText {
                Text(error).font(.caption).foregroundColor(VeilTheme.danger)
            }

            HStack(spacing: 8) {
                TextField("输入文本，不超过 512 字", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .disabled(chat.isGenerating)
                if chat.isGenerating {
                    Button("停止") { chat.stop() }.buttonStyle(.bordered)
                } else {
                    Button("发送", action: send)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 512)
                }
            }
            Text("实验模型可能答错、重复或无法理解中文；其输出永远不会作为设备或游戏命令。")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .padding(12)
        .background(VeilAmbientBackground())
        .navigationTitle("微型离线聊天")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空") { chat.clear() }.disabled(chat.messages.isEmpty)
            }
        }
        .onDisappear { chat.stop() }
    }

    private func send() {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= 512, !chat.isGenerating else { return }
        draft = ""
        chat.send(input)
    }
}
#endif
