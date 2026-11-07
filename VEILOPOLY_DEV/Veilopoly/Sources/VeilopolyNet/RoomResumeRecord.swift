import Foundation

/// Room discovery index only. Logical game lives in the existing role-separated
/// A/B save store. Identity IDs are bindings, not keys or authentication claims.
public struct VeilopolyRoomResumeRecord: Codable {
 public let configuration: VeilopolyRoomConfiguration
 public let localIdentityID: String
 public init(configuration: VeilopolyRoomConfiguration, localIdentityID: String) throws {
  guard configuration.isValid, configuration.seat(for: localIdentityID) != nil else {
   throw VeilopolyRoomError.invalidConfiguration
  }
  self.configuration = configuration; self.localIdentityID = localIdentityID
 }
 public func isValid(for identity: String) -> Bool {
  configuration.isValid && localIdentityID == identity && configuration.seat(for: identity) != nil
 }
 public static func filename(for identity: String) -> String {
  let safe = Data(identity.utf8).base64EncodedString()
   .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
   .replacingOccurrences(of: "=", with: "")
  return "ActivePeerRoom-" + safe + ".json"
 }
}
