import XCTest
@testable import VeilopolyUI

final class AstraDetailArtworkTests: XCTestCase {
 func testSixBundledSpritesHaveExactSizeAndRGBA() throws {
  XCTAssertEqual(AstraDetailArtwork.assets.count, 6)
  XCTAssertEqual(AstraDetailArtwork.assets.reduce(0) { $0 + $1.bytes }, 119511)
  for asset in AstraDetailArtwork.assets {
   let data = try Data(contentsOf: XCTUnwrap(AstraDetailArtwork.resourceURL(asset.alias)))
   XCTAssertEqual(data.count, asset.bytes, asset.alias)
   XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
   let width = data[16..<20].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
   let height = data[20..<24].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
   XCTAssertEqual(width, 128); XCTAssertEqual(height, 128)
   XCTAssertEqual(data[25], 6) // RGBA PNG, retaining transparent margins.
  }
 }

 func testPlayerIdentityAndFallbackRemainConsistentWithExistingTokens() {
  let legacy = ["pawnBlue", "carRed", "shipGreen", "planeYellow"]
  for player in 0..<4 {
   let candidates = AstraDetailArtwork.tokenCandidates(for: player)
   XCTAssertEqual(candidates.count, 3)
   XCTAssertEqual(candidates[0], AstraDetailArtwork.tokenAliases[player])
   XCTAssertEqual(candidates[1], KimiVisualAssetNames.tokenCandidate(for: player))
   XCTAssertEqual(candidates[2], legacy[player])
  }
  XCTAssertEqual(AstraDetailArtwork.tokenCandidates(for: -1), [])
  XCTAssertEqual(AstraDetailArtwork.tokenCandidates(for: 4), [])
  let aliases = Set(AstraDetailArtwork.assets.map(\.alias))
  XCTAssertEqual(aliases.count, 6)
  XCTAssertTrue(aliases.isDisjoint(with: Set(AstraB01AssetNames.imported)))
 }
}
