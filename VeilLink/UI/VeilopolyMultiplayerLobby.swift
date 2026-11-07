import SwiftUI
import VeilopolyUI

/// Nearby multiplayer is separate from the existing offline entry. Invitations
/// never auto-accept and no money or move is committed by opening this panel.
@MainActor
struct VeilopolyMultiplayerLobby: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var bridge: VeilopolyMultiplayerBridge
    @Environment(\.scenePhase) private var scenePhase
    init(model: AppModel) {
        self.model = model
        _bridge = ObservedObject(wrappedValue: model.veilopolyMultiplayer)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("大富翁 · 加密联机", systemImage: "person.2.wave.2")
                .font(.headline)
            Text("两台手机 · 两名真人 + 两名 AI · 房主裁决 · 对手须支持同版功能")
                .font(.caption).foregroundColor(.secondary)
            Text(bridge.status).font(.caption).fixedSize(horizontal: false, vertical: true)
            if let error = bridge.lastError {
                Text(error).font(.caption).foregroundColor(.orange)
            }
            if bridge.incomingInvitation != nil {
                HStack {
                    lobbyButton("接受邀请", symbol: "checkmark") { bridge.acceptInvitation() }
                    lobbyButton("拒绝", symbol: "xmark") { bridge.declineInvitation() }
                }
            } else if bridge.outgoingInvitation != nil {
                ProgressView("等待对方接受")
                lobbyButton("取消邀请", symbol: "xmark.circle") { bridge.leaveRoom() }
            } else if bridge.gameModel != nil {
                lobbyButton("进入／继续联机对局", symbol: "gamecontroller") { bridge.isGamePresented = true }
                lobbyButton("重新同步", symbol: "arrow.triangle.2.circlepath") { bridge.gameModel?.requestNetworkSync() }
                lobbyButton("离开房间（保留本地对局记录）", symbol: "rectangle.portrait.and.arrow.right") { bridge.leaveRoom() }
            } else if model.conversations.isEmpty {
                Text("先在“附近”完成可信配对，再从这里邀请联系人。")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(Array(model.conversations.prefix(6))) { conversation in
                    lobbyButton("邀请 \(conversation.title)", symbol: "paperplane") { bridge.invite(conversation) }
                }
            }
        }
        .veilCard()
        .onAppear { bridge.restoreIfNeeded(); bridge.setForeground(scenePhase == .active) }
        .onChange(of: scenePhase) { bridge.setForeground($0 == .active) }
        .fullScreenCover(isPresented: $bridge.isGamePresented) {
            if let session = bridge.gameModel {
                VeilopolyMultiplayerGameView(session: session) { bridge.isGamePresented = false }
            }
        }
        .accessibilityIdentifier("game-lobby.veilopoly-multiplayer")
    }
    private func lobbyButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
    }
}
