import XCTest
@testable import VeilopolyUI

final class AstraCenterCityArtworkTests: XCTestCase {
 func testDecorativeInlayCannotOverlapAnyPlayableTile() {
  let half = AstraCenterCityArtwork.displaySize / 2
  let x0 = AstraCenterCityArtwork.centerX - half
  let x1 = AstraCenterCityArtwork.centerX + half
  let y0 = AstraCenterCityArtwork.centerY - half
  let y1 = AstraCenterCityArtwork.centerY + half
  for tile in KimiK2TileMap.tiles {
   let quarterTurn = abs(tile.rotationDegrees) == 90
   let w = (quarterTurn ? tile.displayHeight : tile.displayWidth) / 2
   let h = (quarterTurn ? tile.displayWidth : tile.displayHeight) / 2
   let overlaps = x0 < tile.centerX + w && x1 > tile.centerX - w &&
                  y0 < tile.centerY + h && y1 > tile.centerY - h
   XCTAssertFalse(overlaps, "Decorative art overlaps playable tile \(tile.index)")
  }
 }

 func testRuntimePNGSizeAndRGBAContract() throws {
  let url = try XCTUnwrap(AstraCenterCityArtwork.resourceURL)
  let data = try Data(contentsOf: url)
  XCTAssertEqual(data.count, AstraCenterCityArtwork.byteCount)
  XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
  func uint32(_ offset: Int) -> UInt32 {
   data[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
  }
  XCTAssertEqual(uint32(16), UInt32(AstraCenterCityArtwork.pixelSize))
  XCTAssertEqual(uint32(20), UInt32(AstraCenterCityArtwork.pixelSize))
  XCTAssertEqual(data[25], 6) // PNG RGBA; preserve transparent margins.
 }
}
