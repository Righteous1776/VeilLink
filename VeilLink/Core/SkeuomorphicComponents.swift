import SwiftUI

struct VeilInstrumentBackground: View {
    private var palette: VeilThemePalette { VeilAppearanceController.shared.palette }
    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.backgroundLift, palette.background], startPoint: .top, endPoint: .bottomTrailing)
            LinearGradient(
                colors: [Color.white.opacity(VeilAppearanceController.shared.systemIsDark ? 0.025 : 0.30), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            Rectangle()
                .fill(Color.black.opacity(VeilAppearanceController.shared.systemIsDark ? 0.11 : 0.025))
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct VeilInstrumentPlate<S: Shape>: View {
    let shape: S
    var emphasized = false
    private var palette: VeilThemePalette { VeilAppearanceController.shared.palette }

    var body: some View {
        shape
            .fill(LinearGradient(colors: [palette.metalTop, palette.metalBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(Color.white.opacity(VeilAppearanceController.shared.systemIsDark ? 0.07 : 0.55), lineWidth: 0.8))
            .overlay(shape.stroke(Color.black.opacity(0.24), lineWidth: emphasized ? 1.3 : 0.7).padding(1))
            .shadow(
                color: Color.black.opacity(VeilRenderProfile.allowsExpensiveVisualEffects ? (VeilAppearanceController.shared.systemIsDark ? 0.46 : 0.26) : 0),
                radius: emphasized ? 12 : 7,
                x: 0,
                y: emphasized ? 8 : 4
            )
    }
}

struct VeilPhysicalButtonStyle: ButtonStyle {
    var accent = false

    func makeBody(configuration: Configuration) -> some View {
        let palette = VeilAppearanceController.shared.palette
        configuration.label
            .foregroundColor(accent ? Color.white : palette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: accent ? [palette.goldBright, palette.goldDeep] : [palette.keycapTop, palette.keycapBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(configuration.isPressed ? 0.05 : 0.26), lineWidth: 0.8))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.32), lineWidth: 1).padding(2))
            .offset(y: configuration.isPressed ? 2.5 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.14 : 0.44), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 5)
            .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.77), value: configuration.isPressed)
    }
}

struct VeilIndicatorLamp: View {
    let active: Bool
    var color: Color? = nil

    var body: some View {
        let c = color ?? VeilAppearanceController.shared.palette.indicator
        Circle()
            .fill(active ? c : Color.black.opacity(0.30))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.6))
            .shadow(color: active ? c.opacity(0.75) : .clear, radius: 5)
    }
}

struct VeilSpeakerGrille: View {
    var columns = 9
    var rows = 6

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { _ in
                        Circle()
                            .fill(Color.black.opacity(VeilAppearanceController.shared.systemIsDark ? 0.66 : 0.55))
                            .frame(width: 3.6, height: 3.6)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct VeilLCDDisplay: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .opacity(0.55)
            Text(value)
                .font(.system(size: 19, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundColor(VeilAppearanceController.shared.systemIsDark ? Color(red: 0.71, green: 0.82, blue: 0.74) : Color(red: 0.12, green: 0.19, blue: 0.16))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VeilAppearanceController.shared.systemIsDark ? Color(red: 0.08, green: 0.10, blue: 0.09) : Color(red: 0.76, green: 0.80, blue: 0.74))
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.38), lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.38), radius: 3, x: 0, y: 2)
    }
}

struct VeilInstrumentKnob: View {
    var value: Double = 0.62

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [VeilAppearanceController.shared.palette.keycapTop, VeilAppearanceController.shared.palette.keycapBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Circle().stroke(Color.black.opacity(0.45), lineWidth: 2).padding(2)
            Capsule()
                .fill(Color.white.opacity(0.88))
                .frame(width: 3, height: 24)
                .offset(y: -21)
                .rotationEffect(.degrees(-135 + value * 270))
        }
        .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 6)
        .accessibilityHidden(true)
    }
}
