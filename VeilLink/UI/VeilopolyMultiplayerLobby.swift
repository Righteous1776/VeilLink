import SwiftUI
import VeilopolyUI

/// Nearby multiplayer is separate from the existing offline entry. Invitations
/// never auto-accept and no money or move is committed by opening this panel.
@MainActor
struct VeilopolyMultiplayerLobby: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var bridge: VeilopolyMultiplayerBridge
    @Environment(\.scenePhase) private var scenePhase
    private let conversation: ConversationSummary?
    private var presentationID: String { conversation.map { "hub-" + $0.id } ?? "game-lobby" }
    init(model: AppModel, conversation: ConversationSummary? = nil) {
        self.model = model
        self.conversation = conversation
        _bridge = ObservedObject(wrappedValue: model.veilopolyMultiplayer)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("大富翁 · 加密联机", systemImage: "person.2.wave.2")
                .font(.headline)
            Text("两台手机 · 两名真人 + 两名 AI · 房主裁决 · 对手须支持同版功能")
                .font(.caption).foregroundColor(.secondary)
            Text("新局与单机共用城市经济 V5；聊天区可直接邀请、接受与进入。旧局按原规则续玩。")
                .font(.caption2).foregroundColor(.secondary)
            Text(bridge.status).font(.caption).fixedSize(horizontal: false, vertical: true)
            if bridge.activePeerIdentityID != nil && bridge.activeRulesTitle == "经典旧局" {
                Text("这是保留的经典旧局，不会自动改价。若要体验 V5，请先离开房间、保留旧存档，再重新邀请。")
                    .font(.caption).foregroundColor(.secondary)
            }
            if let error = bridge.lastError {
                Text(error).font(.caption).foregroundColor(.orange)
            }
            if let conversation, let peer = bridge.activePeerIdentityID,
               peer != conversation.peerIdentityID {
                Text("已有与其他联系人的房间或邀请，请到独立游戏大厅处理；不会邀请错当前聊天对象。")
                    .font(.caption).foregroundColor(.secondary)
            } else if bridge.incomingInvitation != nil {
                HStack {
                    lobbyButton("接受邀请 · \(bridge.activeRulesTitle)", symbol: "checkmark") {
                        bridge.acceptInvitation(presentationContext: presentationID)
                    }
                    lobbyButton("拒绝", symbol: "xmark") { bridge.declineInvitation() }
                }
            } else if bridge.outgoingInvitation != nil {
                ProgressView("等待对方接受")
                lobbyButton("取消邀请", symbol: "xmark.circle") { bridge.leaveRoom() }
            } else if bridge.gameModel != nil {
                lobbyButton("继续联机 · \(bridge.activeRulesTitle)", symbol: "gamecontroller") {
                    bridge.presentGame(context: presentationID)
                }
                lobbyButton("重连并同步", symbol: "arrow.triangle.2.circlepath") { bridge.reconnectAndSync() }
                lobbyButton("离开房间（保留本地对局记录）", symbol: "rectangle.portrait.and.arrow.right") { bridge.leaveRoom() }
            } else if let conversation {
                lobbyButton("邀请 \(conversation.title) · 城市经济 V5", symbol: "paperplane") {
                    bridge.invite(conversation, presentationContext: presentationID)
                }
                .accessibilityIdentifier("veilopoly.chat.invite")
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
        .modifier(VeilopolyRoomPresentation(bridge: bridge, context: presentationID))
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

/// Exactly one route may present the shared room. In particular the hidden
/// Games tab cannot race a chat sheet for the same full-screen presentation.
@MainActor
struct VeilopolyRoomPresentation: ViewModifier {
    @ObservedObject var bridge: VeilopolyMultiplayerBridge
    let context: String
    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: Binding(
            get: { bridge.isGamePresented && bridge.presentationContext == context },
            set: { if !$0 && bridge.presentationContext == context { bridge.isGamePresented = false } }
        )) {
            if let session = bridge.gameModel {
                VeilopolyMultiplayerGameView(session: session) { bridge.isGamePresented = false }
            }
        }
    }
}

/// Transient room status, deliberately outside the message ScrollView: it
/// cannot steal the latest-message anchor or pretend to be persisted chat.
@MainActor
struct VeilopolyConversationInvitationView: View {
    @ObservedObject var bridge: VeilopolyMultiplayerBridge
    let peerIdentityID: String
    let presentationID: String
    var body: some View {
        Group {
            if bridge.activePeerIdentityID == peerIdentityID ||
                (bridge.lastActionPeer == peerIdentityID && bridge.lastError != nil) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("大富翁 · \(bridge.activeRulesTitle)", systemImage: "building.2")
                        .font(.caption.weight(.semibold))
                    Text((bridge.lastActionPeer == peerIdentityID ? bridge.lastError : nil) ?? bridge.status)
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                    if bridge.activePeerIdentityID == peerIdentityID {
                        HStack {
                            if bridge.incomingInvitation != nil {
                                Button("接受邀请") { bridge.acceptInvitation(presentationContext: presentationID) }
                                    .accessibilityIdentifier("veilopoly.chat.accept")
                                Button("拒绝") { bridge.declineInvitation() }
                            } else if bridge.gameModel != nil {
                                Button("进入／继续") { bridge.presentGame(context: presentationID) }
                                    .accessibilityIdentifier("veilopoly.chat.resume")
                            } else if bridge.outgoingInvitation != nil {
                                Button("取消邀请") { bridge.leaveRoom() }
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VeilTheme.gold.opacity(0.08))
                .accessibilityIdentifier("veilopoly.chat.room-status")
            }
        }
    }
}
