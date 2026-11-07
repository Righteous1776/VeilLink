import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class DecisionReviewTests: XCTestCase {
 private func purchase() -> GameState {
  var game = GameFactory.make(seed: 20071, humanCount: 2)
  game.turn.phase = .tileResolve; game.turn.pendingPurchase = 1
  return game
 }
 private func auction() -> GameState {
  var game = GameFactory.make(seed: 20072, humanCount: 2)
  game.turn.phase = .auction
  game.auction = AuctionState(tile: 1, active: [0, 1])
  game.auction?.currentBid = 100; game.auction?.bidder = 1
  return game
 }
 private func trade() -> GameState {
  var game = GameFactory.make(seed: 20073, humanCount: 2)
  game.turn.phase = .trade
  game.board[1].owner = 0; game.board[3].owner = 1
  game.players[0].chanceJailCards = 1
  game.players[1].chestJailCards = 1
  game.trade = .init(from: 0, to: 1,
   offer: .init(cash: 50, tiles: [1], chanceCards: 1),
   request: .init(cash: 100, tiles: [3], chestCards: 1))
  return game
 }

 func testPurchaseUsesCurrentPriceCashAndActualReducerPreview() throws {
  let game = purchase(); let original = StateDigest.hash(game)
  let review = try XCTUnwrap(VeilopolyPurchaseReview(game: game, player: 0, tile: 1))
  XCTAssertEqual(review.name, game.board[1].name)
  XCTAssertEqual(review.price, game.board[1].price)
  XCTAssertEqual(review.cashAfterPurchase, game.players[0].cash - game.board[1].price)
  XCTAssertNil(review.rejection)
  let result = try VeilopolyEngine.apply(game, VeilopolyEngine.context(game),
   Move(.buyProperty, player: 0, seq: game.nextSeq, tile: 1)).get().0
  XCTAssertEqual(review.cashAfterPurchase, result.players[0].cash)
  XCTAssertEqual(StateDigest.hash(game), original)
 }

 func testInsufficientCashDoesNotInventANegativeAvailableBalance() throws {
  var game = purchase(); game.players[0].cash = game.board[1].price - 1
  let review = try XCTUnwrap(VeilopolyPurchaseReview(game: game, player: 0, tile: 1))
  XCTAssertNil(review.cashAfterPurchase)
  XCTAssertEqual(review.rejection, VeilopolyGamePresentation.message(.noCash))
 }

 func testVersionedCityPricesAndBailAreNeverHardcodedToClassicAmounts() throws {
  var game = VeilopolyCityLongEconomy.make(seed: 20074, humanCount: 2)
  game.turn.phase = .tileResolve; game.turn.pendingPurchase = 1
  let before = StateDigest.hash(game)
  let review = try XCTUnwrap(VeilopolyPurchaseReview(game: game, player: 0, tile: 1))
  XCTAssertEqual(review.price, 180)
  XCTAssertEqual(review.cashAfterPurchase, 7020)
  XCTAssertNil(review.rejection)
  XCTAssertEqual(VeilopolyCityLongEconomy.bail(game), 150)
  XCTAssertEqual(VeilopolyCityLongEconomy.bail(purchase()), 50)
  XCTAssertEqual(StateDigest.hash(game), before)
 }

 func testPurchaseOutOfPhaseUsesAuthoritativeRejection() throws {
  var game = purchase(); game.turn.phase = .manage; game.turn.pendingPurchase = nil
  let review = try XCTUnwrap(VeilopolyPurchaseReview(game: game, player: 0, tile: 1))
  XCTAssertNotNil(review.rejection)
 }

 func testInvalidPurchaseReferencesNeverIndexOutsideGame() {
  let game = purchase()
  XCTAssertNil(VeilopolyPurchaseReview(game: game, player: Int.max, tile: 1))
  XCTAssertNil(VeilopolyPurchaseReview(game: game, player: 0, tile: -1))
  XCTAssertNil(VeilopolyPurchaseReview(game: game, player: 0, tile: 4)) // Tax, not land.
 }

 func testAuctionSeparatesPositiveBidFromExplicitFold() throws {
  let game = auction(); let before = StateDigest.hash(game)
  let review = try XCTUnwrap(VeilopolyAuctionReview(game: game, player: 0))
  XCTAssertEqual(review.minimumBid, 101)
  XCTAssertEqual(review.leader, game.players[1].name)
  for draft in ["", "0", "-1", "100", "not-a-number", String(Int.max)] {
   XCTAssertNotNil(VeilopolyAuctionReview.rejection(game: game, player: 0, draft: draft))
  }
  XCTAssertNil(VeilopolyAuctionReview.rejection(game: game, player: 0, draft: "101"))
  // Rendering a quote never bids/folds, debits cash or consumes sequence/RNG.
  XCTAssertEqual(StateDigest.hash(game), before)
 }

 func testAuctionInvalidReferencesAndOverflowAreNotDisplayedAsValidQuotes() {
  var game = auction(); game.auction?.tile = Int.max
  XCTAssertNil(VeilopolyAuctionReview(game: game, player: 0))
  game = auction(); game.auction?.bidder = -1
  XCTAssertNil(VeilopolyAuctionReview(game: game, player: 0))
  game = auction(); game.auction?.currentBid = Int.max
  XCTAssertNil(VeilopolyAuctionReview(game: game, player: 0))
 }

 func testRecipientSeesGivingAndReceivingInOwnPerspective() throws {
  let game = trade()
  let review = try XCTUnwrap(VeilopolyTradeReview(game: game, viewer: 1))
  XCTAssertEqual(review.otherPlayer, game.players[0].name)
  XCTAssertEqual(review.giving.cash, 100)
  XCTAssertEqual(review.giving.properties, [game.board[3].name])
  XCTAssertEqual(review.giving.chestCards, 1)
  XCTAssertEqual(review.receiving.cash, 50)
  XCTAssertEqual(review.receiving.properties, [game.board[1].name])
  XCTAssertEqual(review.receiving.chanceCards, 1)
  let after = try VeilopolyEngine.apply(game, VeilopolyEngine.context(game),
   Move(.acceptTrade, player: 1, seq: game.nextSeq)).get().0
  XCTAssertEqual(review.cashAfterTrade, after.players[1].cash)
 }

 func testProposerGetsInversePerspectiveWithoutStateMutation() throws {
  let game = trade(); let before = StateDigest.hash(game)
  let from = try XCTUnwrap(VeilopolyTradeReview(game: game, viewer: 0))
  let to = try XCTUnwrap(VeilopolyTradeReview(game: game, viewer: 1))
  XCTAssertEqual(from.giving, to.receiving)
  XCTAssertEqual(from.receiving, to.giving)
  XCTAssertEqual(from.cashAfterTrade + to.cashAfterTrade,
                 game.players[0].cash + game.players[1].cash)
  XCTAssertEqual(StateDigest.hash(game), before)
 }

 func testInvalidTradeReferencesAndUninvolvedViewerAreSafe() {
  var game = trade()
  XCTAssertNil(VeilopolyTradeReview(game: game, viewer: 2))
  game.trade?.offer.tiles = [Int.max]
  XCTAssertNil(VeilopolyTradeReview(game: game, viewer: 1))
  game = trade(); game.trade?.from = -1
  XCTAssertNil(VeilopolyTradeReview(game: game, viewer: 1))
  game = trade(); game.trade?.offer.cash = Int.max
  XCTAssertNil(VeilopolyTradeReview(game: game, viewer: 1))
 }

 func testDecisionColumnsWrapAndRespectAccessibilityText() {
  for width in [-10.0, 0, 112, 231.99, .nan, .infinity] {
   XCTAssertEqual(VeilopolyDecisionLayout.columns(contentWidth: width, accessibilityText: false), 1)
  }
  for width in [232.0, 256, 359, 1000] {
   XCTAssertEqual(VeilopolyDecisionLayout.columns(contentWidth: width, accessibilityText: false), 2)
   XCTAssertEqual(VeilopolyDecisionLayout.columns(contentWidth: width, accessibilityText: true), 1)
  }
 }
}
