import Foundation

/// Authenticated chat messages still need strict room-role checks.
/// The transport proves who sent each message; this validates what that
/// authenticated participant is allowed to claim within the game session.
public enum VeilopolyRoomAuthorization {
 public static func allows(_ command: GameMessageType,
                           hostIsLocal: Bool, messageIsOutgoing: Bool) -> Bool {
  let fromHost = messageIsOutgoing == hostIsLocal
  switch command {
  case .invite, .move, .snapshot, .syncHint: return fromHost
  case .accept, .decline, .intent, .resync: return !fromHost
  }
 }
}
