import XCTest
@testable import VeilopolyEngine

final class BoardEconomyTests: XCTestCase {
 func testBoardStockAndDeckGeometry() {
  let g = GameFactory.make(seed: 0)
  XCTAssertEqual(g.board.count, 40)
  XCTAssertEqual(g.board.filter { $0.kind == .street }.count, 22)
  XCTAssertEqual(g.board.filter { $0.kind == .railroad }.count, 4)
  XCTAssertEqual(g.board.filter { $0.kind == .utility }.count, 2)
  XCTAssertEqual(Set(g.board.compactMap(\.color)), Set(ColorGroup.allCases))
  XCTAssertEqual(g.chanceDeck.order.count, 16)
  XCTAssertEqual(g.chestDeck.order.count, 16)
  XCTAssertEqual(g.bank.houses, 32)
  XCTAssertEqual(g.bank.hotels, 12)
  XCTAssertEqual(g.players.map(\.cash), [1500,1500,1500,1500])
 }
 func testEvenBuildingHotelStockAndHalfPriceSale() {
  var g = Fixture.ownedSet()
  g.board[1].houses = 4; g.board[3].houses = 4
  g.bank.houses = 24
  Fixture.step(&g, .buildHouse, tile: 1)
  XCTAssertTrue(g.board[1].hotel)
  XCTAssertEqual(g.bank.houses, 28)
  XCTAssertEqual(g.bank.hotels, 11)
  Fixture.step(&g, .sellHouse, tile: 1)
  XCTAssertFalse(g.board[1].hotel)
  XCTAssertEqual(g.board[1].houses, 4)
  XCTAssertEqual(g.bank.houses, 24)
  XCTAssertEqual(g.bank.hotels, 12)
 }
 func testBankDebtRunsMortgageSaleThenPendingBankruptcy() {
  var g = Fixture.ownedSet()
  g.players[0].cash = 0
  g.board[1].houses = 1; g.bank.houses = 31
  g.players[0].position = 4; g.turn.phase = .tileResolve
  let effects = Fixture.step(&g, .resolveTile)
  XCTAssertTrue(effects.contains(where:{ $0.kind == .soldBuilding }))
  XCTAssertTrue(effects.contains(where:{ $0.kind == .mortgaged }))
  XCTAssertEqual(g.turn.phase, .debt)
  XCTAssertEqual(g.pendingDebt?.amount, 200)
  Fixture.step(&g, .declareBankruptcy)
  XCTAssertNil(g.pendingDebt)
  XCTAssertTrue(g.players[0].bankrupt)
  XCTAssertNil(g.board[1].owner)
 }
 func testIllegalMoveAndInvalidContextPreserveBytes() {
  let g = Fixture.game(.roll)
  var ctx = VeilopolyEngine.context(g)
  ctx.phase = .manage
  XCTAssertEqual(VeilopolyEngine.apply(g,ctx,Move(.rollDice,player:0,seq:0)).failureValue,.invalidContext)
  XCTAssertEqual(StateDigest.hash(g),StateDigest.hash(GameFactory.make(seed:8241,humanCount:0)))
 }
}
private extension Result {
 var failureValue: Failure? { if case .failure(let error) = self { return error }; return nil }
}
