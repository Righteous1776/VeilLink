import XCTest
@testable import VeilopolyEngine

final class StartAuctionTests: XCTestCase {
 func testCasualWalkPastDoesNotChargeOrTransferOwnership() {
  var g = Fixture.game(.tileResolve)
  g.turn.pendingPurchase = 1
  let money = g.players[0].cash
  let initialSequence = g.nextSeq
  Fixture.step(&g, .skipPurchase, tile: 1)
  XCTAssertEqual(g.players[0].cash, money)
  XCTAssertNil(g.board[1].owner)
  XCTAssertNil(g.turn.pendingPurchase)
  XCTAssertNil(g.auction)
  XCTAssertEqual(g.turn.phase, .manage)
  XCTAssertEqual(g.nextSeq, initialSequence + 1)
  XCTAssertEqual(g.moveLog.last?.type, .skipPurchase)
 }
 func testWalkPastRejectsDifferentTileWithoutMutatingState() {
  var g = Fixture.game(.tileResolve)
  g.turn.pendingPurchase = 1
  let original = g
  Fixture.fails(g, Move(.skipPurchase, player: 0, seq: g.nextSeq, tile: 3), .invalidTile)
  XCTAssertEqual(g, original)
 }

 func testStartAuction() {
   var g = Fixture.game(.tileResolve)
   g.turn.pendingPurchase = 1
   Fixture.step(&g, .startAuction, tile: 1)
   XCTAssertEqual(g.turn.phase, .auction)
   XCTAssertEqual(g.auction?.active.count, 4)
 }
}
