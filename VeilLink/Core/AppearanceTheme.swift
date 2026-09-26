import Combine
import SwiftUI
import UIKit

enum VeilColorMode: String, CaseIterable, Identifiable, Codable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var subtitle: String {
        switch self {
        case .automatic: return "跟随 iOS 外观"
        case .light: return "始终使用白天配色"
        case .dark: return "始终使用夜间配色"
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func resolvesDark(systemIsDark: Bool) -> Bool {
        switch self {
        case .automatic: return systemIsDark
        case .light: return false
        case .dark: return true
        }
    }
}

enum VeilAppearanceSelection: String, CaseIterable, Identifiable, Codable {
    case veilOriginal
    case appleSoft
    case instrumentAuto

    var id: String { rawValue }
    var title: String {
        switch self {
        case .veilOriginal: return "Veil 原生"
        case .appleSoft: return "Apple Soft"
        case .instrumentAuto: return "拟物仪器"
        }
    }
    var subtitle: String {
        switch self {
        case .veilOriginal: return "保留现有黑金、切角面板与 Veil 动效。"
        case .appleSoft: return "苹果式软质拟物；iOS 26 自动接入底层 Liquid Glass。"
        case .instrumentAuto: return "柔和仪器拟物；完整支持浅色、深色与跟随系统。"
        }
    }

    var previewSystemImage: String {
        switch self {
        case .veilOriginal: return "sparkles"
        case .appleSoft: return "circle.grid.2x2.fill"
        case .instrumentAuto: return "dial.medium.fill"
        }
    }

    var previewSurfaceColor: Color {
        switch self {
        case .veilOriginal: return Color(red: 0.02, green: 0.02, blue: 0.03)
        case .appleSoft: return Color(red: 0.91, green: 0.93, blue: 0.97)
        case .instrumentAuto: return Color(red: 0.38, green: 0.38, blue: 0.40)
        }
    }
}

struct VeilThemePalette {
    let background: Color
    let backgroundLift: Color
    let elevated: Color
    let panel: Color
    let panelSoft: Color
    let obsidian: Color
    let veil: Color
    let gold: Color
    let goldBright: Color
    let goldDeep: Color
    let mutedGold: Color
    let paleMetal: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let hairline: Color
    let danger: Color
    let success: Color
    let metalTop: Color
    let metalBottom: Color
    let recess: Color
    let keycapTop: Color
    let keycapBottom: Color
    let indicator: Color
}

final class VeilAppearanceController: ObservableObject {
    static let shared = VeilAppearanceController()
    private enum Key {
        static let selection = "appearance.theme.selection.v1"
        static let colorMode = "appearance.color.mode.v1"
    }

    @Published var selection: VeilAppearanceSelection {
        didSet { UserDefaults.standard.set(selection.rawValue, forKey: Key.selection) }
    }
    @Published var colorMode: VeilColorMode {
        didSet {
            UserDefaults.standard.set(colorMode.rawValue, forKey: Key.colorMode)
            synchronizeSystemAppearance()
        }
    }
    @Published private(set) var systemIsDark = true

    private init() {
        selection = UserDefaults.standard.string(forKey: Key.selection)
            .flatMap(VeilAppearanceSelection.init(rawValue:)) ?? .veilOriginal
        colorMode = UserDefaults.standard.string(forKey: Key.colorMode)
            .flatMap(VeilColorMode.init(rawValue:)) ?? .automatic
        systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        synchronizeSystemAppearance()
    }

    /// Environment updates are authoritative only in Auto mode. A forced Light/Dark mode must not
    /// be overwritten by an intermediate UIKit trait while a scene or lock screen is transitioning.
    func update(colorScheme: ColorScheme) {
        guard colorMode == .automatic else { return }
        let next = colorScheme == .dark
        if systemIsDark != next { systemIsDark = next }
    }

    func synchronizeSystemAppearance() {
        guard colorMode == .automatic else { return }
        let style = UITraitCollection.current.userInterfaceStyle
        guard style != .unspecified else { return }
        let next = style == .dark
        if systemIsDark != next { systemIsDark = next }
    }

