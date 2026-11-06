#if os(iOS) && canImport(SpriteKit)
import XCTest
import SpriteKit
@testable import VeilopolyUI

@MainActor
final class KimiK2SpriteKitIntegrationTests: XCTestCase {
 func testAllFortyLiveVisualCellsUseOriginalCoordinates() {
  let scene = GameBoardScene(size: CGSize(width: 1024, height: 940))
  let sprites = scene.children.filter { $0.name?.hasPrefix("VL-K2-TILE-") == true }
  XCTAssertEqual(sprites.count, 40)
  for corner in [0,10,20,30] {
   guard let geometry = KimiK2TileMap.visual(for: corner),
         let sprite = scene.childNode(withName: geometry.id) else {
    XCTFail("Missing Kimi sprite at corner " + String(corner)); continue
   }
   XCTAssertEqual(sprite.position.x, CGFloat(geometry.centerX), accuracy: 0.01)
   XCTAssertEqual(sprite.position.y, CGFloat(geometry.centerY), accuracy: 0.01)
   XCTAssertEqual(sprite.zRotation, CGFloat(geometry.rotationRadians), accuracy: 0.001)
  }
 }

 func testPartialAssetSetCannotInstallIncompleteKimiBoard() {
  let scene = SKScene(size: CGSize(width: 1024, height: 940))
  let result = KimiK2BoardSkin.install(in: scene, load: { _ in nil })
  XCTAssertNil(result)
  XCTAssertTrue(scene.children.isEmpty)
 }
}
#endif
