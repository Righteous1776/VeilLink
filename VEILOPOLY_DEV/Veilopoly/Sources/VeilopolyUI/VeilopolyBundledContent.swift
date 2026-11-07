import Foundation
import VeilopolyEngine

/// Release-independent offline resource contract. Assets come from this package
/// bundle, never from incoming-art folders or an on-demand network download.
public enum VeilopolyBundledContent {
 public static let legacyImages = ["pawnBlue", "carRed", "shipGreen", "planeYellow",
  "die1", "die2", "die3", "die4", "die5", "die6", "house", "hotel",
  "cardChance", "cardChest", "cardChanceAlt", "cardChestAlt", "diceSheetWhite"]
 public static var imageAliases: [String] {
  Array(Set(legacyImages + AstraB01AssetNames.imported + KimiK2BoardCatalog.assets.map(\.alias) +
   KimiK2RuntimeResourceAudit.additional.map(\.alias) + IvoryR1Artwork.items.map(\.alias) +
   AstraDetailArtwork.assets.map(\.alias) + AstraTileArtwork.aliases + [AstraCenterCityArtwork.alias])).sorted()
 }
 public static let sounds = ["diceShuffle", "bankrupt", "build", "diceThrow", "jail", "moveClick",
                            "mortgage", "buildClick", "drawCard", "cash", "purchase", "trade", "turn"]
 public static var missingResources: [String] {
  var expected = imageAliases.map { ($0, "png") } + sounds.map { ($0, "wav") }
  expected.append(("diceSheetWhiteFrames", "xml"))
  return expected.compactMap { name, ext in
   Bundle.module.url(forResource: name, withExtension: ext) == nil ? name + "." + ext : nil
  }
 }
 public static var invalidImages: [String] {
  imageAliases.filter { name in
   guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
         let bytes = try? Data(contentsOf: url), bytes.count >= 33 else { return true }
   return Array(bytes.prefix(8)) != [137, 80, 78, 71, 13, 10, 26, 10]
  }
 }
 public static var compiledTextCounts: [String: Int] {
  let game = GameFactory.make(seed: 1)
  return ["cards": game.cards.compactMap(VeilopolyCardEditorial.presentation).count,
          "streets": game.board.compactMap(VeilopolyWorldEditorial.page).count,
          "issuers": VeilopolyMarketEditorial.issuers.count,
          "guide": VeilopolyGuideLibrary.topics.count,
          "news": VeilopolyBulletinCopy.cityLines.count + VeilopolyBulletinCopy.eventTemplates.values.reduce(0) { $0 + $1.count }]
 }
}