    func setColorMode(_ mode: VeilColorMode) {
        guard colorMode != mode else { return }
        colorMode = mode
    }

    var preferredColorScheme: ColorScheme? { colorMode.preferredColorScheme }
    var isDarkAppearance: Bool { colorMode.resolvesDark(systemIsDark: systemIsDark) }
    var isInstrument: Bool { selection == .instrumentAuto }
    var isAppleSoft: Bool { selection == .appleSoft }
    var appearanceLabel: String {
        let phase = isDarkAppearance ? "NIGHT" : "DAY"
        switch selection {
        case .veilOriginal: return "VEIL ORIGINAL · \(phase)"
        case .appleSoft: return "APPLE SOFT · \(phase)"
        case .instrumentAuto: return "INSTRUMENT · \(phase)"
        }
    }

    var palette: VeilThemePalette {
        switch selection {
        case .veilOriginal: return isDarkAppearance ? Self.original : Self.originalDay
        case .appleSoft: return isDarkAppearance ? Self.appleSoftNight : Self.appleSoftDay
        case .instrumentAuto: return isDarkAppearance ? Self.instrumentNight : Self.instrumentDay
        }
    }

    static let originalDay = VeilThemePalette(
        background: Color(red: 0.958, green: 0.952, blue: 0.936),
        backgroundLift: Color(red: 0.988, green: 0.983, blue: 0.970),
        elevated: Color(red: 0.944, green: 0.936, blue: 0.918),
        panel: Color(red: 0.928, green: 0.918, blue: 0.895),
        panelSoft: Color(red: 0.975, green: 0.969, blue: 0.952),
        obsidian: Color(red: 0.902, green: 0.892, blue: 0.868),
        veil: Color(red: 0.932, green: 0.923, blue: 0.904),
        gold: Color(red: 0.72, green: 0.48, blue: 0.12),
        goldBright: Color(red: 0.88, green: 0.61, blue: 0.18),
        goldDeep: Color(red: 0.48, green: 0.29, blue: 0.065),
        mutedGold: Color(red: 0.45, green: 0.36, blue: 0.22),
        paleMetal: Color(red: 0.54, green: 0.51, blue: 0.45),
        text: Color.black.opacity(0.88),
        secondaryText: Color.black.opacity(0.57),
        tertiaryText: Color.black.opacity(0.34),
        hairline: Color.black.opacity(0.085),
        danger: Color(red: 0.80, green: 0.16, blue: 0.18),
        success: Color(red: 0.08, green: 0.56, blue: 0.30),
        metalTop: Color(red: 0.985, green: 0.980, blue: 0.966),
        metalBottom: Color(red: 0.900, green: 0.888, blue: 0.862),
        recess: Color.black.opacity(0.08),
        keycapTop: Color(red: 0.985, green: 0.980, blue: 0.966),
        keycapBottom: Color(red: 0.910, green: 0.900, blue: 0.878),
        indicator: Color(red: 0.82, green: 0.50, blue: 0.10)
    )

    static let original = VeilThemePalette(
        background: Color(red: 0.012, green: 0.013, blue: 0.017),
        backgroundLift: Color(red: 0.026, green: 0.027, blue: 0.034),
        elevated: Color(red: 0.045, green: 0.046, blue: 0.056),
        panel: Color(red: 0.070, green: 0.069, blue: 0.080),
        panelSoft: Color(red: 0.095, green: 0.091, blue: 0.102),
        obsidian: Color(red: 0.020, green: 0.021, blue: 0.026),
        veil: Color(red: 0.032, green: 0.030, blue: 0.038),
        gold: Color(red: 0.86, green: 0.64, blue: 0.24),
        goldBright: Color(red: 0.98, green: 0.82, blue: 0.46),
        goldDeep: Color(red: 0.48, green: 0.31, blue: 0.09),
        mutedGold: Color(red: 0.52, green: 0.40, blue: 0.21),
        paleMetal: Color(red: 0.78, green: 0.75, blue: 0.68),
        text: Color.white.opacity(0.96),
        secondaryText: Color.white.opacity(0.57),
        tertiaryText: Color.white.opacity(0.32),
        hairline: Color.white.opacity(0.072),
        danger: Color(red: 0.91, green: 0.28, blue: 0.28),
        success: Color(red: 0.35, green: 0.80, blue: 0.55),
        metalTop: Color(red: 0.18, green: 0.18, blue: 0.20),
        metalBottom: Color(red: 0.05, green: 0.05, blue: 0.06),
        recess: Color.black.opacity(0.55),
        keycapTop: Color(red: 0.19, green: 0.19, blue: 0.21),
        keycapBottom: Color(red: 0.08, green: 0.08, blue: 0.09),
        indicator: Color(red: 1.0, green: 0.42, blue: 0.08)
    )

