import SwiftUI

struct AgentHomeView: View {
    @ObservedObject var coordinator: AgentCoordinator
    @ObservedObject var maleCNS: MaleCNSGraphManager
    @State private var showDiagnostics = false

    var body: some View {
        VStack(spacing: 12) {
            AgentStatusView(coordinator: coordinator, maleCNS: maleCNS)
            AgentChatView(coordinator: coordinator)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(VeilAmbientBackground())
        .navigationTitle("灵核")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink(destination: AgentVideoChatView(coordinator: coordinator)) {
                    Image(systemName: "video")
                }
                .accessibilityLabel("进入本地视频对话")

                Button {
                    coordinator.newSession()
                } label: {
                    Image(systemName: "plus.bubble")
                }
                .accessibilityLabel("新建本地会话")

                Menu {
                    Button("运行诊断") { showDiagnostics = true }
                    if coordinator.isGenerating {
                        Button("停止生成", role: .destructive) { coordinator.stopGeneration() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("灵核更多选项")
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            AgentDiagnosticsView(coordinator: coordinator)
        }
        .onAppear {
            coordinator.setComputeFocus(.languageChat)
            maleCNS.prepareFromBundle()
            coordinator.activate()
        }
        .onDisappear { coordinator.setComputeFocus(.idle) }
    }
}

private struct AgentDiagnosticsView: View {
    @ObservedObject var coordinator: AgentCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("只包含本地运行时状态与性能计数；不包含聊天正文、附件、密钥、配对六码或数据库路径。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    Text(coordinator.diagnosticsReport())
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(VeilTheme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
            }
            .background(VeilAmbientBackground())
            .navigationTitle("灵核诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
