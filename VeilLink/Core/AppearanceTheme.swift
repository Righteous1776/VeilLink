import Combine
import SwiftUI
import UIKit

enum VeilAppearanceSelection: String, CaseIterable, Identifiable, Codable {
    case veilOriginal
    case instrumentAuto

    var id: String { rawValue }
    var title: String {
        switch self {
        case .veilOriginal: return "Veil 原生"
        case .instrumentAuto: return "仪器 · 自动"
        }
    }
    var subtitle: String {
        switch self {
        case .veilOriginal: return "保留现有黑金、切角面板与 Veil 动效。"
        case .instrumentAuto: return "现代工业拟物；随系统浅色/深色自动切换。"
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
    private enum Key { static let selection = "appearance.theme.selection.v1" }

    @Published var selection: VeilAppearanceSelection {
        didSet { UserDefaults.standard.set(selection.rawValue, forKey: Key.selection) }
    }
    @Published private(set) var systemIsDark = true

    private init() {
        selection = UserDefaults.standard.string(forKey: Key.selection)
            .flatMap(VeilAppearanceSelection.init(rawValue:)) ?? .veilOriginal
        systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
    }

    func update(colorScheme: ColorScheme) { systemIsDark = colorScheme == .dark }
    var isInstrument: Bool { selection == .instrumentAuto }
    var appearanceLabel: String {
        isInstrument ? (systemIsDark ? "INSTRUMENT · NIGHT" : "INSTRUMENT · DAY") : "VEIL ORIGINAL"
    }

    var palette: VeilThemePalette {
        guard isInstrument else { return Self.original }
        return systemIsDark ? Self.instrumentNight : Self.instrumentDay
    }

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

    static let instrumentDay = VeilThemePalette(
        background: Color(red: 0.86, green: 0.86, blue: 0.84),
        backgroundLift: Color(red: 0.94, green: 0.94, blue: 0.92),
        elevated: Color(red: 0.82, green: 0.82, blue: 0.80),
        panel: Color(red: 0.75, green: 0.75, blue: 0.73),
        panelSoft: Color(red: 0.88, green: 0.88, blue: 0.85),
        obsidian: Color(red: 0.10, green: 0.10, blue: 0.105),
        veil: Color(red: 0.68, green: 0.68, blue: 0.66),
        gold: Color(red: 0.96, green: 0.33, blue: 0.05),
        goldBright: Color(red: 1.0, green: 0.44, blue: 0.10),
        goldDeep: Color(red: 0.64, green: 0.16, blue: 0.02),
        mutedGold: Color(red: 0.44, green: 0.40, blue: 0.34),
        paleMetal: Color(red: 0.92, green: 0.92, blue: 0.90),
        text: Color.black.opacity(0.88),
        secondaryText: Color.black.opacity(0.56),
        tertiaryText: Color.black.opacity(0.34),
        hairline: Color.black.opacity(0.13),
        danger: Color(red: 0.78, green: 0.08, blue: 0.06),
        success: Color(red: 0.10, green: 0.62, blue: 0.28),
        metalTop: Color(red: 0.95, green: 0.95, blue: 0.93),
        metalBottom: Color(red: 0.63, green: 0.63, blue: 0.61),
        recess: Color.black.opacity(0.16),
        keycapTop: Color(red: 0.98, green: 0.98, blue: 0.96),
        keycapBottom: Color(red: 0.70, green: 0.70, blue: 0.68),
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
