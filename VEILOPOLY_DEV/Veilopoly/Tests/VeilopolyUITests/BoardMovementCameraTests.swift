#if os(iOS) && canImport(SpriteKit)
import XCTest
import SpriteKit
@testable import VeilopolyUI

@MainActor
final class BoardMovementCameraTests: XCTestCase {
 func testMovingTokenNeverSchedulesCameraZoomAndSkipAcknowledgesOnce() throws {
  let model = GameSessionModel(seed: 7101, humanCount: 1)
  let scene = model.scene
  let camera = try XCTUnwrap(scene.camera)
  let position = camera.position
  let scale = CGSize(width: camera.xScale, height: camera.yScale)
  var acknowledgements = 0

  scene.play(.tokenMove(player: 0, path: [1, 2, 3])) { acknowledgements += 1 }
  // Inspect queued actions, not just the unchanged first frame: the old
  // 0.83 zoom was scheduled here but had not started interpolating yet.
  XCTAssertFalse(camera.hasActions())
  XCTAssertEqual(acknowledgements, 0)
  scene.fastForward()
  scene.fastForward()
  XCTAssertEqual(acknowledgements, 1)
  XCTAssertEqual(camera.position, position)
  XCTAssertEqual(camera.xScale, scale.width)
  XCTAssertEqual(camera.yScale, scale.height)
  XCTAssertFalse(camera.hasActions())

  var landed = model.game
  landed.players[0].position = 3
  let token = try XCTUnwrap(scene.childNode(withName: "Veilopoly/player-token-0"))
  let skippedPosition = token.position
  scene.display(landed)
  XCTAssertEqual(token.position, skippedPosition, "Skip must land at the final board cell")
 }

 func testReducedMotionAndMissingTokenKeepCameraAndAcknowledgeOnce() throws {
  let model = GameSessionModel(seed: 7102, humanCount: 1)
  let scene = model.scene
  let camera = try XCTUnwrap(scene.camera)
  let position = camera.position
  var acknowledgements = 0
  scene.reduceMotion = true
  scene.play(.tokenMove(player: 0, path: [39, 0, 1])) { acknowledgements += 1 }
  scene.fastForward()
  XCTAssertEqual(acknowledgements, 1)
  scene.reduceMotion = false
  scene.play(.tokenMove(player: 99, path: [1])) { acknowledgements += 1 }
  scene.fastForward()
  XCTAssertEqual(acknowledgements, 2)
  XCTAssertEqual(camera.position, position)
  XCTAssertEqual(camera.xScale, 1)
  XCTAssertEqual(camera.yScale, 1)
  XCTAssertFalse(camera.hasActions())
 }
}
#endif
