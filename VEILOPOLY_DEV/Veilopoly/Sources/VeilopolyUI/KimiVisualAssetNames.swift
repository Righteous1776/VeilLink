/// Kimi K2–K4 visual intake contract. Astra B01 owns the interactive HUD.
/// These optional aliases are intentionally distinct from Astra runtime names.
/// Assets are only loadable after a separately validated resource import.
public enum KimiVisualAssetNames {
 public static let boardBase = "kimiBoardBase"
 public static let tokenPawn = "kimiTokenPawnBlue"
 public static let tokenCar = "kimiTokenCarRed"
 public static let tokenShip = "kimiTokenShipGreen"
 public static let tokenPlane = "kimiTokenPlaneYellow"
 public static let tileRail = "kimiTileRail"
 public static let tileTax = "kimiTileTax"
 public static let tileChance = "kimiTileChance"
 public static let tilePulse = "kimiFxTilePulseAtlas"
 public static let cashChip = "kimiFxCashChipAtlas"
 public static let pawnShadow = "kimiFxPawnShadowAtlas"
 public static let turnBanner = "kimiFxTurnBanner"
 public static let victoryBadge = "kimiFxVictoryBadge"
 public static let cardFaceFrame = "kimiCardFaceFrame"

 public static let runtimeCandidates: [String] = [
  boardBase, tokenPawn, tokenCar, tokenShip, tokenPlane,
  tileRail, tileTax, tileChance, tilePulse, cashChip,
  pawnShadow, turnBanner, victoryBadge, cardFaceFrame
 ]

 /// Existing game sprite aliases remain stable until an art asset is installed.
 public static func tokenCandidate(for player: Int) -> String? {
  switch player {
  case 0: return tokenPawn
  case 1: return tokenCar
  case 2: return tokenShip
  case 3: return tokenPlane
  default: return nil
  }
 }

 /// No Kimi preview or pending finance visual may become an interactive control.
 public static let stagingOnly: [String] = [
  "kimiStarBadge", "kimiChestGreen", "kimiHouseRed", "kimiHouseGreen"
 ]
}

/// K4 palette is a design contract, not an automatic override of Astra artwork.
public enum KimiDayFeltPalette {
 public static let table = "#F5F0E6"
 public static let boardTop = "#0E7C3A"
 public static let tileFill = "#FFFFFF"
 public static let tileStroke = "#94A3B8"
 public static let hudBackground = "#EDE7DC"
 public static let cardBackground = "#FFFFFF"
 public static let primaryText = "#0F172A"
 public static let secondaryText = "#334155"
 public static let tertiaryText = "#64748B"
 public static let bankBackground = "#ECFDF5"
}
