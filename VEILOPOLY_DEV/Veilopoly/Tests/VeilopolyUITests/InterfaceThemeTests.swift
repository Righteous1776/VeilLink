import Foundation
import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class InterfaceThemeTests: XCTestCase {
 func testThemeFollowsExistingBoardPreferenceAndDoesNotChangeGameplay() {
  let game = GameFactory.make(seed: 7401, humanCount: 1)
  let before = StateDigest.hash(game)
  XCTAssertTrue(VeilopolyInterfaceTheme(dayFelt: IvoryUnifiedVisualSystem.defaultLightTheme).isLight)
  XCTAssertEqual(VeilopolyInterfaceTheme(dayFelt: false), .night)
  XCTAssertEqual(VeilopolyInterfaceTheme(dayFelt: true), .day)
  XCTAssertEqual(StateDigest.hash(game), before)
 }

 func testNightRemovesBrightCanvasAndPaperSurround() {
  let night = VeilopolyInterfaceTheme.night
  for color in [night.canvasStart, night.canvasEnd, night.paper, night.paperSurround] {
   XCTAssertLessThan(luminance(color), 0.04)
  }
  XCTAssertGreaterThan(luminance(VeilopolyInterfaceTheme.day.paper), 0.8)
  XCTAssertNotEqual(VeilopolyInterfaceTheme.day.canvasStart, night.canvasStart)
 }

 func testNormalSizeReadingTextHasAAContrastInBothThemes() {
  for theme in VeilopolyInterfaceTheme.allCases {
   for background in [theme.paper, theme.paperSurround] {
    for foreground in [theme.ink, theme.secondaryInk, theme.goldInk] {
     XCTAssertGreaterThanOrEqual(contrast(foreground, background), 4.5,
      "\(theme): small guide/news labels must not depend on low-opacity gold or ink")
    }
   }
  }
 }

 func testPaletteIsBoundedOpaqueSRGBWithoutAssetOrStateVariants() {
  for theme in VeilopolyInterfaceTheme.allCases {
   for color in [theme.canvasStart, theme.canvasEnd, theme.paper, theme.paperSurround,
                 theme.ink, theme.secondaryInk, theme.goldInk] {
    for channel in [color.red, color.green, color.blue] {
     XCTAssertTrue(channel.isFinite)
     XCTAssertTrue((0...1).contains(channel))
    }
   }
  }
 }

 private func luminance(_ color: VeilopolyThemeRGB) -> Double {
  func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
  return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
 }
 private func contrast(_ a: VeilopolyThemeRGB, _ b: VeilopolyThemeRGB) -> Double {
  let first = luminance(a), second = luminance(b)
  return (max(first, second) + 0.05) / (min(first, second) + 0.05)
 }
}
