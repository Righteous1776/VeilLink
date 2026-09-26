import SwiftUI
import Foundation

/// VeilLink visual system.
///
/// The language is intentionally not "generic cyberpunk": near-black veils hide information,
/// identity is represented by deterministic local glyphs, warm metal only appears around trust
/// and action, and motion has three meanings only: Reveal, Transit and Resolve.
enum VeilTheme {
    private static var p: VeilThemePalette { VeilAppearanceController.shared.palette }
    static var background: Color { p.background }
    static var backgroundLift: Color { p.backgroundLift }
    static var elevated: Color { p.elevated }
    static var panel: Color { p.panel }
    static var panelSoft: Color { p.panelSoft }
    static var obsidian: Color { p.obsidian }
    static var veil: Color { p.veil }
    static var gold: Color { p.gold }
    static var goldBright: Color { p.goldBright }
    static var goldDeep: Color { p.goldDeep }
    static var mutedGold: Color { p.mutedGold }
    static var paleMetal: Color { p.paleMetal }
    static var text: Color { p.text }
    static var secondaryText: Color { p.secondaryText }
    static var tertiaryText: Color { p.tertiaryText }
    static var hairline: Color { p.hairline }
    static var danger: Color { p.danger }
    static var success: Color { p.success }
    static var goldGradient: LinearGradient {
        VeilAppearanceController.shared.isAppleSoft
            ? LinearGradient(colors: [goldBright, gold], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [goldBright, gold, goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var metalGradient: LinearGradient {
        VeilAppearanceController.shared.isAppleSoft
            ? LinearGradient(colors: [panelSoft, panel], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color.white.opacity(0.72), paleMetal, gold.opacity(0.78), goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var surfaceGradient: LinearGradient {
        VeilAppearanceController.shared.isAppleSoft
            ? LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.015)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color.white.opacity(0.040), Color.white.opacity(0.010)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var incomingBubbleGradient: LinearGradient { LinearGradient(colors: [panelSoft, panel, obsidian], startPoint: .topLeading, endPoint: .bottomTrailing) }
}


/// Hardware/OS render capability gate. iPhone 7 / 7 Plus on iOS 15 use an older
/// SwiftUI compositor path that can invalidate large clipped/shadowed scroll layers while
/// repeat-forever animations are active. Keep the visual language, but switch persistent motion
/// and expensive off-screen composition to a lighter path on that exact device family.
enum VeilRenderProfile {
    static var machineIdentifier: String { VeilDevicePerformance.machineIdentifier }

    static var usesLegacyCompositorPath: Bool {
        RenderCompatibilityPolicy.shouldUseLegacyCompositor(
            machineIdentifier: machineIdentifier,
            osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }

    static var usesStableScrollLayout: Bool {
        RenderCompatibilityPolicy.shouldUseStableScrollLayout(
            osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }

    static var allowsExpensiveVisualEffects: Bool {
        !usesLegacyCompositorPath || VeilPerformanceOverrides.forceFullVisualEffects
    }

    static var allowsPersistentAnimations: Bool {
        !usesLegacyCompositorPath || VeilPerformanceOverrides.allowPersistentAnimations
    }

    static var diagnosticLabel: String {
        let renderer: String
        if usesLegacyCompositorPath { renderer = "LEGACY15" }
        else if usesStableScrollLayout { renderer = "STABLE15" }
        else { renderer = "MODERN" }
        let god = PerformanceOverrideStore.shared.snapshot().isEnabled ? " · GOD" : ""
        return "\(renderer) · \(VeilDevicePerformance.current.label) · \(machineIdentifier)\(god)"
    }
}

enum VeilBuildInfo {
    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    static var display: String { "VeilLink \(shortVersion) (\(build)) · Protocol 4" }
}

enum VeilMotion {
    static var reveal: Animation {
        switch VeilDevicePerformance.current.transferVisualComplexity {
        case .minimal: return .easeOut(duration: 0.15)
        case .balanced: return .easeOut(duration: 0.20)
        case .full: return .easeOut(duration: 0.24)
        }
    }

    static var transit: Animation {
        switch VeilDevicePerformance.current.transferVisualComplexity {
        case .minimal: return .easeOut(duration: 0.18)
        case .balanced: return .interactiveSpring(response: 0.32, dampingFraction: 0.88)
        case .full: return .interactiveSpring(response: 0.38, dampingFraction: 0.84)
        }
    }

    static var resolve: Animation {
        switch VeilDevicePerformance.current.transferVisualComplexity {
        case .minimal: return .easeOut(duration: 0.18)
        case .balanced: return .spring(response: 0.34, dampingFraction: 0.80)
        case .full: return .spring(response: 0.42, dampingFraction: 0.72)
        }
    }
}

/// Asymmetric panel geometry used throughout VeilLink. The cuts deliberately replace generic
/// rounded cards with a more terminal-like silhouette without becoming sharp or hostile.
struct VeilPanelShape: Shape {
    var cut: CGFloat = 16
    var radius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        if VeilAppearanceController.shared.isAppleSoft {
            return RoundedRectangle(cornerRadius: max(18, radius * 2.4), style: .continuous).path(in: rect)
        }
        if VeilAppearanceController.shared.isInstrument {
            return RoundedRectangle(cornerRadius: max(12, radius * 1.8), style: .continuous).path(in: rect)
        }
        let c = min(cut, min(rect.width, rect.height) * 0.28)
        let r = min(radius, c * 0.7)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct VeilCurtainShape: Shape {
    let leadingInset: CGFloat
    let trailingInset: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + leadingInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - trailingInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - trailingInset * 0.35, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + leadingInset * 0.28, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct VeilAmbientBackground: View {
    var body: some View {
        Group {
            if VeilAppearanceController.shared.isAppleSoft {
                VeilAppleSoftBackground()
            } else if VeilAppearanceController.shared.isInstrument {
                VeilInstrumentBackground()
            } else if VeilRenderProfile.usesLegacyCompositorPath {
                // Keep the legacy background strictly within its parent's bounds. On iOS 15,
                // an ignoresSafeArea background attached to ScrollView can participate in the
                // same content-host invalidation we are trying to avoid.
                LinearGradient(
                    colors: [VeilTheme.backgroundLift, VeilTheme.background, VeilAppearanceController.shared.isDarkAppearance ? Color.black : VeilTheme.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                GeometryReader { geometry in
                    ZStack {
                        LinearGradient(
                            colors: [VeilTheme.backgroundLift, VeilTheme.background, VeilAppearanceController.shared.isDarkAppearance ? Color.black : VeilTheme.background],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        VeilCurtainShape(
                            leadingInset: geometry.size.width * 0.12,
                            trailingInset: geometry.size.width * 0.48
                        )
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.020), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        VeilCurtainShape(
                            leadingInset: geometry.size.width * 0.64,
                            trailingInset: geometry.size.width * 0.04
                        )
                        .fill(
                            LinearGradient(
                                colors: [VeilTheme.gold.opacity(0.032), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        RadialGradient(
                            colors: [VeilTheme.gold.opacity(0.070), Color.clear],
                            center: UnitPoint(x: 0.95, y: 0.02),
                            startRadius: 0,
                            endRadius: 330
                        )

                        RadialGradient(
                            colors: [Color.white.opacity(0.018), Color.clear],
                            center: UnitPoint(x: 0.08, y: 0.76),
                            startRadius: 0,
                            endRadius: 260
                        )
                    }
                }
                .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
    }
}

/// Explicit-width vertical scroll host. The iOS 15 path never asks ScrollView to resolve a
/// nested maxWidth(.infinity) chain: viewport width is measured once outside the scroll content,
/// then the content receives a concrete width. This targets the whole-content horizontal jump /
/// disappearance seen on real iPhone 7 recordings while preserving centering on iPad/newer iOS.
struct VeilStableScrollView<Content: View>: View {
    let maxContentWidth: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    private let content: Content

    init(
        maxContentWidth: CGFloat = 760,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.maxContentWidth = maxContentWidth
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.content = content()
    }

    var body: some View {
        GeometryReader { viewport in
            let available = max(1, viewport.size.width - horizontalPadding * 2)
            let width = min(maxContentWidth, available)
            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: 0)
                    content
                        .frame(width: width, alignment: .top)
                    Spacer(minLength: 0)
                }
                .frame(width: max(1, viewport.size.width), alignment: .top)
                .padding(.vertical, verticalPadding)
            }
            .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
        }
    }
}

struct VeilCardModifier: ViewModifier {
    let emphasized: Bool

    init(emphasized: Bool = false) {
        self.emphasized = emphasized
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if VeilAppearanceController.shared.isAppleSoft {
            content
                .padding(16)
                .background(VeilAppleSoftSurface(cornerRadius: emphasized ? 28 : 23, emphasized: emphasized))
        } else if VeilAppearanceController.shared.isInstrument {
            content
                .padding(16)
                .background(VeilInstrumentPlate(shape: RoundedRectangle(cornerRadius: emphasized ? 22 : 18, style: .continuous), emphasized: emphasized))
        } else if VeilRenderProfile.usesLegacyCompositorPath {
            // Preserve the cut-panel identity, but avoid clip + duplicate-shape + large shadow
            // off-screen rendering inside ScrollView/Sheet on iPhone 7.
            content
                .padding(16)
                .background(
                    VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8)
                        .fill(emphasized ? VeilTheme.panel : VeilTheme.elevated)
                )
                .overlay(
                    VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8)
                        .stroke(emphasized ? VeilTheme.gold.opacity(0.22) : VeilTheme.hairline, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Rectangle()
                        .fill(emphasized ? VeilTheme.goldBright.opacity(0.50) : VeilTheme.hairline)
                        .frame(width: emphasized ? 30 : 16, height: 1)
                        .padding(.leading, 12)
                }
        } else {
            content
                .padding(16)
                .background(
                    ZStack {
                        VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8)
                            .fill(emphasized ? VeilTheme.panel : VeilTheme.elevated)
                        VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8)
                            .fill(VeilTheme.surfaceGradient)
                    }
                )
                .clipShape(VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8))
                .overlay(
                    VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8)
                        .stroke(emphasized ? VeilTheme.gold.opacity(0.24) : VeilTheme.hairline, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Rectangle()
                        .fill(emphasized ? VeilTheme.goldBright.opacity(0.58) : VeilTheme.hairline)
                        .frame(width: emphasized ? 34 : 18, height: 1)
                        .padding(.leading, 12)
                }
                .shadow(color: Color.black.opacity(0.26), radius: 16, x: 0, y: 8)
        }
    }
}

struct VeilGlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.modifier(VeilPlatformGlassSurfaceModifier(cornerRadius: cornerRadius, interactive: false))
    }
}

struct VeilPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let appleSoft = VeilAppearanceController.shared.isAppleSoft
        configuration.label
            .scaleEffect(pressed && !reduceMotion ? (appleSoft ? 0.982 : VeilMotionPolicy.pressScale) : 1)
            .offset(y: pressed ? (appleSoft ? 0.8 : (VeilAppearanceController.shared.isInstrument ? 2.5 : 1.4)) : 0)
            .brightness(pressed ? (appleSoft ? -0.018 : -0.035) : 0)
            .opacity(pressed ? (appleSoft ? 0.90 : 0.96) : 1)
            .shadow(
                color: Color.black.opacity(appleSoft ? (pressed ? 0.04 : 0.08) : (pressed ? 0.10 : (VeilMotionPolicy.allowsFullSpatialEffects ? 0.22 : 0.12))),
                radius: pressed ? 2 : (appleSoft ? 5 : (VeilMotionPolicy.allowsFullSpatialEffects ? 7 : 3)),
                x: 0,
                y: pressed ? 1 : (appleSoft ? 3 : (VeilMotionPolicy.allowsFullSpatialEffects ? 4 : 2))
            )
            .animation(reduceMotion ? nil : (appleSoft ? .easeOut(duration: 0.13) : VeilMotionPolicy.spring), value: pressed)
    }
}

/// A deterministic visual fingerprint generated only from an identity string. It is not a
/// cryptographic fingerprint and never leaves the UI layer; its purpose is fast visual recognition.
struct VeilIdentityGlyph: View {
    let seed: String
    var size: CGFloat = 44
    var active: Bool = false

    private var bits: [UInt8] {
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return (0..<8).map { UInt8((hash >> UInt64($0 * 8)) & 0xff) }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(VeilTheme.obsidian.opacity(0.94))
            Circle()
                .stroke(VeilTheme.hairline, lineWidth: 1)

            Circle()
                .trim(from: 0.04, to: 0.48 + CGFloat(bits[0] % 26) / 100)
                .stroke(
                    active ? VeilTheme.goldGradient : LinearGradient(colors: [VeilTheme.gold.opacity(0.70), VeilTheme.mutedGold], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 1.35, lineCap: .round)
                )
                .padding(size * 0.13)
                .rotationEffect(.degrees(Double(bits[1]) * 1.41))

            Circle()
                .trim(from: 0.08, to: 0.28 + CGFloat(bits[2] % 18) / 100)
                .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                .padding(size * 0.23)
                .rotationEffect(.degrees(Double(bits[3]) * 1.41))

            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == 0 && active ? VeilTheme.goldBright : VeilTheme.paleMetal.opacity(0.58))
                    .frame(width: 1.2, height: size * (0.15 + CGFloat(bits[4 + index] % 7) / 100))
                    .offset(y: -size * 0.29)
                    .rotationEffect(.degrees(Double((Int(bits[4 + index]) + index * 83) % 360)))
            }

            VeilDiamond()
                .fill(active ? VeilTheme.goldBright : VeilTheme.paleMetal.opacity(0.78))
                .frame(width: size * 0.15, height: size * 0.15)
                .rotationEffect(.degrees(Double(bits[7] % 4) * 45))
        }
        .frame(width: size, height: size)
        .shadow(
            color: active && VeilRenderProfile.allowsExpensiveVisualEffects ? VeilTheme.gold.opacity(0.20) : .clear,
            radius: VeilRenderProfile.allowsExpensiveVisualEffects ? 9 : 0
        )
        .accessibilityHidden(true)
    }
}

private struct VeilDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

/// A thin state thread. It only moves when communication/scanning is actually active.
struct VeilLinkTrace: View {
    let active: Bool
    var width: CGFloat = 90
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travels = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.065))
                .frame(height: 1)
            Capsule()
                .fill(VeilTheme.gold.opacity(active ? 0.42 : 0.10))
                .frame(width: width * 0.48, height: 1)
            if active {
                Circle()
                    .fill(VeilTheme.goldBright)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(
                        color: VeilRenderProfile.allowsExpensiveVisualEffects ? VeilTheme.gold.opacity(0.75) : .clear,
                        radius: VeilRenderProfile.allowsExpensiveVisualEffects ? 5 : 0
                    )
                    .offset(x: VeilRenderProfile.allowsPersistentAnimations ? (travels ? width - 4 : 0) : width * 0.70)
            }
        }
        .frame(width: width, height: 4)
        .onAppear { updateMotion() }
        .onChange(of: active) { _ in updateMotion() }
        .onChange(of: reduceMotion) { _ in updateMotion() }
    }

    private func updateMotion() {
        travels = false
        guard active, !reduceMotion, VeilRenderProfile.allowsPersistentAnimations else { return }
        withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
            travels = true
        }
    }
}

