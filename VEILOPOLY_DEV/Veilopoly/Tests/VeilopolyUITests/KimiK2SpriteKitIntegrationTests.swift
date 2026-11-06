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
 func testDayNightSwitchReusesTheSameFortyTilesAndLeavesExitIndependent() {
  let scene = GameBoardScene(size: CGSize(width: 1024, height: 940))
  guard let corner = scene.childNode(withName: "VL-K2-TILE-000"),
        let opposite = scene.childNode(withName: "VL-K2-TILE-020") else {
   return XCTFail("Kimi 40-cell board is not active")
  }
  let cornerPosition = corner.position
  let oppositePosition = opposite.position
  let originalChildCount = scene.children.count
  scene.setDayFelt(true)
  XCTAssertTrue(scene.isDayFelt)
  XCTAssertTrue(scene.childNode(withName: "VL-K2-TILE-000") === corner)
  XCTAssertTrue(scene.childNode(withName: "VL-K2-TILE-020") === opposite)
  XCTAssertEqual(corner.position, cornerPosition)
  XCTAssertEqual(opposite.position, oppositePosition)
  XCTAssertEqual(scene.children.count, originalChildCount)
  scene.setDayFelt(false)
  XCTAssertFalse(scene.isDayFelt)
  XCTAssertTrue(scene.childNode(withName: "VL-K2-TILE-000") === corner)
 }

 func testFourTokenShadowsFollowSnapshotsAndHideOnBankruptcy() {
  let model = GameSessionModel(seed: 12345, humanCount: 1)
  let scene = model.scene
  for i in 0..<4 {
   XCTAssertNotNil(scene.childNode(withName: "KimiK2/token-shadow-\(i)"))
  }
  let shadow = scene.childNode(withName: "KimiK2/token-shadow-0")
  let start = shadow?.position
  var moved = model.game
  moved.players[0].position = 20
  scene.display(moved)
  XCTAssertNotEqual(start, shadow?.position)
  moved.players[0].bankrupt = true
  scene.display(moved)
  XCTAssertEqual(shadow?.isHidden, true)
  moved.players[0].bankrupt = false
  scene.display(moved)
  XCTAssertEqual(shadow?.isHidden, false)
 }

 func testWinnerBadgeBindsToActualEngineWinnerAndClearsOnReset() {
  let model = GameSessionModel(seed: 2468, humanCount: 1)
  let scene = model.scene
  XCTAssertNil(scene.childNode(withName: "KimiK2/victoryBadge"))
  var state = model.game
  state.winner = 0
  scene.display(state)
  let badge = scene.childNode(withName: "KimiK2/victoryBadge")
  XCTAssertNotNil(badge)
  XCTAssertEqual((badge?.childNode(withName: "winnerName") as? SKLabelNode)?.text,
                 state.players[0].name)
  state.winner = nil
  scene.display(state)
  XCTAssertNil(scene.childNode(withName: "KimiK2/victoryBadge"))
 }

}
#endif