    static let appleSoftDay = VeilThemePalette(
        background: Color(red: 0.950, green: 0.956, blue: 0.974),
        backgroundLift: Color(red: 0.982, green: 0.984, blue: 0.992),
        elevated: Color(red: 0.972, green: 0.976, blue: 0.988),
        panel: Color(red: 0.935, green: 0.944, blue: 0.968),
        panelSoft: Color(red: 0.985, green: 0.987, blue: 0.995),
        obsidian: Color(red: 0.890, green: 0.905, blue: 0.940),
        veil: Color(red: 0.925, green: 0.936, blue: 0.962),
        gold: Color(red: 0.090, green: 0.455, blue: 0.930),
        goldBright: Color(red: 0.170, green: 0.535, blue: 1.000),
        goldDeep: Color(red: 0.035, green: 0.275, blue: 0.665),
        mutedGold: Color(red: 0.315, green: 0.430, blue: 0.610),
        paleMetal: Color(red: 0.650, green: 0.690, blue: 0.760),
        text: Color.black.opacity(0.88),
        secondaryText: Color.black.opacity(0.56),
        tertiaryText: Color.black.opacity(0.34),
        hairline: Color.black.opacity(0.075),
        danger: Color(red: 0.88, green: 0.18, blue: 0.20),
        success: Color(red: 0.08, green: 0.62, blue: 0.34),
        metalTop: Color(red: 0.985, green: 0.987, blue: 0.995),
        metalBottom: Color(red: 0.900, green: 0.916, blue: 0.950),
        recess: Color.black.opacity(0.08),
        keycapTop: Color.white.opacity(0.96),
        keycapBottom: Color(red: 0.905, green: 0.920, blue: 0.950),
        indicator: Color(red: 0.090, green: 0.455, blue: 0.930)
    )

    static let appleSoftNight = VeilThemePalette(
        background: Color(red: 0.055, green: 0.057, blue: 0.064),
        backgroundLift: Color(red: 0.085, green: 0.088, blue: 0.098),
        elevated: Color(red: 0.105, green: 0.108, blue: 0.120),
        panel: Color(red: 0.120, green: 0.124, blue: 0.138),
        panelSoft: Color(red: 0.145, green: 0.150, blue: 0.166),
        obsidian: Color(red: 0.075, green: 0.078, blue: 0.088),
        veil: Color(red: 0.095, green: 0.098, blue: 0.110),
        gold: Color(red: 0.180, green: 0.530, blue: 1.000),
        goldBright: Color(red: 0.340, green: 0.645, blue: 1.000),
        goldDeep: Color(red: 0.070, green: 0.310, blue: 0.720),
        mutedGold: Color(red: 0.430, green: 0.550, blue: 0.720),
        paleMetal: Color(red: 0.700, green: 0.730, blue: 0.790),
        text: Color.white.opacity(0.94),
        secondaryText: Color.white.opacity(0.62),
        tertiaryText: Color.white.opacity(0.38),
        hairline: Color.white.opacity(0.085),
        danger: Color(red: 1.00, green: 0.30, blue: 0.32),
        success: Color(red: 0.22, green: 0.82, blue: 0.50),
        metalTop: Color(red: 0.165, green: 0.170, blue: 0.185),
        metalBottom: Color(red: 0.090, green: 0.092, blue: 0.102),
        recess: Color.black.opacity(0.42),
        keycapTop: Color(red: 0.165, green: 0.170, blue: 0.185),
        keycapBottom: Color(red: 0.095, green: 0.098, blue: 0.110),
        indicator: Color(red: 0.230, green: 0.575, blue: 1.000)
    )

