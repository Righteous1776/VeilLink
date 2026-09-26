import SwiftUI
import UIKit

extension VeilMorphVectorData {
    /// Three equal-length strokes so every state can interpolate without topology changes.
    static let activationSignal = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.18, y: 0.62), CGPoint(x: 0.31, y: 0.50), CGPoint(x: 0.44, y: 0.62)],
        [CGPoint(x: 0.34, y: 0.72), CGPoint(x: 0.50, y: 0.56), CGPoint(x: 0.66, y: 0.72)],
        [CGPoint(x: 0.52, y: 0.62), CGPoint(x: 0.69, y: 0.42), CGPoint(x: 0.82, y: 0.62)]
    ])

    static let activationShield = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.25, y: 0.27), CGPoint(x: 0.50, y: 0.18), CGPoint(x: 0.75, y: 0.27)],
        [CGPoint(x: 0.25, y: 0.27), CGPoint(x: 0.28, y: 0.62), CGPoint(x: 0.50, y: 0.80)],
        [CGPoint(x: 0.75, y: 0.27), CGPoint(x: 0.72, y: 0.62), CGPoint(x: 0.50, y: 0.80)]
    ])

    static let activationLink = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.20, y: 0.42), CGPoint(x: 0.34, y: 0.28), CGPoint(x: 0.49, y: 0.43)],
        [CGPoint(x: 0.38, y: 0.58), CGPoint(x: 0.50, y: 0.46), CGPoint(x: 0.62, y: 0.58)],
        [CGPoint(x: 0.51, y: 0.57), CGPoint(x: 0.66, y: 0.72), CGPoint(x: 0.80, y: 0.58)]
    ])

    static let activationNetwork = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.20, y: 0.64), CGPoint(x: 0.50, y: 0.26), CGPoint(x: 0.80, y: 0.64)],
        [CGPoint(x: 0.20, y: 0.64), CGPoint(x: 0.50, y: 0.74), CGPoint(x: 0.80, y: 0.64)],
        [CGPoint(x: 0.50, y: 0.26), CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.50, y: 0.74)]
    ])
}

struct VeilReleaseNeumorphicPlate<Content: View>: View {
    var emphasized = false
    var cornerRadius: CGFloat = 24
    private let content: Content

    init(
        emphasized: Bool = false,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.emphasized = emphasized
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(emphasized ? 0.19 : 0.11),
                                VeilTheme.gold.opacity(emphasized ? 0.28 : 0.12),
                                Color.black.opacity(0.34)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(emphasized ? 0.24 : 0.13))
                    .frame(width: emphasized ? 76 : 46, height: 1)
                    .padding(.top, 1)
                    .padding(.leading, 24)
            }
            .shadow(
                color: Color.black.opacity(VeilRenderProfile.usesLegacyCompositorPath ? 0.20 : 0.42),
                radius: VeilRenderProfile.usesLegacyCompositorPath ? 7 : 18,
                x: 8,
                y: 11
            )
            .shadow(
                color: VeilTheme.gold.opacity(VeilRenderProfile.usesLegacyCompositorPath ? 0.035 : (emphasized ? 0.10 : 0.045)),
                radius: VeilRenderProfile.usesLegacyCompositorPath ? 3 : 12,
                x: -5,
                y: -7
            )
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        VeilTheme.panelSoft.opacity(0.99),
                        VeilTheme.elevated.opacity(0.98),
                        VeilTheme.obsidian.opacity(0.995)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                    .stroke(Color.white.opacity(0.035), lineWidth: 3)
                    .padding(2)
                    .blendMode(.screen)
            )
    }
}

struct VeilReleasePrimaryButton: View {
    let title: String
    var systemImage = "arrow.right"
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(enabled ? 0.18 : 0.08))
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(width: 34, height: 34)
            }
            .foregroundColor(enabled ? VeilTheme.obsidian : VeilTheme.tertiaryText)
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: enabled
                                ? [VeilTheme.goldBright, VeilTheme.gold, VeilTheme.mutedGold]
                                : [VeilTheme.panelSoft, VeilTheme.elevated],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(enabled ? 0.45 : 0.08), lineWidth: 0.9)
                    .padding(1)
            )
            .shadow(color: enabled ? VeilTheme.gold.opacity(0.20) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(VeilPressStyle())
        .disabled(!enabled)
    }
}

struct VeilReleasePageDots: View {
    let page: Int
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(index == page ? VeilTheme.goldBright : Color.white.opacity(0.15))
                        .scaleEffect(x: index == page ? 1 : 0.32, y: 1, anchor: .center)
                        .opacity(index == page ? 1 : 0.78)
                }
                .frame(width: 19, height: 6)
                .animation(VeilMotionPolicy.spring, value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(page + 1) 页，共 \(count) 页")
    }
}

struct VeilReleaseFeatureRow: View {
    let icon: String
    let title: String
    let detail: String
    var highlighted = false

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VeilIconDisc(systemName: icon, size: 38, highlighted: highlighted)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(VeilTheme.text)
                Text(detail)
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

struct VeilActivationMorphCore: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var morphs = false
    @State private var rotates = false
    @State private var pulse = false

    var compact = false

    var body: some View {
        let size: CGFloat = compact ? 116 : 154
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VeilTheme.gold.opacity(0.16), VeilTheme.panelSoft.opacity(0.88), VeilTheme.obsidian],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.68
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.52), radius: compact ? 12 : 24, x: 10, y: 15)
                .shadow(color: VeilTheme.gold.opacity(0.13), radius: compact ? 8 : 18, x: -7, y: -9)

            Circle()
                .trim(from: 0.04, to: 0.42)
                .stroke(VeilTheme.goldGradient, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .padding(compact ? 10 : 13)
                .rotationEffect(.degrees(rotates ? 360 : 0))

            Circle()
                .trim(from: 0.58, to: 0.84)
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                .padding(compact ? 19 : 24)
                .rotationEffect(.degrees(rotates ? -360 : 0))

            VeilMorphIcon(
                from: .activationSignal,
                to: .activationShield,
                toggled: morphs,
                size: compact ? 44 : 58,
                color: VeilTheme.goldBright,
                lineWidth: compact ? 2.3 : 2.7
            )
            .scaleEffect(pulse && !reduceMotion ? 1.025 : 1)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.82)) { morphs = true }
            guard VeilMotionPolicy.allowsContinuousDecorativeMotion else { return }
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) { rotates = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

struct VeilOnboardingHaptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func confirm() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
