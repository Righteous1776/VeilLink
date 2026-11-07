import Foundation
import SwiftUI
import Combine
import VeilopolyEngine
import VeilopolyNet
import VeilopolyUI

/// All packets below are read from the host app's decrypted, persisted and
/// identity-bound chat history. The host SessionCoordinator provides E2EE,
/// delivery ACK, retry and peer authentication. This file never opens raw BLE.
private struct VeilopolyFriendRoom: Identifiable {
 let invite: GameInvite
 let hostIsLocal: Bool
 let createdAt: Date
 var accepted = false
 var declined = false
 var id: String { invite.gameId }
}

private struct VeilopolyOpenFriendGame: Identifiable {
 let id: String
 let isHost: Bool
 let model: GameSessionModel
}

@MainActor
private final class VeilopolyFriendRoomController: ObservableObject {
 @Published private(set) var rooms: [VeilopolyFriendRoom] = []
 @Published var activeGame: VeilopolyOpenFriendGame?
 @Published var statusMessage: String?

 let model: AppModel
 let conversation: ConversationSummary
 private var processedIDs = Set<String>()
 private var processedSyncHints = Set<String>()
 private var processedRejections = Set<String>()
 private var lastGuestIntentSeq: Int?
 private var pendingHostHeadSeq: Int?
 private var lastResyncAt = Date.distantPast

 init(model: AppModel, conversation: ConversationSummary) {
  self.model = model
  self.conversation = conversation
 }

 var secureReady: Bool {
  model.sessions.hasSecureSession(for: conversation.peerIdentityID)
 }

 func recoverLink() {
  if !model.ensureRealtimeGameLink(for: conversation.peerIdentityID) {
   statusMessage = "已请求恢复安全连接。请先确认两台设备已连接，再重试邀请。"
  } else {
   statusMessage = "端到端加密链路已就绪。"
  }
 }

 private func outbound(_ event: GameEnvelope) -> Bool {
  guard model.ensureRealtimeGameLink(for: conversation.peerIdentityID) else {
   statusMessage = "好友安全链路尚未就绪。请连接成功后再提交。"
   return false
  }
  do {
   try model.sessions.sendVeilopolyEnvelope(event, to: conversation.peerIdentityID)
   statusMessage = nil
   return true
  } catch {
   statusMessage = error.localizedDescription
   return false
  }
 }

 func invite() {
  guard secureReady else { recoverLink(); return }
  let id = UUID().uuidString
  let seed = VeilopolyNewGameSeed.fresh()
  let invitation = GameInvite(gameId: id, seed: seed, humanSeats: [0, 1])
  guard outbound(GameEnvelope(gameId: id, kind: .invite, invite: invitation)) else { return }
  refresh()
 }

 func accept(_ room: VeilopolyFriendRoom) {
  guard !room.hostIsLocal, !room.accepted, !room.declined else { return }
  if outbound(GameEnvelope(gameId: room.id, kind: .accept)) {
   refresh()
  }
 }

 func decline(_ room: VeilopolyFriendRoom) {
  guard !room.hostIsLocal, !room.accepted, !room.declined else { return }
  if outbound(GameEnvelope(gameId: room.id, kind: .decline)) {
   refresh()
  }
 }

 func closeGame() {
  activeGame?.model.flushSave()
  activeGame = nil
  lastGuestIntentSeq = nil
  pendingHostHeadSeq = nil
 }

