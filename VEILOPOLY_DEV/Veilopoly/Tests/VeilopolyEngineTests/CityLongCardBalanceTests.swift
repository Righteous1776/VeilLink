import Foundation
import XCTest
@testable import VeilopolyEngine

/// Every event amount and event-deck side effect must be reproducible,
/// and must not silently migrate legacy saved-game rules.
final class CityLongCardBalanceTests: XCTestCase {
 private func draw(_ game: inout GameState, on tile: Int, deckOrder: [Int]) throws -> [Effect] {
  game.players[0].position = tile
  game.turn.phase = .tileResolve
  if tile == 7 {
   game.chanceDeck = DeckState(order: deckOrder)
  } else {
   game.chestDeck = DeckState(order: deckOrder)
  }
  let move = Move(.resolveTile, player: 0, seq: game.nextSeq)
  let (next, effects) = try VeilopolyEngine.apply(game, VeilopolyEngine.context(game), move).get()
  game = next
  return effects
 }

 func testV3HasExactlyTwoDecksAnd32StoryCardsIncludingOpportunityTheme() throws {
  let cards = VeilopolyCityLongCards.all
  let blueprints = VeilopolyCityLongCards.blueprints
  XCTAssertEqual(cards.count, 32)
  XCTAssertEqual(blueprints.count, 32)
  XCTAssertEqual(cards.filter { $0.deck == .chance }.count, 16)
  XCTAssertEqual(cards.filter { $0.deck == .chest }.count, 16)
  XCTAssertEqual(cards.map(\.id), Array(0..<32))
  XCTAssertGreaterThanOrEqual(blueprints.filter { $0.category == "机遇" }.count, 4)
  XCTAssertEqual(Set(blueprints.map { "\($0.deck.rawValue)-\($0.id)" }).count, 32)
  for blueprint in blueprints {
   let card = blueprint.canonical
   XCTAssertFalse(blueprint.title.isEmpty)
   XCTAssertGreaterThan(blueprint.story.count, 8)
   XCTAssertGreaterThan(blueprint.ruling.count, 7)
   XCTAssertEqual(VeilopolyCardEditorial.presentation(for: card),
                  blueprint.editorial)
   for effect in blueprint.effects where effect.kind == .cash {
    let amount = try XCTUnwrap(effect.amount)
    XCTAssertLessThanOrEqual(abs(amount), 800)
    XCTAssertTrue(blueprint.ruling.contains("¥\(abs(amount))"),
                  "Card id \(blueprint.id) text and award must match")
   }
   for effect in blueprint.effects where effect.kind == .repair {
    XCTAssertTrue(blueprint.ruling.contains("¥\(try XCTUnwrap(effect.perHouse))"))
    XCTAssertTrue(blueprint.ruling.contains("¥\(try XCTUnwrap(effect.perHotel))"))
   }
  }
 }

 func testBothDecksInjectBoundedCashInsteadOfLethalOrUnboundedSwings() {
  func cashSum(_ kind: DeckKind) -> Int {
   VeilopolyCityLongCards.all.filter { $0.deck == kind }
    .flatMap(\.effects)
    .filter { $0.kind == .cash && $0.target == .bank }
    .reduce(0) { $0 + ($1.amount ?? 0) }
  }
  // These are nominal bank transfers for one 16-card cycle; travel, rents,
  // personal trading, birthday transfers, repairs and GO are excluded.
  XCTAssertEqual(cashSum(.chance), 1000)
  XCTAssertEqual(cashSum(.chest), 2210)
  XCTAssertEqual(VeilopolyCityLongCards.all.filter { $0.effects.contains { $0.kind == .goToJail } }.count, 2)
  XCTAssertEqual(VeilopolyCityLongCards.all.filter { $0.effects.contains { $0.kind == .jailCard } }.count, 2)
 }

 func testChanceCardUsesPrintedCashExactlyWithoutHiddenThreeTimesMultiplier() throws {
  var game = VeilopolyCityLongEconomy.make(seed: 91201)
  let cash = game.players[0].cash
  let effects = try draw(&game, on: 7, deckOrder: [5])
  XCTAssertEqual(game.players[0].cash, cash + 650)
  XCTAssertTrue(effects.contains { $0.kind == .cashChanged && $0.amount == 650 })
  XCTAssertEqual(game.pendingCard?.id, 5)
  let debit = try draw(&game, on: 7, deckOrder: [14])
  XCTAssertEqual(game.players[0].cash, cash + 150)
  XCTAssertTrue(debit.contains { $0.kind == .cashChanged && $0.amount == -500 })
 }

