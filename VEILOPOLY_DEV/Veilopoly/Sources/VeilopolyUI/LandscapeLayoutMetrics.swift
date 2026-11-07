import Foundation

/// Immutable layout constants for the landscape board/UI split. Has no UIKit or
/// SpriteKit dependency, so it can be tested with the portable Swift toolchain.
public enum VeilopolyLandscapeLayout {
 public static let boardAspect = 1024.0 / 940.0
 public static let minimumControlTouchSide = 44.0
 public static let capsuleButtonWidth = 46.0
 public static let capsuleTouchHeight = minimumControlTouchSide
 public static let capsuleDividerWidth = 1.0
 public static let boardHorizontalInset = 6.0
 public static let boardVerticalInset = 4.0
 public static let drawerTopInset = 54.0
 public static let drawerBottomInset = 10.0
 public static let drawerCloseMinWidth = 78.0
 /// The ticker occupies only the free space between board and More/Exit.
 public static func bulletinWidth(availableWidth: Double, boardWidth: Double) -> Double {
  max(0, availableWidth - boardWidth - 128)
 }

 /// Conservative center-to-center distances in design points, used for
 /// regression checks. Top-right Exit center is 22pt from top; the
 /// collapsed status entry is anchored near the bottom. Drawer-close
 /// sits at the LEFT end of the overlay, away from the exit capsule.
 public static func topExitToBottomActionVerticalDistance(viewportHeight: Double) -> Double {
  max(0, viewportHeight - 2 * (boardVerticalInset + capsuleTouchHeight / 2))
 }

 public static func topExitToDrawerCloseHorizontalDistance(viewportWidth: Double) -> Double {
  let drawer = overlayDrawerWidth(for: viewportWidth)
  return max(0, drawer - 10 - drawerCloseMinWidth / 2 - capsuleButtonWidth / 2)
 }

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
 /// With no permanent sidebar, maximize the whole 40-tile board to the safe
 /// viewport height and retain its original aspect ratio. Never crop cells.
 public static func maximizedBoardSize(availableWidth: Double, availableHeight: Double) -> (width: Double, height: Double) {
  boardSize(availableWidth: max(0, availableWidth - 2 * boardHorizontalInset),
            availableHeight: max(0, availableHeight - 2 * boardVerticalInset))
 }

 /// Overlay is intentionally separate from board layout: collapsing it
 /// must never trigger a new board size or camera target.
 public static func overlayDrawerWidth(for width: Double) -> Double {
  let available = max(0, width - 12)
  return min(available, min(max(width * 0.44, 292), 395))
 }

 public static func overlayDrawerHeight(for height: Double) -> Double {
  max(0, height - drawerTopInset - drawerBottomInset)
 }

}
