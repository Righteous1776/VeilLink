import Foundation
import VeilopolyEngine

/// Application payloads are carried ONLY inside the pre-existing encrypted,
/// authenticated VeilLink chat. No plaintext BLE, relays or unauthenticated IO.
/// The host must verify the sender identity and role separately from this codec.
public enum VeilopolyRoomWire {
 public static let maximumTextBytes = 12_000
 private static let prefix = "\u{2063}VLVP1:"

 public enum CodecError: Error, Equatable {
  case invalidShape, oversized
 }

 public static func encode(_ envelope: GameEnvelope) throws -> String {
  guard isValid(envelope) else { throw CodecError.invalidShape }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let payload = try encoder.encode(envelope)
  let message = prefix + payload.base64EncodedString()
  guard message.utf8.count <= maximumTextBytes else { throw CodecError.oversized }
  return message
 }

 public static func decode(_ message: String) -> GameEnvelope? {
  guard message.hasPrefix(prefix), message.utf8.count <= maximumTextBytes,
        let bytes = Data(base64Encoded: String(message.dropFirst(prefix.count))),
        let packet = try? JSONDecoder().decode(GameEnvelope.self, from: bytes),
        isValid(packet) else { return nil }
  return packet
 }

 public static func isValid(_ packet: GameEnvelope) -> Bool {
  guard UUID(uuidString: packet.gameId) != nil else { return false }
  let noRejection = packet.rejectedSeq == nil && packet.rejectionReason == nil
  let noHead = packet.hostHeadSeq == nil
  switch packet.kind {
  case .invite:
   return noRejection && noHead &&
    packet.invite?.gameId == packet.gameId &&
    packet.invite?.seed != 0 && packet.invite?.humanSeats == [0, 1] &&
    packet.intent == nil && packet.move == nil &&
    packet.snapshot == nil && packet.resync == nil
  case .accept, .decline:
   return noRejection && noHead && packet.invite == nil &&
    packet.intent == nil && packet.move == nil &&
    packet.snapshot == nil && packet.resync == nil
  case .intent:
   return noRejection && noHead && packet.invite == nil &&
    packet.move == nil && packet.snapshot == nil && packet.resync == nil &&
    packet.intent.map { $0.seq >= 0 && $0.player == 1 } == true
  case .move:
   return noRejection && noHead && packet.invite == nil &&
    packet.intent == nil && packet.snapshot == nil && packet.resync == nil &&
    packet.move.map {
     $0.seq >= 0 && $0.seq == $0.move.seq &&
      !$0.stateHash.isEmpty && $0.stateHash.utf8.count <= 128
    } == true
  case .rejected:
   return noHead && packet.invite == nil && packet.intent == nil &&
    packet.move == nil && packet.snapshot == nil && packet.resync == nil &&
    packet.rejectedSeq.map { $0 >= 0 } == true &&
    packet.rejectionReason.map { !$0.isEmpty && $0.utf8.count <= 240 } == true
  case .resync:
   return noRejection && noHead && packet.invite == nil &&
    packet.intent == nil && packet.move == nil && packet.snapshot == nil &&
    packet.resync.map { $0.afterSeq >= -1 &&
                         !$0.observedHash.isEmpty &&
                         $0.observedHash.utf8.count <= 128 } == true
  case .snapshot:
   return noRejection && noHead && packet.invite == nil &&
    packet.intent == nil && packet.move == nil && packet.resync == nil &&
    packet.snapshot.map { $0.lastAppliedSeq >= -1 && !$0.stateHash.isEmpty } == true
  case .syncHint:
   return noRejection && packet.invite == nil &&
    packet.intent == nil && packet.move == nil &&
    packet.snapshot == nil && packet.resync == nil &&
    packet.hostHeadSeq.map { $0 >= -1 } == true
  }
 }

 public static func previewText(for text: String) -> String? {
  guard let packet = decode(text) else { return nil }
  switch packet.kind {
  case .invite: return "[Veilopoly] 好友邀请你加入大富翁"
  case .accept: return "[Veilopoly] 已接受游戏邀请"
  case .decline: return "[Veilopoly] 已拒绝游戏邀请"
  case .intent: return "[Veilopoly] 玩家提交回合操作"
  case .move: return "[Veilopoly] 加密棋局已同步"
  case .rejected: return "[Veilopoly] 房主拒绝了本次不合法操作"
  case .resync: return "[Veilopoly] 请求恢复棋局"
  case .snapshot: return "[Veilopoly] 房主发送恢复快照"
  case .syncHint: return "[Veilopoly] 可继续恢复离线回合"
  }
 }
}
