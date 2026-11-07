/// Source-level wiring inventory, not iOS device acceptance.
/// Astra retains its interactive HUD. Two overlapping/duplicated art assets
/// are deliberately deferred instead of lowering UI fidelity.
public enum KimiK2VisualUtilization {
 public static let sourceWired: [String] = [
  "kimiK2BoardTableDark",
  "kimiK2BoardTableLight",
  "kimiK2BoardEdgeDark",
  "kimiK2BoardEdgeLight",
  "kimiK2BoardBaseDark",
  "kimiK2BoardBaseLight",
  "kimiK2BoardFrameDark",
  "kimiK2BoardFrameLight",
  "kimiK2BoardCenterEmblem",
  "kimiK2TilesDark",
  "kimiK2TilesLight",
  "kimiK2OwnerStripes",
  "kimiK2TileMortgageOverlay",
  "kimiK2BuildingShadow",
  "kimiTokenPawnBlue",
  "kimiTokenCarRed",
  "kimiTokenShipGreen",
  "kimiTokenPlaneYellow",
  "kimiFxTilePulseAtlas",
  "kimiFxCashChipAtlas",
  "kimiFxPawnShadowAtlas",
  "kimiFxTurnBanner",
  "kimiFxVictoryBadge",
 ]
 public static let deliberatelyDeferred: [String] = [
  "kimiK2SpecialIconsMask",
  "kimiCardFaceFrame",
 ]
 public static var referencedCount: Int { sourceWired.count }
 public static var selectedCount: Int {
  KimiK2BoardCatalog.assets.count + KimiK2RuntimeResourceAudit.additional.count
 }
}
