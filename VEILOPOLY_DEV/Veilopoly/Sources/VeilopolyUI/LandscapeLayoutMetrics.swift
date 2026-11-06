import Foundation

/// Immutable layout constants for the landscape board/UI split. Has no UIKit or
/// SpriteKit dependency, so it can be tested with the portable Swift toolchain.
public enum VeilopolyLandscapeLayout {
 public static let boardAspect = 1024.0 / 940.0
 public static let capsuleButtonWidth = 46.0
 public static let capsuleTouchHeight = 44.0
 public static let capsuleDividerWidth = 1.0

 public static func isLandscape(width: Double, height: Double) -> Bool {
  width > height
 }

 public static func sidebarWidth(for width: Double) -> Double {
  min(max(width * 0.40, 285), 395)
 }

 /// Fit the complete 40-tile board within the allocated viewport without
 /// cropping its corners; keep the same aspect on iPhone and iPad.
 public static func boardSize(availableWidth: Double, availableHeight: Double) -> (width: Double, height: Double) {
  let w = max(0, availableWidth)
  let h = max(0, availableHeight)
  let width = min(w, h * boardAspect)
  return (width, width / boardAspect)
 }
}
