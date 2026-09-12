import SwiftUI
import Foundation
import Darwin

/// VeilLink visual system.
///
/// The language is intentionally not "generic cyberpunk": near-black veils hide information,
/// identity is represented by deterministic local glyphs, warm metal only appears around trust
/// and action, and motion has three meanings only: Reveal, Transit and Resolve.
enum VeilTheme {
    static let background = Color(red: 0.012, green: 0.013, blue: 0.017)
    static let backgroundLift = Color(red: 0.026, green: 0.027, blue: 0.034)
    static let elevated = Color(red: 0.045, green: 0.046, blue: 0.056)
    static let panel = Color(red: 0.070, green: 0.069, blue: 0.080)
    static let panelSoft = Color(red: 0.095, green: 0.091, blue: 0.102)
    static let obsidian = Color(red: 0.020, green: 0.021, blue: 0.026)
    static let veil = Color(red: 0.032, green: 0.030, blue: 0.038)

    static let gold = Color(red: 0.86, green: 0.64, blue: 0.24)
    static let goldBright = Color(red: 0.98, green: 0.82, blue: 0.46)
    static let goldDeep = Color(red: 0.48, green: 0.31, blue: 0.09)
    static let mutedGold = Color(red: 0.52, green: 0.40, blue: 0.21)
    static let paleMetal = Color(red: 0.78, green: 0.75, blue: 0.68)

    static let text = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.57)
    static let tertiaryText = Color.white.opacity(0.32)
    static let hairline = Color.white.opacity(0.072)
    static let danger = Color(red: 0.91, green: 0.28, blue: 0.28)
    static let success = Color(red: 0.35, green: 0.80, blue: 0.55)

    static let goldGradient = LinearGradient(
        colors: [goldBright, gold, goldDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let metalGradient = LinearGradient(
        colors: [Color.white.opacity(0.72), paleMetal, gold.opacity(0.78), goldDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surfaceGradient = LinearGradient(
        colors: [Color.white.opacity(0.040), Color.white.opacity(0.010)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let incomingBubbleGradient = LinearGradient(
        colors: [panelSoft, panel, obsidian],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}


/// Hardware/OS render capability gate. iPhone 7 / 7 Plus on iOS 15 use an older
/// SwiftUI compositor path that can invalidate large clipped/shadowed scroll layers while
/// repeat-forever animations are active. Keep the visual language, but switch persistent motion
/// and expensive off-screen composition to a lighter path on that exact device family.
enum VeilRenderProfile {
    static let machineIdentifier: String = {
        var info = utsname()
        guard uname(&info) == 0 else { return "unknown" }
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }()

    static var usesLegacyCompositorPath: Bool {
        RenderCompatibilityPolicy.shouldUseLegacyCompositor(
            machineIdentifier: machineIdentifier,
            osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }
}

enum VeilMotion {
    static let reveal = Animation.easeOut(duration: 0.24)
    static let transit = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.84)
    static let resolve = Animation.spring(response: 0.42, dampingFraction: 0.72)
}

/// Asymmetric panel geometry used throughout VeilLink. The cuts deliberately replace generic
/// rounded cards with a more terminal-like silhouette without becoming sharp or hostile.
struct VeilPanelShape: Shape {
    var cut: CGFloat = 16
    var radius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
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
            if VeilRenderProfile.usesLegacyCompositorPath {
                // iPhone 7 / iOS 15: avoid GeometryReader-driven multi-layer composition.
                ZStack {
                    LinearGradient(
                        colors: [VeilTheme.backgroundLift, VeilTheme.background, Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [VeilTheme.gold.opacity(0.045), Color.clear],
                        center: UnitPoint(x: 0.94, y: 0.04),
                        startRadius: 0,
                        endRadius: 280
                    )
                }
            } else {
                GeometryReader { geometry in
                    ZStack {
                        LinearGradient(
                            colors: [VeilTheme.backgroundLift, VeilTheme.background, Color.black],
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
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct VeilCardModifier: ViewModifier {
    let emphasized: Bool

    init(emphasized: Bool = false) {
        self.emphasized = emphasized
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if VeilRenderProfile.usesLegacyCompositorPath {
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

    @ViewBuilder
    func body(content: Content) -> some View {
        if VeilRenderProfile.usesLegacyCompositorPath {
            content
                .background(VeilTheme.elevated.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(VeilTheme.hairline, lineWidth: 1)
                )
        } else {
            content
                .background(VeilTheme.elevated.opacity(0.90))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(VeilTheme.hairline, lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.11), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
        }
    }
}

struct VeilPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion && !VeilRenderProfile.usesLegacyCompositorPath ? 0.968 : 1)
            .opacity(configuration.isPressed ? 0.80 : 1)
            .animation((reduceMotion || VeilRenderProfile.usesLegacyCompositorPath) ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
            color: active && !VeilRenderProfile.usesLegacyCompositorPath ? VeilTheme.gold.opacity(0.20) : .clear,
            radius: VeilRenderProfile.usesLegacyCompositorPath ? 0 : 9
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
                        color: VeilRenderProfile.usesLegacyCompositorPath ? .clear : VeilTheme.gold.opacity(0.75),
                        radius: VeilRenderProfile.usesLegacyCompositorPath ? 0 : 5
                    )
                    .offset(x: VeilRenderProfile.usesLegacyCompositorPath ? width * 0.70 : (travels ? width - 4 : 0))
            }
        }
        .frame(width: width, height: 4)
        .onAppear { updateMotion() }
        .onChange(of: active) { _ in updateMotion() }
        .onChange(of: reduceMotion) { _ in updateMotion() }
    }

    private func updateMotion() {
        travels = false
        guard active, !reduceMotion, !VeilRenderProfile.usesLegacyCompositorPath else { return }
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
        guard resolved, !reduceMotion, !VeilRenderProfile.usesLegacyCompositorPath else { return }
        withAnimation(VeilMotion.resolve) { expanded = true }
    }
}

struct VeilIconDisc: View {
    let systemName: String
    var size: CGFloat = 34
    var highlighted = false

    var body: some View {
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

extension View {
    func veilCard(emphasized: Bool = false) -> some View {
        modifier(VeilCardModifier(emphasized: emphasized))
    }

    func veilGlass(cornerRadius: CGFloat = 18) -> some View {
        modifier(VeilGlassModifier(cornerRadius: cornerRadius))
    }
}
