import VeilopolyEngine

/// Read-only summaries for the native decision cards. Prices, cash, transfers
/// and rejection reasons come from the current canonical game, not artwork.
public struct VeilopolyPurchaseReview: Equatable {
 public let name: String
 public let price: Int
 public let cash: Int
 public let cashAfterPurchase: Int?
 public let rejection: String?
 public init?(game: GameState, player: Int, tile: Int) {
  guard game.players.indices.contains(player), game.board.indices.contains(tile),
        game.board[tile].purchasable,
        (0...1_000_000_000).contains(game.players[player].cash),
        (0...1_000_000).contains(game.board[tile].price) else { return nil }
  name = game.board[tile].name; price = game.board[tile].price
  cash = game.players[player].cash
  cashAfterPurchase = cash >= price ? cash - price : nil
  rejection = VeilopolyGamePresentation.rejection(game,
   move: Move(.buyProperty, player: player, seq: game.nextSeq, tile: tile))
 }
}

public struct VeilopolyAuctionReview: Equatable {
 public let name: String
 public let currentBid: Int
 public let minimumBid: Int
 public let leader: String
 public let cash: Int
 public init?(game: GameState, player: Int) {
  guard let auction = game.auction, game.players.indices.contains(player),
        game.board.indices.contains(auction.tile),
        (0...1_000_000_000).contains(auction.currentBid),
        (auction.bidder.map { game.players.indices.contains($0) } ?? true) else { return nil }
  name = game.board[auction.tile].name; currentBid = auction.currentBid
  minimumBid = currentBid + 1
  leader = auction.bidder.map { game.players[$0].name } ?? "暂无出价"
  cash = game.players[player].cash
 }
 public static func rejection(game: GameState, player: Int, draft: String) -> String? {
  // Zero is the reducer's explicit fold command, NEVER a bid submitted by an
  // empty/invalid amount field. The separate fold button remains unchanged.
  guard let value = Int(draft), value > 0 else { return "请输入正整数竞价；退出本次竞拍请点弃权" }
  return VeilopolyGamePresentation.rejection(game,
   move: Move(.bid, player: player, seq: game.nextSeq, amount: value))
 }
}

public struct VeilopolyTransferReview: Equatable {
 public let cash: Int
 public let properties: [String]
 public let chanceCards: Int
 public let chestCards: Int
 fileprivate init?(game: GameState, transfer: TradeTransfer) {
  guard (0...1_000_000_000).contains(transfer.cash),
        transfer.tiles.allSatisfy({ game.board.indices.contains($0) }),
        (0...16).contains(transfer.chanceCards), (0...16).contains(transfer.chestCards) else { return nil }
  cash = transfer.cash; properties = transfer.tiles.map { game.board[$0].name }
  chanceCards = transfer.chanceCards; chestCards = transfer.chestCards
 }
}

public struct VeilopolyTradeReview: Equatable {
 public let otherPlayer: String
 public let giving: VeilopolyTransferReview
 public let receiving: VeilopolyTransferReview
 public let cashAfterTrade: Int
 public init?(game: GameState, viewer: Int) {
  guard let trade = game.trade, game.players.indices.contains(viewer),
        game.players.indices.contains(trade.from), game.players.indices.contains(trade.to),
        trade.from != trade.to, viewer == trade.from || viewer == trade.to,
        let offered = VeilopolyTransferReview(game: game, transfer: trade.offer),
        let requested = VeilopolyTransferReview(game: game, transfer: trade.request),
        (0...1_000_000_000).contains(game.players[viewer].cash) else { return nil }
  let isProposer = viewer == trade.from
  giving = isProposer ? offered : requested
  receiving = isProposer ? requested : offered
  otherPlayer = game.players[isProposer ? trade.to : trade.from].name
  cashAfterTrade = game.players[viewer].cash - giving.cash + receiving.cash
 }
}

public enum VeilopolyDecisionLayout {
 public static let minimumActionWidth = 112.0
 public static let actionSpacing = 8.0
 public static func columns(contentWidth: Double, accessibilityText: Bool) -> Int {
  guard !accessibilityText, contentWidth.isFinite,
        contentWidth >= 2 * minimumActionWidth + actionSpacing else { return 1 }
  return 2
 }
}
