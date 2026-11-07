import XCTest
@testable import VeilopolyEngine

final class CardEditorialTests: XCTestCase {
 func testAll32RealProvisionalCardsHaveUniqueCopyAndMatchingDecks() throws {
  let samples = SampleCards.all
  let entries = VeilopolyCardEditorial.entries
  XCTAssertEqual(samples.count, 32)
  XCTAssertEqual(entries.count, 32)
  XCTAssertEqual(Set(entries.map(\.stableID)).count, 32)
  XCTAssertEqual(Set(entries.map(\.id)).count, 32)
  XCTAssertEqual(entries.filter { $0.deck == .chance }.count, 16)
  XCTAssertEqual(entries.filter { $0.deck == .chest }.count, 16)
  for (index, card) in samples.enumerated() {
   let copy = try XCTUnwrap(VeilopolyCardEditorial.presentation(for: card))
   XCTAssertEqual(copy.id, card.id)
   XCTAssertEqual(copy.deck, card.deck)
   XCTAssertEqual(copy.id, index)
   XCTAssertGreaterThan(copy.title.count, 2)
   XCTAssertGreaterThan(copy.story.count, 16)
   XCTAssertGreaterThan(copy.ruling.count, 5)
   XCTAssertLessThan(copy.title.count, 16)
   XCTAssertEqual(copy.stableID, String(format:"VL-TEXT-%@-%03d",index < 16 ? "CH":"FT",index))
   XCTAssertEqual(VeilopolyCardEditorial.presentation(id:card.id,deck:card.deck,among:samples),copy)
  }
 }
 func testCopyIsRejectedIfGameplayEffectsOrOriginalCardHaveChanged() {
  var changed = SampleCards.all[5]
  changed.effects = [CardEffect(kind:.cash,amount:500,target:.bank)]
  XCTAssertNil(VeilopolyCardEditorial.presentation(for:changed))
  var renamed = SampleCards.all[5]
  renamed.text = "自定义银行红利卡"
  XCTAssertNil(VeilopolyCardEditorial.presentation(for:renamed))
  let missing = VeilopolyCardEditorial.presentation(id:999,deck:.chance,among:SampleCards.all)
  XCTAssertNil(missing)
  XCTAssertNil(VeilopolyCardEditorial.presentation(id:5,deck:.chest,among:SampleCards.all))
 }
 func testImportantExactRulingsStayConsistentWithCanonicalEffects() throws {
  let sample=SampleCards.all
  let nearest=try XCTUnwrap(VeilopolyCardEditorial.presentation(for:sample[3]))
  XCTAssertTrue(nearest.ruling.contains("公共事业"))
  XCTAssertTrue(nearest.ruling.contains("2倍"))
  let rail=try XCTUnwrap(VeilopolyCardEditorial.presentation(for:sample[4]))
  XCTAssertTrue(rail.ruling.contains("铁路"))
  XCTAssertTrue(rail.ruling.contains("2倍"))
  let repairs=try XCTUnwrap(VeilopolyCardEditorial.presentation(for:sample[9]))
  XCTAssertTrue(repairs.ruling.contains("¥25"))
  XCTAssertTrue(repairs.ruling.contains("¥100"))
  let birthday=try XCTUnwrap(VeilopolyCardEditorial.presentation(for:sample[20]))
  XCTAssertTrue(birthday.ruling.contains("其他玩家"))
  XCTAssertTrue(birthday.ruling.contains("¥50"))
  XCTAssertEqual(VeilopolyCardEditorial.deckName(.chance),"机会")
  XCTAssertEqual(VeilopolyCardEditorial.deckName(.chest),"命运")
 }
 func testEditorialDoesNotChangeCanonicalCardsOrSeededGameReplay() {
  let fixture = SampleCards.all
  let original=GameFactory.make(seed:20261107)
  for c in fixture { _ = VeilopolyCardEditorial.presentation(for:c) }
  let after=GameFactory.make(seed:20261107)
  XCTAssertEqual(original,after)
  XCTAssertEqual(after.cards,fixture)
  XCTAssertEqual(original.chanceDeck,after.chanceDeck)
  XCTAssertEqual(original.chestDeck,after.chestDeck)
  XCTAssertEqual(original.rngCounter,after.rngCounter)
 }
}