    static let instrumentDay = VeilThemePalette(
        background: Color(red: 0.934, green: 0.931, blue: 0.910),
        backgroundLift: Color(red: 0.977, green: 0.974, blue: 0.958),
        elevated: Color(red: 0.910, green: 0.908, blue: 0.890),
        panel: Color(red: 0.882, green: 0.879, blue: 0.858),
        panelSoft: Color(red: 0.956, green: 0.953, blue: 0.936),
        obsidian: Color(red: 0.10, green: 0.10, blue: 0.105),
        veil: Color(red: 0.846, green: 0.842, blue: 0.820),
        gold: Color(red: 1.00, green: 0.38, blue: 0.10),
        goldBright: Color(red: 1.0, green: 0.47, blue: 0.14),
        goldDeep: Color(red: 0.72, green: 0.20, blue: 0.03),
        mutedGold: Color(red: 0.44, green: 0.40, blue: 0.34),
        paleMetal: Color(red: 0.92, green: 0.92, blue: 0.90),
        text: Color.black.opacity(0.88),
        secondaryText: Color.black.opacity(0.56),
        tertiaryText: Color.black.opacity(0.34),
        hairline: Color.black.opacity(0.085),
        danger: Color(red: 0.78, green: 0.08, blue: 0.06),
        success: Color(red: 0.10, green: 0.62, blue: 0.28),
        metalTop: Color(red: 0.970, green: 0.968, blue: 0.952),
        metalBottom: Color(red: 0.862, green: 0.858, blue: 0.838),
        recess: Color.black.opacity(0.16),
        keycapTop: Color(red: 0.968, green: 0.966, blue: 0.950),
        keycapBottom: Color(red: 0.884, green: 0.880, blue: 0.858),
        indicator: Color(red: 1.0, green: 0.28, blue: 0.03)
    )

    static let instrumentNight = VeilThemePalette(
        background: Color(red: 0.035, green: 0.036, blue: 0.038),
        backgroundLift: Color(red: 0.10, green: 0.10, blue: 0.105),
        elevated: Color(red: 0.12, green: 0.12, blue: 0.125),
        panel: Color(red: 0.16, green: 0.16, blue: 0.165),
        panelSoft: Color(red: 0.20, green: 0.20, blue: 0.205),
        obsidian: Color(red: 0.015, green: 0.015, blue: 0.018),
        veil: Color(red: 0.08, green: 0.08, blue: 0.085),
        gold: Color(red: 1.0, green: 0.34, blue: 0.05),
        goldBright: Color(red: 1.0, green: 0.50, blue: 0.12),
        goldDeep: Color(red: 0.55, green: 0.11, blue: 0.01),
        mutedGold: Color(red: 0.57, green: 0.51, blue: 0.43),
        paleMetal: Color(red: 0.72, green: 0.73, blue: 0.74),
        text: Color.white.opacity(0.93),
        secondaryText: Color.white.opacity(0.58),
        tertiaryText: Color.white.opacity(0.34),
        hairline: Color.white.opacity(0.10),
        danger: Color(red: 0.96, green: 0.18, blue: 0.12),
        success: Color(red: 0.18, green: 0.82, blue: 0.40),
        metalTop: Color(red: 0.25, green: 0.25, blue: 0.26),
        metalBottom: Color(red: 0.075, green: 0.075, blue: 0.08),
        recess: Color.black.opacity(0.65),
        keycapTop: Color(red: 0.27, green: 0.27, blue: 0.28),
        keycapBottom: Color(red: 0.10, green: 0.10, blue: 0.11),
        indicator: Color(red: 1.0, green: 0.31, blue: 0.04)
    )
}