 func open(_ room: VeilopolyFriendRoom) {
  guard room.accepted, !room.declined else {
   statusMessage = "请先让受邀好友接受邀请。"
   return
  }
  guard secureReady else { recoverLink(); return }
  if activeGame?.id == room.id { return }

  let session = GameSessionModel(
   seed: room.invite.seed, humanCount: 2, roomID: room.id,
   localSeat: room.hostIsLocal ? 0 : 1, isHost: room.hostIsLocal)
  session.onGuestPresentationReady = { [weak self] in
   self?.continueResyncIfNeeded()
  }
  session.onAuthoritativeMove = { [weak self, weak session] committed in
   guard let self else { return }
   let packet = GameEnvelope(gameId: room.id, kind: .move, move: committed)
   if !self.outbound(packet) {
    session?.reportPeerError("本地操作已保存，但尚未发送到好友。恢复连接后请手动同步。")
   }
  }
  session.onGuestIntentRejected = { [weak self] proposal, reason in
   guard let self else { return }
   let packet = GameEnvelope(gameId: room.id, kind: .rejected,
                             rejectedSeq: proposal.seq, rejectionReason: reason)
   _ = self.outbound(packet)
  }
  session.onGuestIntent = { [weak self, weak session] intent in
   guard let self else { return }
   guard self.lastGuestIntentSeq != intent.seq else {
    session?.reportPeerError("已发送本回合指令，请等待房主确认")
    return
   }
   if self.outbound(GameEnvelope(gameId: room.id, kind: .intent, intent: intent)) {
    self.lastGuestIntentSeq = intent.seq
   } else {
    session?.reportPeerError("本次操作未发送；请先恢复连接。")
   }
  }
  activeGame = VeilopolyOpenFriendGame(id: room.id,
                                        isHost: room.hostIsLocal, model: session)
  processedIDs = []
  processedSyncHints = []
  processedRejections = []
  pendingHostHeadSeq = nil
  refresh()
  if !room.hostIsLocal { requestResync() }
 }

 private func trustedEvents() -> [(ChatMessage, GameEnvelope)] {
  model.database.fetchMessages(conversationID: conversation.id).compactMap { message in
   guard message.isOutgoing || message.senderIdentityID == conversation.peerIdentityID,
         message.deliveryState != .failed, message.deliveryState != .cancelled,
         let payload = VeilopolyRoomWire.decode(message.body)
   else { return nil }
   return (message, payload)
  }
 }

 func refresh() {
  let records = trustedEvents()
  var map: [String: VeilopolyFriendRoom] = [:]
  for (message, packet) in records where packet.kind == .invite {
   guard let invite = packet.invite else { continue }
   if map[packet.gameId] == nil {
    map[packet.gameId] = VeilopolyFriendRoom(
     invite: invite, hostIsLocal: message.isOutgoing, createdAt: message.sentAt)
   }
  }
  for (message, packet) in records {
   guard var room = map[packet.gameId],
         VeilopolyRoomAuthorization.allows(packet.kind,
           hostIsLocal: room.hostIsLocal,
           messageIsOutgoing: message.isOutgoing) else { continue }
   // The invited authenticated peer alone can accept or decline.
   if packet.kind == .accept { room.accepted = true }
   if packet.kind == .decline { room.declined = true }
   map[packet.gameId] = room
  }
  rooms = map.values.sorted { $0.createdAt > $1.createdAt }

  guard let active = activeGame,
        let room = rooms.first(where: { $0.id == active.id }),
        room.accepted, !room.declined else { return }

  // Replaying cached ciphertext is safe: only the authenticated sender's
  // direction is authorized and move sequence+post-state hashes are checked.
  if active.isHost {
   for (message, packet) in records where packet.gameId == active.id &&
                                      !message.isOutgoing {
    guard !processedIDs.contains(message.id),
          VeilopolyRoomAuthorization.allows(packet.kind,
            hostIsLocal: true, messageIsOutgoing: message.isOutgoing)
    else { continue }
    switch packet.kind {
    case .intent:
     guard let move = packet.intent else { continue }
     processedIDs.insert(message.id)
     active.model.acceptGuestIntent(move)
    case .resync:
     guard let query = packet.resync else { continue }
     processedIDs.insert(message.id)
     sendMissing(afterSeq: query.afterSeq, roomID: active.id, game: active.model.game)
    default: break
    }
   }
  } else {
   let commits = records.compactMap { message, packet -> AuthoritativeMove? in
    guard packet.gameId == active.id,
          VeilopolyRoomAuthorization.allows(packet.kind,
            hostIsLocal: false, messageIsOutgoing: message.isOutgoing),
          packet.kind == .move else { return nil }
    return packet.move
   }.sorted { $0.seq < $1.seq }
   for committed in commits {
    if committed.seq < active.model.game.nextSeq { continue }
    if committed.seq != active.model.game.nextSeq ||
       !active.model.acceptHostMove(committed) {
     active.model.reportPeerError("收到的棋局更新不连续或校验失败，请重新同步。")
     requestResync()
     break
    }
    lastGuestIntentSeq = nil
   }
   // Invalid proposals are explicitly rejected so guest input can be edited.
   for (message, packet) in records where packet.gameId == active.id &&
                                        !message.isOutgoing && packet.kind == .rejected {
    guard !processedRejections.contains(message.id),
          VeilopolyRoomAuthorization.allows(packet.kind,
            hostIsLocal: false, messageIsOutgoing: message.isOutgoing) else { continue }
    processedRejections.insert(message.id)
    if packet.rejectedSeq == active.model.game.nextSeq {
     lastGuestIntentSeq = nil
     active.model.reportPeerError(packet.rejectionReason ?? "操作未通过房主校验")
    }
   }
   // The authoritative host may have sent more than one bounded replay
   // batch. A new host-head hint requests the next part exactly once.
   for (message, packet) in records where packet.gameId == active.id &&
                                        !message.isOutgoing && packet.kind == .syncHint {
    guard !processedSyncHints.contains(message.id) else { continue }
    processedSyncHints.insert(message.id)
    if let lastHostSeq = packet.hostHeadSeq,
       active.model.game.nextSeq - 1 < lastHostSeq {
     pendingHostHeadSeq = max(pendingHostHeadSeq ?? -1, lastHostSeq)
     continueResyncIfNeeded()
    }
   }
  }
 }

