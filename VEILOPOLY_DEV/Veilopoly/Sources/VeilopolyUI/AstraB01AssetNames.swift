/// Atlas-free asset-name mapping for the Astra B01 v1.1 runtime subset.
/// Keep renderer-only choices separate from engine rules and source aliases.
public enum AstraB01AssetNames {
 public static let primaryNormal = "astraButtonPrimaryNormal"
 public static let primaryPressed = "astraButtonPrimaryPressed"
 public static let primaryDisabled = "astraButtonPrimaryDisabled"
 public static let secondaryNormal = "astraButtonSecondaryNormal"
 public static let secondaryPressed = "astraButtonSecondaryPressed"
 public static let secondaryDisabled = "astraButtonSecondaryDisabled"
 public static let playerNormal = "astraPlayerNormal"
 public static let playerCurrent = "astraPlayerCurrent"
 public static let playerJailed = "astraPlayerJailed"
 public static let playerBankrupt = "astraPlayerBankrupt"
 public static let actionPanel = "astraPanelAction"
 public static let glassPanel = "astraPanelGlass"
 public static let feedbackError = "astraFeedbackError"
 public static let feedbackPositive = "astraFeedbackPositive"
 public static let cardFace = "astraCardFace"
 public static let buyHero = "astraHeroBuy"
 public static let auctionHero = "astraHeroAuction"
 public static let tradeHero = "astraHeroTrade"
 public static let bankHero = "astraHeroBank"
 public static let settlementHero = "astraHeroSettlement"

 public static let heroSize = (width: 256, height: 174)

 public static func primaryButton(enabled: Bool, pressed: Bool) -> String {
  if !enabled { return primaryDisabled }
  return pressed ? primaryPressed : primaryNormal
 }
 public static func secondaryButton(enabled: Bool, pressed: Bool) -> String {
  if !enabled { return secondaryDisabled }
  return pressed ? secondaryPressed : secondaryNormal
 }
 public static func playerSkin(bankrupt: Bool, jailed: Bool, current: Bool) -> String {
  if bankrupt { return playerBankrupt }
  if jailed { return playerJailed }
  return current ? playerCurrent : playerNormal
 }
 public static func phaseHero(_ name: String) -> String? {
  switch name {
  case "BUY": return buyHero
  case "AUCTION": return auctionHero
  case "TRADE": return tradeHero
  case "BANK": return bankHero
  case "SETTLEMENT": return settlementHero
  default: return nil
  }
 }
 public static let imported: [String] = [
  primaryNormal, primaryPressed, primaryDisabled,
  secondaryNormal, secondaryPressed, secondaryDisabled,
  playerNormal, playerCurrent, playerJailed, playerBankrupt,
  actionPanel, glassPanel, feedbackError, feedbackPositive, cardFace,
  buyHero, auctionHero, tradeHero, bankHero, settlementHero
 ]
}
