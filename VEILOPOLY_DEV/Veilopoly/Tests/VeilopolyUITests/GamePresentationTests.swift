import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class GamePresentationTests: XCTestCase {
 func testPropertyControlsUseReducerLegalityWithoutMutatingGame() {
  var game = GameFactory.make(seed: 99, humanCount: 1)
  game.turn.phase = .manage
  let unavailable = Move(.buildHouse, player: 0, seq: game.nextSeq, tile: 1)
  XCTAssertNotNil(VeilopolyGamePresentation.rejection(game, move: unavailable))
  game.board[1].owner = 0
  game.board[3].owner = 0
  let before = StateDigest.hash(game)
  XCTAssertNil(VeilopolyGamePresentation.rejection(game, move: unavailable))
  XCTAssertEqual(StateDigest.hash(game), before)
  game.turn.phase = .roll
  XCTAssertNotNil(VeilopolyGamePresentation.rejection(game, move: unavailable))
 }

 func testAssetSummaryIncludesBankPrincipalStockAndDebtExactlyOnce() throws {
  var game = GameFactory.make(seed: 100, humanCount: 1)
  game.board[1].owner = 0
  game.board[1].price = 200; game.board[1].houseCost = 100; game.board[1].houses = 1
  var market = StockMarketEngine.initial(seed: game.seed)
  _ = try StockMarketEngine.buy(&market, player: 0, symbol: "VTL", shares: 10, cash: &game.players[0].cash)
  var ledger = IntegratedBankLedger(market: market)
  ledger.accounts[0].savings = [.init(id: 1, feature: .demandDeposit, principal: 300,
                                     unlockPeriod: 0, payoutBasisPoints: 0)]
  ledger.accounts[0].positions = [.init(id: 2, feature: .managedFund, principal: 200, duePeriod: 5)]
  ledger.accounts[0].loans = [.init(id: 3, principal: 100, interestBasisPoints: 2000,
                                   duePeriod: 5, periods: 1, totalDue: 120)]
  game.banking = ledger
  let before = StateDigest.hash(game)
  let summary = VeilopolyAssetSummary(game: game, player: 0)
  XCTAssertEqual(summary.cash, 1314)
  XCTAssertEqual(summary.property, 300)
  XCTAssertEqual(summary.stocks, 185)
  XCTAssertEqual(summary.netWorth, 2179)
  XCTAssertEqual(StateDigest.hash(game), before)
  game.board[1].mortgaged = true
  XCTAssertEqual(VeilopolyAssetSummary(game: game, player: 0).property, 200)
 }

 func testAutomaticDecisionPresentationExcludesFreeManagementAndAnimation() {
  for phase in [Phase.tileResolve, .auction, .trade, .debt, .finished] {
   XCTAssertTrue(VeilopolyGamePresentation.requiresDecision(phase))
  }
  for phase in [Phase.roll, .moveAnim, .manage] {
   XCTAssertFalse(VeilopolyGamePresentation.requiresDecision(phase))
  }
 }

 func testCounterOfferKeepsPropertyWhenCashTermsChange() throws {
  var game = GameFactory.make(seed: 101, humanCount: 2)
  game.board[1].owner = 0; game.board[3].owner = 1
  game.turn.phase = .trade
  let trade = TradeState(from: 0, to: 1,
   offer: TradeTransfer(cash: 20, tiles: [1]), request: TradeTransfer(cash: 50, tiles: [3]))
  game.trade = trade
  let counter = VeilopolyGamePresentation.counterOffer(trade, offeredCash: 35, requestedCash: 10,
                                                      sequence: game.nextSeq)
  XCTAssertEqual(counter.offer?.tiles, [3])
  XCTAssertEqual(counter.request?.tiles, [1])
  let (next, _) = try VeilopolyEngine.apply(game, VeilopolyEngine.context(game), counter).get()
  XCTAssertEqual(next.trade?.from, 1)
  XCTAssertEqual(next.trade?.offer.cash, 35)
  let (accepted, _) = try VeilopolyEngine.apply(next, VeilopolyEngine.context(next),
   Move(.acceptTrade, player: 0, seq: next.nextSeq)).get()
  XCTAssertEqual(accepted.board[1].owner, 1)
  XCTAssertEqual(accepted.board[3].owner, 0)
 }

 func testCombinedPropertyBankStockTradeFlowReplaysAsOneGame() throws {
  var initial = GameFactory.make(seed: 102, humanCount: 2)
  initial.turn.phase = .manage
  initial.board[1].owner = 0; initial.board[3].owner = 0; initial.board[6].owner = 1
  let moves = [
   Move(.buildHouse, player: 0, seq: 0, tile: 1),
   Move(.bankDeposit, player: 0, seq: 1, amount: 100, financeProduct: .demandDeposit),
   Move(.stockBuy, player: 0, seq: 2, stockSymbol: "VTL", stockShares: 10),
   Move(.stockTick, player: 0, seq: 3),
   Move(.stockSell, player: 0, seq: 4, stockSymbol: "VTL", stockShares: 4),
   Move(.bankWithdraw, player: 0, seq: 5, financeID: 1),
   Move(.proposeTrade, player: 0, seq: 6, to: 1,
        offer: TradeTransfer(cash: 10), request: TradeTransfer(tiles: [6])),
   Move(.acceptTrade, player: 1, seq: 7),
   Move(.endTurn, player: 0, seq: 8)
  ]
  var live = initial
  var replay = initial
  for move in moves {
   let before = StateDigest.hash(live)
   XCTAssertNil(VeilopolyGamePresentation.rejection(live, move: move))
   XCTAssertEqual(StateDigest.hash(live), before)
   live = try VeilopolyEngine.apply(live, VeilopolyEngine.context(live), move).get().0
   replay = try VeilopolyEngine.apply(replay, VeilopolyEngine.context(replay), move).get().0
   XCTAssertEqual(StateDigest.hash(live), StateDigest.hash(replay))
  }
  XCTAssertEqual(live.board[1].houses, 1)
  XCTAssertEqual(live.board[6].owner, 0)
  XCTAssertEqual(live.banking?.accounts[0].savings.count, 0)
  XCTAssertEqual(live.banking?.market?.portfolios[0].positions.first?.shares, 6)
  XCTAssertEqual(live.turn.player, 1)
 }


 func testEveryKnownEngineFailureHasUsefulRecoveryText() {
  let failures: [GameError] = [
   .noCash,.notOwner,.invalidTile,.setNotComplete,.buildUneven,
   .alreadyMortgaged,.alreadyOwned,.insufficientBankSupply,.invalidBid,
   .tradeMismatch,.financeTermsPending,.financePositionLocked,.financeOverdue,
   .stockTradingHalted,.insufficientShares,.stockNotFound,.wrongPhase,
   .notYourTurn,.gameFinished,.noJailCard,.inJail,.alreadyBankrupt,
   .noDebt,.invalidPayload,.invalidSequence,.invalidContext,.invalidState
  ]
  XCTAssertEqual(Set(failures.map(\.rawValue)).count,27)
  for error in failures {
   XCTAssertGreaterThan(VeilopolyGamePresentation.advice(error).count,12)
   XCTAssertFalse(VeilopolyGamePresentation.message(error).isEmpty)
  }
  XCTAssertTrue(VeilopolyGamePresentation.advice(.financeTermsPending).contains("尚未完成"))
  XCTAssertTrue(VeilopolyGamePresentation.advice(.invalidState).contains("保留本地存档"))
 }

 #if os(iOS) && canImport(SpriteKit)
 func testStockCashEffectsUseExistingBoardFeedbackPipeline() {
  let commands = CommandTranslator.translate([
   Effect(.stockBought, player: 2, amount: -186),
   Effect(.stockSold, player: 2, amount: 73),
   Effect(.stockTicked, amount: 1)
  ])
  XCTAssertEqual(commands.count, 2)
  if case .cashFloat(let player, let delta) = commands[0] {
   XCTAssertEqual(player, 2); XCTAssertEqual(delta, -186)
  } else { XCTFail("Trade must enter the existing cash effect pipeline") }
 }
 #endif
}
