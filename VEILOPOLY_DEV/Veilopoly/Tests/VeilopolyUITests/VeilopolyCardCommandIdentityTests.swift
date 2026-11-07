#if os(iOS) && canImport(SwiftUI) && canImport(SpriteKit)
import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

@MainActor
final class VeilopolyCardCommandIdentityTests: XCTestCase {
 func testDrawnCardCommandKeepsActualEngineIDDeckAndText() {
  let card = SampleCards.all[20]
  let event = Effect(.cardDrawn, player:0, tile:17, amount:card.id,
                     text:card.text, deck:card.deck)
  let commands=CommandTranslator.translate([event])
  XCTAssertEqual(commands.count,1)
  guard case .cardShow(let deck,let id,let text) = commands[0] else {
   return XCTFail("Expected typed card command")
  }
  XCTAssertEqual(deck,.chest)
  XCTAssertEqual(id,20)
  XCTAssertEqual(text,card.text)
  XCTAssertEqual(VeilopolyCardEditorial.presentation(id:20,deck:deck,among:SampleCards.all)?.title,
                 "生日的来宾")
 }
 func testNoCardIDNeverInventsEditorialEvent() {
  let commands = CommandTranslator.translate([
   Effect(.cardDrawn,player:0,text:"自定义卡",deck:.chance)
  ])
  guard case .cardShow(_,let id,let text) = commands[0] else {
   return XCTFail("Expected fallback card command")
  }
  XCTAssertNil(id)
  XCTAssertEqual(text,"自定义卡")
 }
}
#endif
