import Foundation

/// Portable SwiftPM resource acceptance. Validates actual packaged PNG files
/// by Bundle.module lookup and compressed source byte length, without UIKit.
public enum KimiK2RuntimeResourceAudit {
 public struct ExtraResource: Sendable {
  public let alias: String
  public let bytes: Int
  public let gitBlobSHA1: String
 }
 public static let additional: [ExtraResource] = [
  .init(alias: "kimiTokenPawnBlue", bytes: 51150, gitBlobSHA1: "2b7eb8f953732563217a5ab95fc874b70930ff78"),
  .init(alias: "kimiTokenCarRed", bytes: 72502, gitBlobSHA1: "6a883c2622dfa58a07320e28c66ad0aa22fe14ef"),
  .init(alias: "kimiTokenShipGreen", bytes: 70199, gitBlobSHA1: "3616d57d0b82c98f4d98a55febc5436b9da8ebda"),
  .init(alias: "kimiTokenPlaneYellow", bytes: 47511, gitBlobSHA1: "5ffb53cd60e9fe351ddf0d5e1d89ea7aca40f319"),
  .init(alias: "kimiFxTilePulseAtlas", bytes: 101004, gitBlobSHA1: "f7d6602f2d57477876bb5e0f5575cd793e93717b"),
  .init(alias: "kimiFxCashChipAtlas", bytes: 6597, gitBlobSHA1: "1678c2db144a9e662077556d2efaa290d3cf5ded"),
  .init(alias: "kimiFxPawnShadowAtlas", bytes: 11368, gitBlobSHA1: "ab423401c4dbec2bc218e76f59c78b6a82e8ecf4"),
  .init(alias: "kimiFxTurnBanner", bytes: 2221, gitBlobSHA1: "7393402f46dbcfc9db8c3cef0e0b7f2415756e10"),
  .init(alias: "kimiFxVictoryBadge", bytes: 12309, gitBlobSHA1: "8394fc4ce38cc48a5c4befd4d217fca23e305119"),
  .init(alias: "kimiCardFaceFrame", bytes: 3753, gitBlobSHA1: "646e798d0fb47020ef2075becbbc3b3ee152a172"),
 ]
 public static var expectedCount: Int { KimiK2BoardCatalog.assets.count + additional.count }
 public static var expectedBytes: Int {
  KimiK2BoardCatalog.selectedBytes + additional.reduce(0) { $0 + $1.bytes }
 }
 public static func missingResourceNames() -> [String] {
  let aliases = KimiK2BoardCatalog.assets.map(\.alias) + additional.map(\.alias)
  return aliases.filter { Bundle.module.url(forResource: $0, withExtension: "png") == nil }
 }
 public static func invalidResourceLengths() -> [String] {
  let items = KimiK2BoardCatalog.assets.map { ($0.alias, $0.byteCount) } +
   additional.map { ($0.alias, $0.bytes) }
  return items.compactMap { name, bytes in
   guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
         let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
         let length = attributes[.size] as? NSNumber,
         length.intValue == bytes else { return name }
   return nil
  }
 }
}