struct VeilResolveMark: View {
    let resolved: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(VeilTheme.gold.opacity(resolved ? 0.42 : 0.12), lineWidth: 1)
                .scaleEffect(expanded ? 1.34 : 0.76)
                .opacity(expanded ? 0 : 1)
            VeilDiamond()
                .fill(resolved ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                .frame(width: 4.5, height: 4.5)
        }
        .frame(width: 14, height: 14)
        .onAppear { resolve() }
        .onChange(of: resolved) { _ in resolve() }
    }

    private func resolve() {
        expanded = false
        guard resolved, !reduceMotion, VeilRenderProfile.allowsExpensiveVisualEffects else { return }
        withAnimation(VeilMotion.resolve) { expanded = true }
    }
}

struct VeilIconDisc: View {
    let systemName: String
    var size: CGFloat = 34
    var highlighted = false

    @ViewBuilder
    var body: some View {
        if VeilAppearanceController.shared.isAppleSoft {
            ZStack {
                Circle()
                    .fill(highlighted ? VeilTheme.gold.opacity(0.12) : VeilTheme.panelSoft)
                    .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
                    .shadow(color: Color.white.opacity(0.60), radius: 5, x: -3, y: -3)
                Circle()
                    .stroke(highlighted ? VeilTheme.gold.opacity(0.24) : VeilTheme.hairline, lineWidth: 0.8)
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(highlighted ? VeilTheme.goldBright : VeilTheme.secondaryText)
            }
            .frame(width: size, height: size)
        } else {
            ZStack {
                Circle()
                    .fill(highlighted ? VeilTheme.gold.opacity(0.14) : Color.white.opacity(0.038))
                Circle()
                    .stroke(highlighted ? VeilTheme.gold.opacity(0.30) : VeilTheme.hairline, lineWidth: 1)
                if highlighted {
                    Circle()
                        .trim(from: 0.04, to: 0.42)
                        .stroke(VeilTheme.goldBright.opacity(0.70), lineWidth: 1)
                        .rotationEffect(.degrees(-30))
                        .padding(2)
                }
                Image(systemName: systemName)
                    .font(.system(size: size * 0.43, weight: .semibold))
                    .foregroundColor(highlighted ? VeilTheme.goldBright : VeilTheme.secondaryText)
            }
            .frame(width: size, height: size)
        }
    }
}

extension View {
    func veilCard(emphasized: Bool = false) -> some View {
        modifier(VeilCardModifier(emphasized: emphasized))
    }

    func veilGlass(cornerRadius: CGFloat = 18) -> some View {
        modifier(VeilGlassModifier(cornerRadius: cornerRadius))
    }
}
