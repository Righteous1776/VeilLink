/// Game liveness is NOT transport/cryptographic liveness. Missing game
/// heartbeats must never tear down a healthy shared E2EE chat session.
public enum VeilopolyRoomLinkPolicy {
 public static func shouldPauseGame(secureSessionReady: Bool, secondsSincePeer: Double) -> Bool {
  !secureSessionReady || !secondsSincePeer.isFinite || secondsSincePeer > 15
 }
 public static func shouldRequestSecureRecovery(secureSessionReady: Bool, userInitiated: Bool) -> Bool {
  userInitiated && !secureSessionReady
 }
}
