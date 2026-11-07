import Foundation

/// Generated detail sprites. Original Kimi/Kenney files remain fallback choices.
public enum AstraDetailArtwork {
 public struct Asset: Sendable {
  public let alias: String
  public let bytes: Int
  public let sha256: String
 }
 public static let tokenAliases = ["astraTokenPawnBlue", "astraTokenCarRed", "astraTokenShipGreen", "astraTokenPlaneGold"]
 public static let house = "astraHouseGreen"
 public static let hotel = "astraHotelRed"
 public static let assets: [Asset] = [
  .init(alias: "astraTokenPawnBlue", bytes: 15550, sha256: "0ff6cfaabedbc1d26d06e1125f3c5dc29c09feebd20056d11c7f5538427fb05a"),
  .init(alias: "astraTokenCarRed", bytes: 19592, sha256: "d866a39d2887a9f787dad49442f0e41805303d7ed0532cae5f5a79533e2f83d6"),
  .init(alias: "astraTokenShipGreen", bytes: 19059, sha256: "b95aa68888f9ec1e6cbd77f976fde8875d1a9bfc1f010812b5fb5bf1ee2f6642"),
  .init(alias: "astraTokenPlaneGold", bytes: 19927, sha256: "b077808b0cc9f6f86f3a8475642c690e86d780ab7eaa200a6e345883230057c6"),
  .init(alias: "astraHouseGreen", bytes: 20456, sha256: "d5d011b4b20ae1302d7bd3ff002c3064b58a13b72f59fa7ae92a7fd74763c0dd"),
  .init(alias: "astraHotelRed", bytes: 24927, sha256: "bf0a5aa3808b4bcd85ab8fc90acfd9f1f001e30040a060172c231a336bd19b03")
 ]
 public static func resourceURL(_ alias: String) -> URL? {
  Bundle.module.url(forResource: alias, withExtension: "png")
 }
 public static func tokenCandidates(for player: Int) -> [String] {
  guard tokenAliases.indices.contains(player),
        let kimi = KimiVisualAssetNames.tokenCandidate(for: player) else { return [] }
  return [tokenAliases[player], kimi, ["pawnBlue", "carRed", "shipGreen", "planeYellow"][player]]
 }
}
