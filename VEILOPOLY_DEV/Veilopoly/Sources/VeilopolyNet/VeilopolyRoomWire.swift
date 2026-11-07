import Foundation
import VeilopolyEngine

/// Encoded only as text inside an already authenticated VeilLink E2EE chat.
/// This is NOT a standalone radio, relay or trust mechanism. The host adapter
/// must also verify the actual sender identity from the decrypted chat record.
public enum VeilopolyRoomWire {
 public static let version = 1
 public static let maximumTextBytes = 12_000
 private static let prefix = "\u{2063}VLVP1:"

 public enum CodecError: Error, Equatable {
  case invalidGameID, invalidShape, oversized
 }

 public static func encode(_ envelope: GameEnvelope) throws -> String {
  guard isValid(envelope) else { throw CodecError.invalidShape }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let payload = try encoder.encode(envelope)
  let text = prefix + payload.base64EncodedString()
  guard text.utf8.count <= maximumTextBytes else { throw CodecError.oversized }
  return text
 }

 public static func decode(_ text: String) -> GameEnvelope? {
  guard text.utf8.count <= maximumTextBytes, text.hasPrefix(prefix),
        let bytes = Data(base64Encoded: String(text.dropFirst(prefix.count))),
        let envelope = try? JSONDecoder().decode(GameEnvelope.self, from: bytes),
        isValid(envelope) else { return nil }
  return envelope
 }

 public static func isValid(_ packet: GameEnvelope) -> Bool {
  guard UUID(uuidString: packet.gameId) != nil else { return false }
  switch packet.kind {
  case .invite:
   return packet.invite?.gameId == packet.gameId &&
    packet.invite?.seed != 0 && packet.invite?.humanSeats == [0, 1] &&
    packet.intent == nil && packet.move == nil &&
    packet.snapshot == nil && packet.resync == nil
  case .accept, .decline:
   return packet.invite == nil && packet.intent == nil &&
    packet.move == nil && packet.snapshot == nil && packet.resync == nil
  case .intent:
   return packet.invite == nil && packet.move == nil &&
    packet.snapshot == nil && packet.resync == nil &&
    packet.intent.map { $0.seq >= 0 && $0.player == 1 } == true
  case .move:
   return packet.invite == nil && packet.intent == nil &&
    packet.snapshot == nil && packet.resync == nil &&
    packet.move.map {
     $0.seq >= 0 && $0.seq == $0.move.seq && !$0.stateHash.isEmpty &&
       $0.stateHash.utf8.count <= 128
    } == true
  case .resync:
   return packet.invite == nil && packet.intent == nil &&
    packet.move == nil && packet.snapshot == nil &&
    packet.resync.map { $0.afterSeq >= -1 && !$0.observedHash.isEmpty &&
                         $0.observedHash.utf8.count <= 128 } == true
  case .snapshot:
   return packet.invite == nil && packet.intent == nil &&
    packet.move == nil && packet.resync == nil && packet.hostHeadSeq == nil &&
    packet.snapshot.map { $0.lastAppliedSeq >= -1 && !$0.stateHash.isEmpty } == true
  case .syncHint:
   return packet.invite == nil && packet.intent == nil &&
    packet.move == nil && packet.snapshot == nil && packet.resync == nil &&
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
  case .resync: return "[Veilopoly] 请求恢复棋局"
  case .snapshot: return "[Veilopoly] 房主发送恢复快照"
  case .syncHint: return "[Veilopoly] 可继续恢复离线回合
  }
 }
}