 private func sendMissing(afterSeq: Int, roomID: String, game: GameState) {
  guard game.nextSeq > afterSeq + 1 else { return }
  var host = AuthoritativeHost(game: GameFactory.make(seed: game.seed, humanCount: 2))
  var dispatched = 0
  for move in game.moveLog {
   guard case .success(let verified) = host.accept(move) else {
    statusMessage = "历史记录无法重放，已停止发送恢复包。"
    return
   }
   guard verified.seq > afterSeq else { continue }
   if !outbound(GameEnvelope(gameId: roomID, kind: .move, move: verified)) {
    return
   }
   dispatched += 1
   if dispatched >= 48 {
    // Tell the guest whether more packets remain; it automatically requests
    // another bounded batch after verifying the current one.
    if verified.seq < game.nextSeq - 1 {
     _ = outbound(GameEnvelope(gameId: roomID, kind: .syncHint,
                               hostHeadSeq: game.nextSeq - 1))
    }
    statusMessage = "已补发一批历史回合，剩余回合由好友自动接续同步。"
    return
   }
  }
 }

 private func continueResyncIfNeeded() {
  guard let active = activeGame, !active.isHost,
        let head = pendingHostHeadSeq else { return }
  if active.model.game.nextSeq - 1 >= head {
   pendingHostHeadSeq = nil
   return
  }
  // Do not ask the host to resend messages still buffered in local replay.
  guard !active.model.hasPendingHostPlayback else { return }
  pendingHostHeadSeq = nil
  lastResyncAt = .distantPast
  requestResync()
 }

 func requestResync() {
  guard let active = activeGame, !active.isHost,
        Date().timeIntervalSince(lastResyncAt) > 3 else { return }
  let game = active.model.game
  let packet = MultiplayerResumeHandshake.request(gameID: active.id, guest: game)
  if outbound(packet) { lastResyncAt = Date() }
 }
}

@MainActor
struct VeilopolyFriendRoomView: View {
 @ObservedObject var model: AppModel
 @ObservedObject private var sessions: SessionCoordinator
 let conversation: ConversationSummary
 @StateObject private var room: VeilopolyFriendRoomController
 @Environment(\.dismiss) private var dismiss

 init(model: AppModel, conversation: ConversationSummary) {
  self.model = model
  self.conversation = conversation
  _sessions = ObservedObject(wrappedValue: model.sessions)
  _room = StateObject(wrappedValue: VeilopolyFriendRoomController(
   model: model, conversation: conversation))
 }

