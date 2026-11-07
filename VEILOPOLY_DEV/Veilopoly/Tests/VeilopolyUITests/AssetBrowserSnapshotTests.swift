import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class AssetBrowserSnapshotTests: XCTestCase {
 func testEveryPhaseAndSeatCanReadWithoutChangingGameOrInitializingFinance() throws {
  for phase in Phase.allCases {
   var game = GameFactory.make(seed: 7201, humanCount: 2)
   game.turn.phase = phase
   game.board[1].owner = 0
   game.board[3].owner = 1
   let before = StateDigest.hash(game)
   for seat in game.players.indices {
    let data = try XCTUnwrap(VeilopolyAssetBrowserSnapshot(game: game, player: seat))
    XCTAssertEqual(data.phase, phase)
    XCTAssertEqual(data.sequence, game.nextSeq)
    XCTAssertEqual(data.player, game.players[seat])
    XCTAssertEqual(data.properties, game.board.filter { $0.owner == seat })
    XCTAssertEqual(data.summary, VeilopolyAssetSummary(game: game, player: seat))
    XCTAssertNil(data.account)
    XCTAssertNil(data.market)
   }
   XCTAssertEqual(StateDigest.hash(game), before)
   XCTAssertNil(game.banking)
  }
 }

 func testBankMarketAndTradeReadExistingStateAndCopiesAreIsolated() throws {
  var game = GameFactory.make(seed: 7202, humanCount: 2)
  var market = StockMarketEngine.initial(seed: game.seed)
  _ = try StockMarketEngine.buy(&market, player: 1, symbol: "VTL", shares: 2, cash: &game.players[1].cash)
  game.banking = IntegratedBankLedger(completedTurns: 5, market: market)
  game.banking?.accounts[1].loans = [SandboxLoan(id: 7, principal: 100,
   interestBasisPoints: 2000, duePeriod: 8, periods: 1, totalDue: 120)]
  game.trade = TradeState(from: 0, to: 1, offer: TradeTransfer(cash: 50, tiles: [1]),
                         request: TradeTransfer(tiles: [3], chanceCards: 1))
  game.players[1].bankrupt = true // Eliminated seats remain inspectable.
  let before = StateDigest.hash(game)
  let data = try XCTUnwrap(VeilopolyAssetBrowserSnapshot(game: game, player: 1))
  XCTAssertEqual(data.account, game.banking?.accounts[1])
  XCTAssertEqual(data.market, market)
  XCTAssertEqual(data.trade, game.trade)
  XCTAssertEqual(data.completedTurns, 5)
  XCTAssertEqual(data.summary.liabilities, 120)
  var detachedMarket = try XCTUnwrap(data.market)
  detachedMarket.quotes[0].currentPriceCents += 1
  var detachedAccount = try XCTUnwrap(data.account)
  detachedAccount.loans.removeAll()
  XCTAssertEqual(StateDigest.hash(game), before)
 }

 func testInvalidSeatCannotReadAnotherPlayersAccount() {
  let game = GameFactory.make(seed: 7203, humanCount: 1)
  XCTAssertNil(VeilopolyAssetBrowserSnapshot(game: game, player: -1))
  XCTAssertNil(VeilopolyAssetBrowserSnapshot(game: game, player: game.players.count))
  XCTAssertNil(VeilopolyAssetBrowserSnapshot(game: game, player: Int.max))
 }
}
