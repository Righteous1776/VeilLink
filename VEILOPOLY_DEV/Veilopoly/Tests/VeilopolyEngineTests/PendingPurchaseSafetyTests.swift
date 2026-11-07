import XCTest
@testable import VeilopolyEngine

final class PendingPurchaseSafetyTests: XCTestCase {
 func testMalformedPendingPurchaseReturnsFailureInsteadOfCrashing() {
  for index in [-1, 40, Int.min, Int.max] {
   assertInvalidReference(index, kind: .buyProperty)
  }
 }

 func testStartAuctionCannotPropagateAnInvalidPurchaseReference() {
  for index in [-1, 40, Int.min, Int.max] {
   assertInvalidReference(index, kind: .startAuction)
  }
 }

 func testExistingMalformedAuctionTileCannotCrashSettlement() {
  for index in [-1, 40, Int.min, Int.max] {
   var state = GameFactory.make(seed: 8205, humanCount: 2)
   state.turn.phase = .auction
   var auction = AuctionState(tile: index, active: [0, 1])
   auction.currentBid = 100
   auction.bidder = 0
   auction.turn = 1
   state.auction = auction
   let before = StateDigest.hash(state)
   let result = VeilopolyEngine.apply(state, VeilopolyEngine.context(state),
    Move(.bid, player: 1, seq: state.nextSeq)) // Fold would otherwise settle board[index].
   guard case .failure(.invalidTile) = result else {
    XCTFail("Malformed existing auction must fail before settlement"); continue
   }
   XCTAssertEqual(StateDigest.hash(state), before)
  }
 }

 func testValidPurchaseAndAuctionStillReplayWithoutConsumingRandomness() throws {
  for kind in [MoveKind.buyProperty, .startAuction] {
   var state = GameFactory.make(seed: 8201, humanCount: 1)
   state.turn.phase = .tileResolve
   state.turn.pendingPurchase = 1
   let move = Move(kind, player: 0, seq: state.nextSeq, tile: 1)
   let next = try VeilopolyEngine.apply(state, VeilopolyEngine.context(state), move).get().0
   let replay = try VeilopolyEngine.apply(state, VeilopolyEngine.context(state), move).get().0
   XCTAssertEqual(StateDigest.hash(next), StateDigest.hash(replay))
   XCTAssertEqual(next.rngCounter, state.rngCounter)
   XCTAssertEqual(next.nextSeq, state.nextSeq + 1)
   if kind == .buyProperty {
    XCTAssertEqual(next.board[1].owner, 0)
    XCTAssertEqual(next.players[0].cash, state.players[0].cash - state.board[1].price)
   } else {
    XCTAssertEqual(next.auction?.tile, 1)
    XCTAssertEqual(next.players[0].cash, state.players[0].cash)
   }
  }
 }

 private func assertInvalidReference(_ index: Int, kind: MoveKind,
                                     file: StaticString = #filePath, line: UInt = #line) {
  var state = GameFactory.make(seed: 8202, humanCount: 1)
  state.turn.phase = .tileResolve
  state.turn.pendingPurchase = index
  let before = StateDigest.hash(state)
  let result = VeilopolyEngine.apply(state, VeilopolyEngine.context(state),
   Move(kind, player: 0, seq: state.nextSeq, tile: index))
  guard case .failure(.invalidTile) = result else {
   return XCTFail("Invalid pending purchase index \(index) must fail atomically", file: file, line: line)
  }
  XCTAssertEqual(StateDigest.hash(state), before, file: file, line: line)
 }
}
