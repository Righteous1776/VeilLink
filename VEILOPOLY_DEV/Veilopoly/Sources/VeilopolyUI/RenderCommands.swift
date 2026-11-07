#if os(iOS) && canImport(SwiftUI) && canImport(SpriteKit)
import SwiftUI
import SpriteKit
import VeilopolyEngine

public struct DiceAnim { public let values: [Int]; public init(_ values: [Int]) { self.values = values } }
public enum FxKind { case purchase, build, mortgage, jail, bankrupt, cash }
public struct TurnInfo { public let player: Int; public let text: String }
public enum ViewCommand {
 case diceRoll(DiceAnim)
 case tokenMove(player: Int, path: [Int])
 case tileFx(tile: Int, kind: FxKind)
 case cardShow(deck: DeckKind, text: String)
 case cashFloat(player: Int, delta: Int)
 case banner(TurnInfo)
}

/// The rendering queue is derived solely from the immutable result effects.
/// Renderer ack goes to the session coordinator; it does not call or mutate engine rules.
public enum CommandTranslator {
 public static func translate(_ effects: [Effect]) -> [ViewCommand] {
  effects.compactMap { e in
   switch e.kind {
   case .diceRolled: return .diceRoll(DiceAnim(e.dice ?? [1,1]))
   case .playerMoved:
    guard let player = e.player, let from = e.from, let to = e.to else { return nil }
    let count = e.steps ?? 0
    let path: [Int]
    if count > 0 { path = (1...count).map { (from + $0) % 40 } }
    else if count < 0 { path = (1...(-count)).map { (from - $0 + 40) % 40 } }
    else { path = [to] }
    return .tokenMove(player: player, path: path)
   case .cardDrawn: return .cardShow(deck: e.deck ?? .chance, text: e.text ?? "")
   case .bankDeposited, .bankWithdrawn, .bankBorrowed, .bankRepaid,
        .bankInvestmentOpened, .bankInvestmentSettled, .stockBought, .stockSold:
    return .cashFloat(player: e.player ?? 0, delta: e.amount ?? 0)
   case .cashChanged, .passedGo:
    return .cashFloat(player: e.player ?? 0, delta: e.amount ?? 0)
   case .bought, .auctionWon: return .tileFx(tile: e.tile ?? 0, kind: .purchase)
   case .built, .soldBuilding: return .tileFx(tile: e.tile ?? 0, kind: .build)
   case .mortgaged, .redeemed: return .tileFx(tile: e.tile ?? 0, kind: .mortgage)
   case .jailed: return .tileFx(tile: 10, kind: .jail)
   case .bankrupt: return .tileFx(tile: e.tile ?? 0, kind: .bankrupt)
   case .turnEnded: return .banner(TurnInfo(player: e.to ?? 0, text: "新回合"))
   case .extraRoll: return .banner(TurnInfo(player: e.player ?? 0, text: "双骰：再掷一次"))
   case .gameWon: return .banner(TurnInfo(player: e.player ?? 0, text: "本局获胜"))
   default: return nil
   }
  }
 }
}
#endif
