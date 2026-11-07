import XCTest
@testable import VeilopolyEngine

enum Fixture {
 static func game(_ phase: Phase = .manage) -> GameState {
  var g = GameFactory.make(seed: 8241, humanCount: 0)
  g.turn.phase = phase
  return g
 }
 @discardableResult
 static func step(_ g: inout GameState, _ kind: MoveKind, player: Int = 0,
                  tile: Int? = nil, amount: Int? = nil, to: Int? = nil,
                  offer: TradeTransfer? = nil, request: TradeTransfer? = nil,
                  deck: DeckKind? = nil, file: StaticString = #filePath, line: UInt = #line) -> [Effect] {
  let move = Move(kind, player: player, seq: g.nextSeq, tile: tile, amount: amount,
                  to: to, offer: offer, request: request, deck: deck)
  switch VeilopolyEngine.apply(g, VeilopolyEngine.context(g), move) {
  case .success((let next, let effects)): g = next; return effects
  case .failure(let err): XCTFail("\(kind) failed: \(err)", file: file, line: line); return []
  }
 }
 static func fails(_ g: GameState, _ move: Move, _ expected: GameError,
                   file: StaticString = #filePath, line: UInt = #line) {
  switch VeilopolyEngine.apply(g, VeilopolyEngine.context(g), move) {
  case .success: XCTFail("Unexpected success", file: file, line: line)
  case .failure(let err): XCTAssertEqual(err, expected, file: file, line: line)
  }
 }
 static func ownedSet() -> GameState {
  var g = game()
  g.board[1].owner = 0; g.board[3].owner = 0
  return g
 }
}
