import Foundation
import XCTest
@testable import VeilopolyEngine

final class CityTreasuryClaimTests: XCTestCase {
 private func apply(_ g: inout GameState, _ type: MoveKind) throws -> [Effect] {
  let (next, effects) = try VeilopolyEngine.apply(
   g, VeilopolyEngine.context(g),
   Move(type, player: g.turn.player, seq: g.nextSeq)).get()
  g = next
  return effects
 }
 private func conserved(_ g: GameState) -> Bool {
  (g.banking?.reserveCash ?? -1) + g.players.reduce(0) { $0 + $1.cash } ==
   VeilopolyCityLongEconomy.totalMoneySupply
 }
 func testEmptyBankDoesNotDeadlockPassingStartAndClaimsAreNotMinted() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 98121)
  g.players[0].cash += 159_900
  g.banking?.reserveCash = 100
  g.players[0].position = 38
  g.turn.phase = .moveAnim; g.turn.pendingSteps = 4
  let fx = try apply(&g, .applyMovement)
  XCTAssertEqual(g.players[0].position, 2)
  XCTAssertEqual(g.turn.phase, .tileResolve)
  XCTAssertEqual(g.banking?.reserveCash, 0)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.amount, 1_000)
  XCTAssertTrue(fx.contains { $0.kind == .passedGo && $0.amount == 100 })
  XCTAssertTrue(fx.contains { $0.text == "bankClaimIssued:1000" })
  XCTAssertTrue(conserved(g))
 }

 func testFutureTaxAutomaticallySettlesOldestClaimWithoutMinting() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 98122)
  g.players[0].cash += 159_900; g.banking?.reserveCash = 100
  g.players[0].position = 38; g.turn.phase = .moveAnim; g.turn.pendingSteps = 4
  _ = try apply(&g, .applyMovement)
  g.players[0].position = 4; g.turn.phase = .tileResolve
  let totalBefore = g.players.reduce(0) { $0 + $1.cash }
  let fx = try apply(&g, .resolveTile)
  XCTAssertEqual(g.banking?.reserveCash, 0)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.amount, 400)
  XCTAssertEqual(g.players.reduce(0) { $0 + $1.cash }, totalBefore)
  XCTAssertTrue(fx.contains { $0.text == "bankClaimSettlement" && $0.amount == 600 })
  XCTAssertTrue(conserved(g))
 }

 func testFreeHouseFallbackMakesClaimWhenBankHasNoCash() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 98123)
  g.players[0].cash += 160_000; g.banking?.reserveCash = 0
  g.players[0].position = 7; g.turn.phase = .tileResolve
  g.chanceDeck = DeckState(order: [13])
  let fx = try apply(&g, .resolveTile)
  XCTAssertEqual(g.players[0].cash, 167_200)
  XCTAssertEqual(g.banking?.queuedClaims?.first?.amount, 800)
  XCTAssertTrue(fx.contains { $0.text == "freeHouseFallback" && $0.amount == 0 })
  XCTAssertTrue(conserved(g))
 }

 func testClaimPreservesOrderAndExactCodableChecksum() throws {
  var g = VeilopolyCityLongEconomy.make(seed: 98124)
  g.banking?.queuedClaims = [
   .init(player: 1, amount: 100, source: "startSalary"),
   .init(player: 0, amount: 500, source: "eventCash")
  ]
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let restored = try JSONDecoder().decode(GameState.self, from: encoder.encode(g))
  XCTAssertEqual(restored, g)
  XCTAssertEqual(StateDigest.hash(restored), StateDigest.hash(g))
 }
}
