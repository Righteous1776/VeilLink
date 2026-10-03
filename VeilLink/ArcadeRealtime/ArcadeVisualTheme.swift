import SwiftUI
import UIKit

@MainActor
enum ArcadeRenderPolicy {
    /// Real-time games keep a stable 60 Hz baseline. God Mode may explicitly use
    /// the display's higher refresh rate instead of having premium motion capped.
    static var preferredFramesPerSecond: Int {
        let displayMaximum = max(60, UIScreen.main.maximumFramesPerSecond)
        return VeilPerformanceOverrides.forceFullVisualEffects ? min(120, displayMaximum) : min(60, displayMaximum)
    }
}

/// Original visual motifs used by the realtime arcade. Motifs are intentionally
/// semantic rather than tied to a particular game, so a new game can acquire a
/// coherent icon, card and reward treatment without adding image assets.
enum ArcadeVisualMotif: String, CaseIterable, Identifiable {
    case comet
    case guardian
    case pulse
    case bloom
    case circuit
    case tide

    var id: String { rawValue }

    var accessibilityName: String {
        switch self {
        case .comet: return "彗星"
        case .guardian: return "守护者"
        case .pulse: return "脉冲"
        case .bloom: return "星花"
        case .circuit: return "回路"
        case .tide: return "潮汐"
        }
    }
}

/// A high-contrast palette that remains legible on the app's dark surfaces.
/// Every color is expressed in code so the system has no external-art or
/// licensing dependency.
struct ArcadeVisualPalette {
    let primary: Color
    let secondary: Color
    let highlight: Color
    let shadow: Color

    static func palette(for motif: ArcadeVisualMotif) -> ArcadeVisualPalette {
        switch motif {
        case .comet:
            return ArcadeVisualPalette(
                primary: Color(red: 1.00, green: 0.49, blue: 0.20),
                secondary: Color(red: 1.00, green: 0.82, blue: 0.30),
                highlight: Color(red: 1.00, green: 0.96, blue: 0.70),
                shadow: Color(red: 0.36, green: 0.08, blue: 0.12)
            )
        case .guardian:
            return ArcadeVisualPalette(
                primary: Color(red: 0.25, green: 0.82, blue: 0.98),
                secondary: Color(red: 0.25, green: 0.46, blue: 1.00),
                highlight: Color(red: 0.78, green: 0.98, blue: 1.00),
                shadow: Color(red: 0.04, green: 0.14, blue: 0.34)
            )
        case .pulse:
            return ArcadeVisualPalette(
                primary: Color(red: 0.95, green: 0.28, blue: 0.70),
                secondary: Color(red: 0.58, green: 0.24, blue: 0.96),
                highlight: Color(red: 1.00, green: 0.78, blue: 0.96),
                shadow: Color(red: 0.29, green: 0.03, blue: 0.28)
            )
        case .bloom:
            return ArcadeVisualPalette(
                primary: Color(red: 0.30, green: 0.94, blue: 0.61),
                secondary: Color(red: 0.85, green: 0.94, blue: 0.30),
                highlight: Color(red: 0.88, green: 1.00, blue: 0.77),
                shadow: Color(red: 0.03, green: 0.25, blue: 0.18)
            )
        case .circuit:
            return ArcadeVisualPalette(
                primary: Color(red: 0.55, green: 0.42, blue: 1.00),
                secondary: Color(red: 0.20, green: 0.88, blue: 0.92),
                highlight: Color(red: 0.86, green: 0.84, blue: 1.00),
                shadow: Color(red: 0.11, green: 0.07, blue: 0.32)
            )
        case .tide:
            return ArcadeVisualPalette(
                primary: Color(red: 0.10, green: 0.72, blue: 0.88),
                secondary: Color(red: 0.12, green: 0.94, blue: 0.76),
                highlight: Color(red: 0.76, green: 1.00, blue: 0.95),
                shadow: Color(red: 0.02, green: 0.18, blue: 0.30)
            )
        }
    }

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [highlight, primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var atmosphereGradient: RadialGradient {
        RadialGradient(
            colors: [primary.opacity(0.48), shadow.opacity(0.20), Color.clear],
            center: .center,
            startRadius: 1,
            endRadius: 150
        )
    }
}

enum ArcadeVisualMetrics {
    static let minimumTapTarget: CGFloat = 44
    static let compactBreakpoint: CGFloat = 340

    static func cardCornerRadius(width: CGFloat) -> CGFloat {
        width < compactBreakpoint ? 18 : 22
    }

    static func cardHeight(width: CGFloat) -> CGFloat {
        width < compactBreakpoint ? 146 : 168
    }

    static func horizontalPadding(width: CGFloat) -> CGFloat {
        width < compactBreakpoint ? 12 : 16
    }
}

/// Deterministic pseudo-random helpers used by Canvas effects. Keeping the
/// values stable prevents particle positions from visually jumping on redraw.
enum ArcadeVisualSeed {
    static func unit(_ seed: Int, _ lane: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed &+ lane &* 7_919))
        value ^= value >> 30
        value &*= 0xbf58_476d_1ce4_e5b9
        value ^= value >> 27
        value &*= 0x94d0_49bb_1331_11eb
        value ^= value >> 31
        return Double(value % 10_000) / 10_000
    }
}
