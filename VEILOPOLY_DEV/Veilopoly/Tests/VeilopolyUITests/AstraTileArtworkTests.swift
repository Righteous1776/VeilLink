import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class AstraTileArtworkTests: XCTestCase {
 func testEverySpecialTileHasGeneratedArtAndStreetsKeepLiveColor() {
  let game = GameFactory.make(seed: 73)
  for tile in game.board {
   if tile.kind == .street { XCTAssertNil(AstraTileArtwork.icon(for: tile)) }
   else {
    let icon = AstraTileArtwork.icon(for: tile)
    XCTAssertNotNil(icon, tile.name)
    XCTAssertTrue(AstraTileArtwork.icons.contains(icon ?? ""))
   }
  }
  XCTAssertNotEqual(AstraTileArtwork.icon(for: game.board[12]), AstraTileArtwork.icon(for: game.board[28]))
 }

 func testAllBundledArtIsRGBAAndExpectedResolution() throws {
  XCTAssertEqual(AstraTileArtwork.aliases.count, 11)
  for alias in AstraTileArtwork.aliases {
   let data = try Data(contentsOf: XCTUnwrap(AstraTileArtwork.resourceURL(alias)))
   let w = data[16..<20].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
   let h = data[20..<24].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
   XCTAssertEqual(w, alias == AstraTileArtwork.face ? 256 : 128)
   XCTAssertEqual(h, alias == AstraTileArtwork.face ? 384 : 128)
   XCTAssertEqual(data[25], 6)
  }
 }

 func testScreenOrientedLayoutStaysInsideAllFortyTiles() {
  for spec in KimiK2TileMap.tiles {
   let layout = AstraTileArtwork.layout(spec)
   for world in [(0.0, layout.priceY), (0.0, layout.iconY), (22.0, layout.buildingY)] {
    let local = layout.local(world.0, world.1)
    let x = local.x * cos(spec.rotationRadians) - local.y * sin(spec.rotationRadians)
    let y = local.x * sin(spec.rotationRadians) + local.y * cos(spec.rotationRadians)
    XCTAssertEqual(x, world.0, accuracy: 0.001)
    XCTAssertEqual(y, world.1, accuracy: 0.001)
   }
   XCTAssertGreaterThan(layout.priceY - 5, -layout.height / 2)
   XCTAssertLessThan(layout.buildingY + 10.5, layout.height / 2 - 11)
   XCTAssertGreaterThan(layout.nameY(special: false) - 10, layout.priceY + 5)
   XCTAssertLessThan(layout.labelWidth, layout.width)
  }
 }
}
