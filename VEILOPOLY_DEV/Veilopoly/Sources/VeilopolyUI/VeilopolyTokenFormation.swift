/// Deterministic four-token placement within one 81x73 board tile.
/// Renderer-only geometry: no UIKit, SpriteKit, RNG or GameState mutation.
public enum VeilopolyTokenFormation {
 public struct Offset: Equatable, Sendable {
  public let x: Int
  public let y: Int
  public init(x: Int, y: Int) { self.x = x; self.y = y }
 }
 public static let tokenSize = 34
 /// 2x2 placement, matching the stable player IDs and token colors.
 public static func offset(player: Int) -> Offset? {
  switch player {
  case 0: return Offset(x: -18, y: 16)
  case 1: return Offset(x: 18, y: 16)
  case 2: return Offset(x: -18, y: -16)
  case 3: return Offset(x: 18, y: -16)
  default: return nil
  }
 }
}
