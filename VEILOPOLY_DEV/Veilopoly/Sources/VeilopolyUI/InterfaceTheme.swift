/// UI-only theme derived from the existing board preference. Never stored in
/// GameState or used by the reducer, market RNG, command queue or save digest.
public enum VeilopolyInterfaceTheme: CaseIterable, Equatable, Sendable {
 case day, night

 public init(dayFelt: Bool) { self = dayFelt ? .day : .night }
 public var isLight: Bool { self == .day }
 public var canvasStart: VeilopolyThemeRGB {
  isLight ? .init(red: 0.97, green: 0.95, blue: 0.90) : .init(red: 0.065, green: 0.09, blue: 0.13)
 }
 public var canvasEnd: VeilopolyThemeRGB {
  isLight ? .init(red: 0.87, green: 0.82, blue: 0.71) : .init(red: 0.04, green: 0.07, blue: 0.10)
 }
 public var paper: VeilopolyThemeRGB {
  isLight ? .init(red: 0.969, green: 0.946, blue: 0.895) : .init(red: 0.09, green: 0.16, blue: 0.17)
 }
 public var paperSurround: VeilopolyThemeRGB {
  isLight ? .init(red: 0.92, green: 0.89, blue: 0.82) : canvasEnd
 }
 public var ink: VeilopolyThemeRGB {
  isLight ? .init(red: 0.11, green: 0.27, blue: 0.28) : .init(red: 0.90, green: 0.94, blue: 0.92)
 }
 public var secondaryInk: VeilopolyThemeRGB {
  isLight ? .init(red: 0.25, green: 0.34, blue: 0.33) : .init(red: 0.72, green: 0.80, blue: 0.77)
 }
 public var goldInk: VeilopolyThemeRGB {
  isLight ? .init(red: 0.48, green: 0.34, blue: 0.16) : .init(red: 0.86, green: 0.73, blue: 0.48)
 }
}

public struct VeilopolyThemeRGB: Equatable, Sendable {
 public let red: Double
 public let green: Double
 public let blue: Double
}

#if os(iOS) && canImport(SwiftUI)
import SwiftUI

extension VeilopolyThemeRGB {
 var color: Color { Color(red: red, green: green, blue: blue) }
}
extension VeilopolyInterfaceTheme {
 var colorScheme: ColorScheme { isLight ? .light : .dark }
}
private struct VeilopolyInterfaceThemeKey: EnvironmentKey {
 static let defaultValue = VeilopolyInterfaceTheme(dayFelt: IvoryUnifiedVisualSystem.defaultLightTheme)
}
extension EnvironmentValues {
 var veilopolyInterfaceTheme: VeilopolyInterfaceTheme {
  get { self[VeilopolyInterfaceThemeKey.self] }
  set { self[VeilopolyInterfaceThemeKey.self] = newValue }
 }
}
#endif
