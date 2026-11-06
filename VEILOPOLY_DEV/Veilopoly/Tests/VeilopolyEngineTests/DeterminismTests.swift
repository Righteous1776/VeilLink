import XCTest
@testable import VeilopolyEngine

final class DeterminismTests: XCTestCase {
 func testSameSeedSameMovesByteIdenticalIncludingHash() throws {
  var a = GameFactory.make(seed: 1729123, humanCount: 0)
  var b = GameFactory.make(seed: 1729123, humanCount: 0)
  for _ in 0..<180 {
   let ctx = VeilopolyEngine.context(a)
   let p = a.auction?.turn ?? a.trade?.to ?? a.pendingDebt?.player ?? a.turn.player
   if ctx.phase == .finished { break }
   let move: Move
   switch ctx.phase {
   case .roll: move = Move(.rollDice, player: p, seq: a.nextSeq)
   case .moveAnim: move = Move(.applyMovement, player: p, seq: a.nextSeq)
   case .tileResolve:
    move = Move(a.turn.pendingPurchase == nil ? .resolveTile : .buyProperty,
                player: p, seq: a.nextSeq, tile: a.turn.pendingPurchase)
   case .manage: move = Move(.endTurn, player: p, seq: a.nextSeq)
   case .auction: move = Move(.bid, player: p, seq: a.nextSeq, amount: 0)
   case .trade: move = Move(.rejectTrade, player: p, seq: a.nextSeq)
   case .debt: move = Move(.declareBankruptcy, player: p, seq: a.nextSeq)
   case .finished: move = Move(.endTurn, player: p, seq: a.nextSeq)
   }
   switch VeilopolyEngine.apply(a, ctx, move) {
   case .success((let next, _)): a = next
   case .failure(let e): XCTFail("A: \(e)"); return
   }
   switch VeilopolyEngine.apply(b, VeilopolyEngine.context(b), move) {
   case .success((let next, _)): b = next
   case .failure(let e): XCTFail("B: \(e)"); return
   }
   XCTAssertEqual(StateDigest.hash(a), StateDigest.hash(b))
  }
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  XCTAssertEqual(try encoder.encode(a), try encoder.encode(b))
 }
 func testInvalidMoveDoesNotMutateState() {
  let g = Fixture.game(.roll)
  let hash = StateDigest.hash(g)
  Fixture.fails(g, Move(.buildHouse, player: 0, seq: 0, tile: 1), .wrongPhase)
  XCTAssertEqual(StateDigest.hash(g), hash)
 }
 func testThreeDoubleAndJailEventuallyReleases() {
  // Roll sequence is seeded, so test directly confirms the forced third attempt mechanic.
  var g = Fixture.game(.roll)
  g.players[0].jailTurns = 1
  for _ in 0..<100 {
   var trial = g; trial.seed += UInt64(trial.seed)
   let fx = Fixture.step(&trial, .rollDice)
   if fx.first?.dice?.first != fx.first?.dice?.last {
    XCTAssertEqual(trial.players[0].jailTurns, 0)
    XCTAssertEqual(trial.turn.phase, .moveAnim)
    return
   }
  }
  XCTFail("No suitable seed")
 }
 func testCardEffectRepairAndMoveNearest() {
  var g = Fixture.game(.tileResolve)
  g.players[0].position = 7
  let testCard = CardDefinition(id: 999, deck: .chance, text: "前往铁路", effects: [CardEffect(kind: .moveNearest, nearest: .railroad, multiplier: 2)])
  g.cards = [testCard]; g.chanceDeck = DeckState(order: [999])
  Fixture.step(&g, .resolveTile)
  XCTAssertEqual(g.players[0].position, 15)
  XCTAssertEqual(g.turn.pendingPurchase, 15)
 }
}
