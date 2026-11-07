import VeilopolyEngine

/// Read-only public-information projection. Reading never opens a bank account,
/// initializes a market, commits a Move or consumes a random number.
public struct VeilopolyAssetBrowserSnapshot {
 public let player: Player
 public let properties: [Tile]
 public let summary: VeilopolyAssetSummary
 public let account: IntegratedBankAccount?
 public let market: StockMarketState?
 public let trade: TradeState?
 public let completedTurns: Int?
 public let phase: Phase
 public let sequence: Int

 public init?(game: GameState, player index: Int) {
  guard game.players.indices.contains(index) else { return nil }
  let inspected = game.players[index]
  player = inspected
  properties = game.board.filter { $0.owner == inspected.id }
  summary = VeilopolyAssetSummary(game: game, player: index)
  account = game.banking.flatMap {
   $0.accounts.indices.contains(index) ? $0.accounts[index] : nil
  }
  market = game.banking?.market
  trade = game.trade
  completedTurns = game.banking?.completedTurns
  phase = game.turn.phase
  sequence = game.nextSeq
 }
}
