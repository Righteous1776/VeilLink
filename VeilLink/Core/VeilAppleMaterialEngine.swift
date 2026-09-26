import SwiftUI
import UIKit

enum VeilPlatformMaterialEngine {
    static var runtimeIsIOS26OrNewer: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    static var nativeLiquidGlassCompiled: Bool {
        #if compiler(>=6.2)
        return true
        #else
        return false
        #endif
    }

    static var diagnosticLabel: String {
        if nativeLiquidGlassCompiled && runtimeIsIOS26OrNewer { return "LIQUID GLASS · NATIVE" }
        if runtimeIsIOS26OrNewer { return "LIQUID GLASS · SDK FALLBACK" }
        return "APPLE MATERIAL · COMPAT"
    }
}

struct VeilPlatformGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.interactive(interactive),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        if VeilRenderProfile.usesLegacyCompositorPath {
            content
                .background(VeilAppearanceController.shared.isAppleSoft ? VeilTheme.panel.opacity(0.98) : VeilTheme.elevated.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(VeilTheme.hairline, lineWidth: 1)
                )
        } else {
            content
                .background(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(VeilAppearanceController.shared.isAppleSoft ? VeilTheme.panel.opacity(colorScheme == .dark ? 0.34 : 0.54) : VeilTheme.elevated.opacity(0.36))
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 14, x: 0, y: 8)
        }
    }
}

struct VeilPlatformGlassCluster<Content: View>: View {
    let spacing: CGFloat
    private let content: () -> Content

    init(spacing: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
        #else
        content()
        #endif
    }
}

struct VeilAppleSoftSurface: View {
    var cornerRadius: CGFloat = 24
    var emphasized = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let legacy = VeilRenderProfile.usesLegacyCompositorPath

        shape
            .fill(emphasized ? VeilTheme.panelSoft : VeilTheme.panel)
            .overlay(
                shape.stroke(
                    colorScheme == .dark ? Color.white.opacity(emphasized ? 0.10 : 0.065) : Color.white.opacity(0.78),
                    lineWidth: 0.8
                )
            )
            .overlay(alignment: .top) {
                if !legacy {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.09 : 0.72), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? (emphasized ? 0.32 : 0.24) : 0.12),
                radius: legacy ? 3 : (emphasized ? 20 : 14),
                x: 0,
                y: legacy ? 2 : (emphasized ? 11 : 7)
            )
            .shadow(
                color: legacy ? .clear : Color.white.opacity(colorScheme == .dark ? 0.025 : 0.86),
                radius: emphasized ? 15 : 10,
                x: -5,
                y: -5
            )
    }
}

struct VeilAppleSoftBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.055, green: 0.057, blue: 0.064), Color(red: 0.095, green: 0.098, blue: 0.11)]
                    : [Color(red: 0.965, green: 0.968, blue: 0.982), Color(red: 0.91, green: 0.925, blue: 0.955)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !VeilRenderProfile.usesLegacyCompositorPath {
                RadialGradient(
                    colors: [VeilTheme.gold.opacity(colorScheme == .dark ? 0.14 : 0.13), Color.clear],
                    center: UnitPoint(x: 0.88, y: 0.08),
                    startRadius: 0,
                    endRadius: 360
                )
                RadialGradient(
                    colors: [Color.white.opacity(colorScheme == .dark ? 0.035 : 0.62), Color.clear],
                    center: UnitPoint(x: 0.08, y: 0.72),
                    startRadius: 0,
                    endRadius: 300
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct VeilAppleSoftTextFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(VeilTheme.elevated.opacity(0.84))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.80), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 8, x: 0, y: 4)
    }
}

extension VeilMorphVectorData {
    static let appleDot = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.50, y: 0.50)]
    ])

    static let appleCheck = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.22, y: 0.52), CGPoint(x: 0.43, y: 0.72), CGPoint(x: 0.80, y: 0.30)]
    ])

    static let applePlus = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.50, y: 0.20), CGPoint(x: 0.50, y: 0.80)],
        [CGPoint(x: 0.20, y: 0.50), CGPoint(x: 0.80, y: 0.50)]
    ])

    static let appleClose = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.28, y: 0.28), CGPoint(x: 0.72, y: 0.72)],
        [CGPoint(x: 0.72, y: 0.28), CGPoint(x: 0.28, y: 0.72)]
    ])
}

extension View {
    func veilPlatformGlass(cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(VeilPlatformGlassSurfaceModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    func veilAppleSoftInput() -> some View {
        modifier(VeilAppleSoftTextFieldModifier())
    }
}
