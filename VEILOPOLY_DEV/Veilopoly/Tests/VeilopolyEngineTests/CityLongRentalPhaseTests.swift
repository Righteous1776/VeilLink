import XCTest
@testable import VeilopolyEngine

final class CityLongRentalPhaseTests: XCTestCase {
 func testLateDevelopedPropertyChargesEarlyCapNotInstantBankruptcy() throws {
  var g = VeilopolyCityLongEconomy.makeV4(seed: 91301)
  g.board[39].owner = 1
  g.board[39].hotel = true
  g.players[0].position = 39
  g.turn.phase = .tileResolve
  g.turn.lastRoll = [3, 4]
  let before = g.players.map(\.cash)
  let (next, fx) = try VeilopolyEngine.apply(
   g, VeilopolyEngine.context(g), Move(.resolveTile, player: 0, seq: 0)
  ).get()
  XCTAssertEqual(next.players[0].cash, before[0] - 900)
  XCTAssertEqual(next.players[1].cash, before[1] + 900)
  XCTAssertNil(next.pendingDebt)
  XCTAssertEqual(next.turn.phase, .manage)
  XCTAssertTrue(fx.contains { $0.kind == .rentPaid && $0.amount == 900 })
 }
 func testLateRentBecomesMeaningfulWithoutRetroactivePriceMutation() throws {
  var g = VeilopolyCityLongEconomy.makeV4(seed: 91302)
  g.board[39].owner = 1; g.board[39].hotel = true
  g.players[0].position = 39
  g.turn.phase = .tileResolve
  g.turn.lastRoll = [3, 4]
  g.banking?.completedTurns = 70
  let (next, fx) = try VeilopolyEngine.apply(
   g, VeilopolyEngine.context(g), Move(.resolveTile, player: 0, seq: 0)
  ).get()
  XCTAssertEqual(next.players[0].cash, 3200)
  XCTAssertTrue(fx.contains { $0.kind == .rentPaid && $0.amount == 4000 })
 }
}
