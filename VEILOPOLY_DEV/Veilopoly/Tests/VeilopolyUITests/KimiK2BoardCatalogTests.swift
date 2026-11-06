import XCTest
@testable import VeilopolyUI

final class KimiK2BoardCatalogTests: XCTestCase {
 func testFifteenAssetsHaveStableUniqueIDsHashesAndDoNotCollideWithAstra() {
  let all=KimiK2BoardCatalog.assets
  XCTAssertEqual(all.count, 15)
  XCTAssertEqual(all.reduce(0) { $0 + $1.byteCount }, 519024)
  XCTAssertEqual(Set(all.map(\.id)).count, 15)
  XCTAssertEqual(Set(all.map(\.alias)).count, 15)
  XCTAssertEqual(Set(all.map(\.sourceAlias)).count, 15)
  XCTAssertTrue(all.allSatisfy { $0.id.hasPrefix("VL-K2-ART-") && $0.alias.hasPrefix("kimiK2") })
  XCTAssertTrue(all.allSatisfy { $0.sha256.count == 64 && $0.expectedGitBlobSHA1.count == 40 })
  XCTAssertTrue(Set(all.map(\.alias)).isDisjoint(with: Set(AstraB01AssetNames.imported)))
  XCTAssertFalse(KimiK2BoardCatalog.runtimeEnabled)
 }
 func testDarkAndLightCandidateMappingsHaveNoRuntimeActivation() {
  XCTAssertEqual(KimiK2BoardCatalog.tileAtlas(light: false)?.sourceAlias, "tilesDark")
  XCTAssertEqual(KimiK2BoardCatalog.tileAtlas(light: true)?.sourceAlias, "tilesLight")
  XCTAssertEqual(KimiK2BoardCatalog.base(light: false)?.sourceAlias, "boardBaseDark")
  XCTAssertEqual(KimiK2BoardCatalog.base(light: true)?.sourceAlias, "boardBaseLight")
  XCTAssertEqual(KimiK2BoardCatalog.sourceArchiveSHA256.count, 64)
  XCTAssertEqual(KimiK2BoardCatalog.sourceMapSHA256.count, 64)
  XCTAssertEqual(KimiK2BoardCatalog.tileCount, 40)
 }
 func testAtlasBottomOriginUVAndFourCornerRotation() {
  let frame=KimiK2AtlasGeometry.Rect(10,10,236,236)
  let uv=KimiK2AtlasGeometry.bottomUV(frame:frame)
  XCTAssertNotNil(uv)
  XCTAssertEqual(uv!.x, 10/2048, accuracy: 1e-12)
  XCTAssertEqual(uv!.y, 1034/1280, accuracy: 1e-12)
  XCTAssertEqual(uv!.width, 236/2048, accuracy: 1e-12)
  XCTAssertNil(KimiK2AtlasGeometry.bottomUV(frame:.init(2040,1000,100,400)))
  XCTAssertEqual(KimiK2AtlasGeometry.radians(-90), -Double.pi/2, accuracy:1e-12)
  XCTAssertEqual(KimiK2AtlasGeometry.radians(180), Double.pi, accuracy:1e-12)
 }
 func testFortyTileVisualGeometryIDsAndUV() {
  let tiles = KimiK2TileMap.tiles
  XCTAssertEqual(tiles.count,40)
  XCTAssertEqual(Set(tiles.map(\.id)).count,40)
  for (i,tile) in tiles.enumerated() {
   XCTAssertEqual(tile.index,i)
   XCTAssertEqual(tile.id,String(format:"VL-K2-TILE-%03d",i))
   XCTAssertGreaterThanOrEqual(tile.centerX,0)
   XCTAssertLessThanOrEqual(tile.centerX,KimiK2TileMap.designWidth)
   XCTAssertGreaterThanOrEqual(tile.centerY,0)
   XCTAssertLessThanOrEqual(tile.centerY,KimiK2TileMap.designHeight)
   XCTAssertGreaterThanOrEqual(tile.uvX,0)
   XCTAssertGreaterThanOrEqual(tile.uvY,0)
   XCTAssertLessThanOrEqual(tile.uvX+tile.uvWidth,1.000001)
   XCTAssertLessThanOrEqual(tile.uvY+tile.uvHeight,1.000001)
  }
  XCTAssertNil(KimiK2TileMap.visual(for:-1))
  XCTAssertNil(KimiK2TileMap.visual(for:40))
  XCTAssertEqual(KimiK2TileMap.visual(for:0)?.rotationDegrees,0)
  XCTAssertEqual(KimiK2TileMap.visual(for:10)?.rotationDegrees,-90)
  XCTAssertEqual(KimiK2TileMap.visual(for:20)?.rotationDegrees,180)
  XCTAssertEqual(KimiK2TileMap.visual(for:30)?.rotationDegrees,90)
 }

}