 func testFatePlayerTransfersConserveTotalCash() throws {
  var game = VeilopolyCityLongEconomy.make(seed: 91202)
  let cashBefore = game.players.reduce(0) { $0 + $1.cash }
  _ = try draw(&game, on: 2, deckOrder: [20])
  XCTAssertEqual(game.players[0].cash, 7500)
  XCTAssertTrue(game.players.dropFirst().allSatisfy { $0.cash == 7100 })
  XCTAssertEqual(game.players.reduce(0) { $0 + $1.cash }, cashBefore)
 }

 func testDuplicateJailCardBecomesOneTimeCashButCannotAccumulateCards() throws {
  var game = VeilopolyCityLongEconomy.make(seed: 91203)
  _ = try draw(&game, on: 7, deckOrder: [6])
  XCTAssertEqual(game.players[0].chanceJailCards, 1)
  let cash = game.players[0].cash
  let effects = try draw(&game, on: 7, deckOrder: [6])
  XCTAssertEqual(game.players[0].chanceJailCards, 1)
  XCTAssertEqual(game.players[0].cash, cash + 250)
  XCTAssertTrue(effects.contains { $0.text == "duplicateJailCardExchange" && $0.amount == 250 })
 }

 func testChanceAndFateCycleShuffleDoNotTouchDiceRNGAndReplayDeterministically() {
  let game = VeilopolyCityLongEconomy.make(seed: 91204)
  var deck = DeckState(order: Array(0..<16), cursor: 16)
  var replay = deck
  let originalDiceCounter = game.rngCounter
  VeilopolyCityLongCards.reshuffleOnCycle(&deck, kind: .chance, seed: game.seed)
  VeilopolyCityLongCards.reshuffleOnCycle(&replay, kind: .chance, seed: game.seed)
  XCTAssertEqual(deck, replay)
  XCTAssertEqual(Set(deck.order), Set(0..<16))
  XCTAssertEqual(deck.cursor, 16)
  XCTAssertEqual(game.rngCounter, originalDiceCounter)
  var midCycle = deck
  midCycle.cursor = 17
  VeilopolyCityLongCards.reshuffleOnCycle(&midCycle, kind: .chance, seed: game.seed)
  XCTAssertEqual(midCycle.order, deck.order)
 }

 func testGraduatedRentCapProtectsEarlyGameButKeepsLateConsequences() {
  var game = VeilopolyCityLongEconomy.make(seed: 91205)
  XCTAssertEqual(VeilopolyCityLongEconomy.rentCeiling(game), 900)
  XCTAssertEqual(VeilopolyCityLongEconomy.chargedRent(game, base: 8000, tileKind: .street), 900)
  XCTAssertEqual(VeilopolyCityLongEconomy.chargedRent(game, base: 180, tileKind: .railroad), 540)
  game.banking?.completedTurns = 20
  XCTAssertEqual(VeilopolyCityLongEconomy.rentCeiling(game), 2500)
  XCTAssertEqual(VeilopolyCityLongEconomy.chargedRent(game, base: 8000, tileKind: .street), 2500)
  game.banking?.completedTurns = 70
  XCTAssertEqual(VeilopolyCityLongEconomy.rentCeiling(game), 6500)
  let classic = GameFactory.make(seed: 91205)
  XCTAssertEqual(VeilopolyCityLongEconomy.chargedRent(classic, base: 8000, tileKind: .street), 8000)
 }

 func testOldSavesAndCardIdentityRemainIndependent() throws {
  let old = GameFactory.make(seed: 91206)
  let city = VeilopolyCityLongEconomy.make(seed: 91206)
  XCTAssertEqual(old.cards, SampleCards.all)
  XCTAssertNotEqual(old.cards, city.cards)
  XCTAssertEqual(city.cards, VeilopolyCityLongCards.all)
  XCTAssertNotNil(VeilopolyCardEditorial.presentation(for: old.cards[5]))
  XCTAssertNotNil(VeilopolyCardEditorial.presentation(for: city.cards[5]))
  var corrupt = city.cards[5]
  corrupt.effects[0].amount = 123
  XCTAssertNil(VeilopolyCardEditorial.presentation(for: corrupt))
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let restored = try JSONDecoder().decode(GameState.self, from: encoder.encode(city))
  XCTAssertEqual(city, restored)
  XCTAssertEqual(StateDigest.hash(city), StateDigest.hash(restored))
 }
}
