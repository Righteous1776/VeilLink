import Foundation

/// One continuous Ivory / antique-gold / deep-teal composition.
public enum IvoryUnifiedVisualSystem {
 public static let identity = "VEILOPOLY-IVORY-UNIFIED-R2"
 public static let minimumIOSMajorVersion = 15
 public static let boardRootName = "Veilopoly/IvoryUnifiedBoard"
 public static let masterImageAlias = IvoryR1Artwork.centerCandidate
 public static let masterImageID = "VL-IVORY-R1-004"
 public static let turnBannerAlias = IvoryR1Artwork.bannerCandidate
 public static let defaultLightTheme = true
 public static let centerX = 512.0
 public static let centerY = 470.0
 public static let centerSize = 448.0
 public static let chanceDeckX = 248.0
 public static let chestDeckX = 776.0
 public static let boardWidth = 1024.0
 public static let boardHeight = 940.0
 public static let antiqueGold = (r: 0.70, g: 0.54, b: 0.31)
 public static let deepTeal = (r: 0.10, g: 0.26, b: 0.27)
 public static let ivoryPaper = (r: 0.96, g: 0.93, b: 0.86)
 public static let integratedRuntimeAliases = [
  "kimiK2BoardTableLight", "kimiK2BoardEdgeLight",
  "kimiK2BoardBaseLight", "kimiK2BoardFrameLight",
  AstraTileArtwork.face, masterImageAlias,
  IvoryR1Artwork.chanceCard, IvoryR1Artwork.chestCard,
  IvoryR1Artwork.bannerCandidate, IvoryR1Artwork.victoryBadge,
  AstraDetailArtwork.house, AstraDetailArtwork.hotel
 ]
 /// No new duplicate icon sheets are drawn over Codex's existing atlas.
 public static let codexSpecialIconsRemainCanonical = true
 public static let independentGameplayState = false
}
