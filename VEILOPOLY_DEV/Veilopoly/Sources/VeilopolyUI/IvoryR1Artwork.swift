import Foundation

/// Supplemental ivory-classical illustration set for Veilopoly.
/// Generated sprites are additive. Codex's Astra tile face, city inlay,
/// house/hotel and tile pictograms remain untouched and authoritative.
/// The three active assets are purely visual: the Engine still decides
/// card contents, purchases, turns and winners.
public enum IvoryR1Artwork {
 public struct Asset: Sendable, Equatable {
  public let id: String
  public let alias: String
  public let sha256: String
  public let gitBlobSHA1: String
  public let bytes: Int
  public let defaultUse: Bool
  public init(_ id: String, _ alias: String, _ sha256: String,
              _ gitBlobSHA1: String, _ bytes: Int, _ defaultUse: Bool) {
   self.id = id; self.alias = alias; self.sha256 = sha256
   self.gitBlobSHA1 = gitBlobSHA1; self.bytes = bytes
   self.defaultUse = defaultUse
  }
 }
 public static let chanceCard = "ivoryR1ChanceCard"
 public static let chestCard = "ivoryR1ChestCard"
 public static let victoryBadge = "ivoryR1VictoryBadge"
 public static let centerCandidate = "ivoryR1CenterInlay"
 public static let houseCandidate = "ivoryR1HousePerspective"
 public static let hotelCandidate = "ivoryR1HotelPerspective"
 public static let bannerCandidate = "ivoryR1TurnBanner"
 public static let items: [Asset] = [
  .init("VL-IVORY-R1-001", "ivoryR1ChanceCard", "1d92d2d7851b05057aa5e26725264de6cbb20e7a5bbd5b8f85986070552c9399", "926f2752a0d2a40d93ae1b033b477d734e5684e9", 307596, true),
  .init("VL-IVORY-R1-002", "ivoryR1ChestCard", "e08cdd76f140ba7522ca9f1bf147af1019fb31374b7a1ed9929728765feead9e", "b75193e9839a5e5d836285d28575fa92263dedb8", 312915, true),
  .init("VL-IVORY-R1-003", "ivoryR1VictoryBadge", "5c820135ac53c336a4115741c5815a10fa103b64afff222d9578bdd20f64a802", "8f40d15f68debd35027fee156ae1044821449dbf", 250175, true),
  .init("VL-IVORY-R1-004", "ivoryR1CenterInlay", "abe2f4615e29140d58f7fce63cdaffaa044e6352392f976b829917e701fd255d", "8fdb360b629e74820d26005ddab2154e20414058", 650551, false),
  .init("VL-IVORY-R1-005", "ivoryR1HousePerspective", "d61495a020617853a196be81fcc2f076afdc8a7b6b5a5fbf205ce3a29ca3a28e", "7ca6874e7b15c84bce46400afa94751b93e9418b", 106370, false),
  .init("VL-IVORY-R1-006", "ivoryR1HotelPerspective", "a4fbe39327bddfc2b783a9493b1d113b4ab6e52e5818ea6a35ece59fd99e8586", "eb95ef1594d18ab0fa15abd8d6b1b99e0bae2a18", 148289, false),
  .init("VL-IVORY-R1-007", "ivoryR1TurnBanner", "7268cee8f9ec932c4cb2f508fbc18c4d11238cdcbbe8f0fd819017e5a9edc3a6", "d036b32b92981ad3dda465067c14314439919fab", 147927, false),
  .init("VL-IVORY-R1-008", "ivoryR1IconRail", "dc5b57a4c9e901372a7c3a28c13ae5ff57029a7ed7f4fa3226b9bbb81f336c1b", "087cda76867287b9a6596569229c45a9264503df", 31095, false),
  .init("VL-IVORY-R1-009", "ivoryR1IconElectric", "7362cc7e3e5b398750d4a0019937ef3a71f0c2eecc825794a2122c3f9162aede", "7b1c874e2e580db9dbdd415198024d04f6bbac4b", 29085, false),
  .init("VL-IVORY-R1-010", "ivoryR1IconWater", "23cf42b8dd0b5d8ac0f235562395699d6a7939646cdf135bb62d1fa525526777", "d06313643054196dd07b3c28ea96abda33a4499d", 29899, false),
  .init("VL-IVORY-R1-011", "ivoryR1IconTax", "0756ed96e85b251b6ebbf274b817d0774d9df1e15062e13439741e1352f9141b", "8387c455cf43a325338520eab3a3d96629a57e9b", 36762, false),
  .init("VL-IVORY-R1-012", "ivoryR1IconInspect", "5a741d5aff4a5aff5d73c381100d38369c1f8c08b0c9763ae551fe5647c72c85", "ed743fb185b839a210040311e8d800edb7e94900", 33407, false),
  .init("VL-IVORY-R1-013", "ivoryR1IconChance", "97ab04f49feddb182cf939fc5fe1843467b839488e5a3c4b40cf412ae5a107b8", "070d6c935fe9614291601c03a303d73ec56bf8f6", 30255, false),
  .init("VL-IVORY-R1-014", "ivoryR1IconTrade", "696c0fdd38ac227360d876e9afb4ec317ec58870d6ffeeb6f8393b377b2716a4", "f10d5f71818988ccefa126680609db17ab1f1da1", 30919, false),
  .init("VL-IVORY-R1-015", "ivoryR1IconTransfer", "dc4b5dba0e43833797baea8f1d866dee1ba2cd6c76f5694fd9bad9cc69c2025c", "239c8cd9930458ace40bf8241d16bc3b73bdf1c3", 28974, false),
  .init("VL-IVORY-R1-016", "ivoryR1IconJail", "9ab62ed61ee5522072de08731686fe08a501161c9be70642d87f0e77bd1ad897", "23636ca6f9818e9f770359aec91a14ce02d8b4f3", 28781, false),
  .init("VL-IVORY-R1-017", "ivoryR1IconParking", "b413da2faf96798b8e07074ea60e411fef6b20dd43daa3e73786feaac76325df", "7a921218648c72957f7027a9fedbe4d5fd4bbd96", 29229, false),
  .init("VL-IVORY-R1-018", "ivoryR1IconMove", "52b6f5b6773fbeb32c07883528b0c6e18693e03422b90fb61671724895b857d4", "3e22a86ca1d945ebb7dca7dbef1829a4de29fdf7", 28378, false),
  .init("VL-IVORY-R1-019", "ivoryR1IconBrand", "4764f0c99639e068c6823535e6b74e9b551a088e53325d8bf96d4eacd48cf050", "cc05a9d40b34e8bcd3e25b4b8cf19cb9ab03fe79", 33259, false),
 ]
 public static var activeAliases: [String] { items.filter(\.defaultUse).map(\.alias) }
 public static var candidateAliases: [String] { items.filter { !$0.defaultUse }.map(\.alias) }
 public static func resourceURL(for alias: String) -> URL? {
  guard items.contains(where: { $0.alias == alias }) else { return nil }
  return Bundle.module.url(forResource: alias, withExtension: "png")
 }
 /// Always keep the existing Kenney/Veilopoly deck thumbnails as fallback.
 public static func preferredCardAlias(isChance: Bool) -> String {
  let next = isChance ? chanceCard : chestCard
  return resourceURL(for: next) == nil
    ? (isChance ? "cardChance" : "cardChest") : next
 }
 public static func preferredVictoryBadgeAlias() -> String {
  resourceURL(for: victoryBadge) == nil ? "kimiFxVictoryBadge" : victoryBadge
 }
}