 var body: some View {
  NavigationView {
   ScrollView {
    VStack(alignment: .leading, spacing: 16) {
     Label("和 \(conversation.title) 玩大富翁",
           systemImage: "person.2.fill")
      .font(.system(size: 22, weight: .bold, design: .rounded))
     Text("先建立 VeilLink 安全连接，邀请好友接受后开启双人对局。双方各一席，其他两席由电脑参与。")
      .font(.subheadline)
      .fixedSize(horizontal: false, vertical: true)
     HStack(spacing: 8) {
      Image(systemName: room.secureReady ? "lock.shield.fill" : "bolt.slash")
       .foregroundColor(room.secureReady ? .green : .orange)
      Text(room.secureReady ? "好友加密连接已建立" : "安全链路未就绪")
       .font(.subheadline.weight(.semibold))
      Spacer(minLength: 2)
      if !room.secureReady {
       Button("重连") { room.recoverLink() }
        .buttonStyle(.bordered)
      }
     }
     .padding(12)
     .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

     Button {
      room.invite()
     } label: {
      Label("邀请 \(conversation.title) 加入新棋局", systemImage: "paperplane.fill")
       .frame(maxWidth: .infinity, minHeight: 52)
       .contentShape(Rectangle())
     }
     .buttonStyle(.borderedProminent)
     .disabled(!room.secureReady)
     .accessibilityIdentifier("veilopoly.invite-friend")

     if let message = room.statusMessage {
      Text(message)
       .font(.subheadline)
       .foregroundColor(.orange)
       .fixedSize(horizontal: false, vertical: true)
     }
     if room.rooms.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
       Text("还没有 Veilopoly 联机邀请").font(.headline)
       Text("邀请会通过当前好友的加密聊天发送。对方需要从游戏大厅进入同一好友的 Veilopoly 页面接受邀请。")
        .font(.subheadline).foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
     } else {
      ForEach(room.rooms) { invite in
       VStack(alignment: .leading, spacing: 10) {
        HStack {
         Image(systemName: "dice.fill")
         Text(invite.hostIsLocal ? "我发起的棋局" : "好友发来的邀请")
          .font(.headline)
         Spacer(minLength: 5)
         Text(invite.accepted ? "已接受" : invite.declined ? "已拒绝" : "待回应")
          .font(.caption)
          .foregroundColor(invite.accepted ? .green : .secondary)
        }
        Text("2 位真人 · 2 位电脑 · 每方独立操控棋子")
         .font(.subheadline).foregroundColor(.secondary)
        if invite.accepted && !invite.declined {
         HStack(spacing: 8) {
          Button("进入或继续对局") { room.open(invite) }
           .buttonStyle(.borderedProminent)
          Button("请求重同步") {
           room.open(invite)
           room.requestResync()
          }
          .buttonStyle(.bordered)
         }
        } else if !invite.hostIsLocal && !invite.declined {
         HStack(spacing: 8) {
          Button("接受邀请") { room.accept(invite) }
           .buttonStyle(.borderedProminent)
          Button("拒绝") { room.decline(invite) }
           .buttonStyle(.bordered)
         }
        } else if invite.hostIsLocal && !invite.accepted && !invite.declined {
         Text("等待好友接受；发送成功不等于好友已经进入房间。")
          .font(.footnote).foregroundColor(.secondary)
        }
       }
       .padding(14)
       .frame(maxWidth: .infinity, alignment: .leading)
       .background(Color.gray.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
      }
     }
    }
    .padding(16)
   }
   .navigationTitle("Veilopoly 双人房间")
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("返回游戏大厅") { dismiss() }
    }
   }
  }
  .navigationViewStyle(.stack)
  .onAppear { room.refresh() }
  .onChange(of: model.messagesRevision) { _ in room.refresh() }
  .onChange(of: sessions.hasSecureSession(for: conversation.peerIdentityID)) { _ in
   room.refresh()
  }
  .fullScreenCover(item: $room.activeGame) { live in
   VeilopolyGameView(multiplayerModel: live.model) {
    room.closeGame()
   }
   .background(VeilopolyLandscapeOrientationRequest())
   .statusBarHidden(true)
  }
 }
}
