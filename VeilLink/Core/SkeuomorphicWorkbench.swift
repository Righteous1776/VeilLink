import SwiftUI

/// Shared modern-skeuomorphic primitives for VeilLink tools, games and tactical surfaces.
/// They deliberately degrade to flat, low-cost drawing when the render policy disables
/// expensive spatial effects, so iPhone 7 class hardware keeps the same hierarchy without
/// paying for blur-heavy decoration.
struct VeilScrewHead: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), Color.black.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Capsule()
                .fill(Color.black.opacity(0.55))
                .frame(width: 7, height: 1.1)
                .rotationEffect(.degrees(-18))
        }
        .frame(width: 10, height: 10)
        .accessibilityHidden(true)
    }
}

struct VeilInstrumentDeck<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    var emphasized = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VeilTheme.goldBright)
                }
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(VeilTheme.text)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                VeilIndicatorLamp(active: true)
            }

            content()
        }
        .padding(14)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                emphasized: emphasized
            )
        )
        .overlay(alignment: .topLeading) {
            VeilScrewHead().padding(7)
        }
        .overlay(alignment: .topTrailing) {
            VeilScrewHead().padding(7)
        }
        .overlay(alignment: .bottomLeading) {
            VeilScrewHead().padding(7)
        }
        .overlay(alignment: .bottomTrailing) {
            VeilScrewHead().padding(7)
        }
    }
}

struct VeilRecessedWell<Content: View>: View {
    var cornerRadius: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.24 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.30), lineWidth: 1.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(2, cornerRadius - 2), style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                    .padding(2)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: -1)
    }
}

struct VeilInstrumentLabel: View {
    let title: String
    let value: String
    var active = true

    var body: some View {
        HStack(spacing: 7) {
            VeilIndicatorLamp(active: active)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 7.5, weight: .black, design: .monospaced))
                    .tracking(0.9)
                    .foregroundColor(VeilTheme.tertiaryText)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(VeilTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct VeilGaugeMeter: View {
    let title: String
    let value: Double
    let text: String

    private var bounded: Double { min(1, max(0, value)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundColor(VeilTheme.tertiaryText)
                Spacer()
                Text(text)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(VeilTheme.text)
            }
            GeometryReader { proxy in
                let width = max(0, proxy.size.width * bounded)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.34))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [VeilTheme.goldDeep, VeilTheme.goldBright],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width)
                }
            }
            .frame(height: 7)
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.6))
        }
        .accessibilityElement(children: .combine)
    }
}

struct VeilHardwareSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var suffix = ""

    private var normalized: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }

    var body: some View {
        HStack(spacing: 10) {
            VeilInstrumentKnob(value: normalized)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundColor(VeilTheme.tertiaryText)
                    Spacer()
                    Text("\(Int(value.rounded()))\(suffix)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.goldBright)
                }

                GeometryReader { proxy in
                    let trackWidth = max(1, proxy.size.width)
                    let knobX = CGFloat(normalized) * trackWidth
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.38))
                            .frame(height: 9)
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.6))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [VeilTheme.goldDeep, VeilTheme.goldBright],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(5, knobX), height: 5)
                            .padding(.horizontal, 2)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [VeilTheme.paleMetal, VeilTheme.panel],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 1.2))
                            .frame(width: 20, height: 20)
                            .offset(x: min(max(-1, knobX - 10), max(-1, trackWidth - 19)))
                            .shadow(
                                color: Color.black.opacity(VeilMotionPolicy.allowsFullSpatialEffects ? 0.38 : 0),
                                radius: VeilMotionPolicy.allowsFullSpatialEffects ? 4 : 0,
                                y: VeilMotionPolicy.allowsFullSpatialEffects ? 3 : 0
                            )
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                updateValue(locationX: gesture.location.x, width: trackWidth)
                            }
                    )
                }
                .frame(height: 24)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.18 : 0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value.rounded()))\(suffix)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(range.upperBound, snapped(value + step))
            case .decrement:
                value = max(range.lowerBound, snapped(value - step))
            @unknown default:
                break
            }
        }
    }

    private func updateValue(locationX: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let fraction = min(1, max(0, Double(locationX / width)))
        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        value = min(range.upperBound, max(range.lowerBound, snapped(raw)))
    }

    private func snapped(_ input: Double) -> Double {
        guard step > 0 else { return input }
        let units = ((input - range.lowerBound) / step).rounded()
        return range.lowerBound + units * step
    }
}

struct VeilToggleLever: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.text)
                    Text(isOn ? "ENGAGED" : "STANDBY")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(isOn ? VeilTheme.gold : VeilTheme.tertiaryText)
                }
                Spacer()
                ZStack {
                    Capsule()
                        .fill(Color.black.opacity(0.38))
                        .frame(width: 52, height: 24)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [VeilTheme.paleMetal, VeilTheme.panel],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 24, height: 20)
                        .offset(x: isOn ? 12 : -12)
                        .shadow(color: Color.black.opacity(0.38), radius: 3, y: 2)
                    VeilIndicatorLamp(active: isOn)
                        .offset(x: isOn ? -15 : 15)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.16 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "开启" : "关闭")
    }
}

struct VeilInstrumentRackSection<Content: View>: View {
    let title: String
    let subtitle: String
    let code: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VeilInstrumentDeck(
            title: title,
            subtitle: subtitle,
            symbol: "shippingbox.fill"
        ) {
            HStack {
                Text(code.uppercased())
                    .font(.system(size: 7.5, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(VeilTheme.mutedGold)
                Spacer()
                Text("LOCAL / OFFLINE")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
            }
            content()
        }
    }
}


private struct VeilInstrumentFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        VeilAppearanceController.shared.isDarkAppearance
                        ? Color(red: 0.075, green: 0.085, blue: 0.08)
                        : Color(red: 0.82, green: 0.83, blue: 0.78)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.40), lineWidth: 1.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
                    .padding(2)
            )
            .foregroundColor(VeilTheme.text)
    }
}

extension View {
    func veilInstrumentField() -> some View {
        modifier(VeilInstrumentFieldModifier())
    }
}


enum VeilInstrumentBayRole {
    case input
    case output
    case status

    var label: String {
        switch self {
        case .input: return "INPUT"
        case .output: return "OUTPUT"
        case .status: return "STATUS"
        }
    }

    var symbol: String {
        switch self {
        case .input: return "arrow.down.to.line.compact"
        case .output: return "arrow.up.from.line.compact"
        case .status: return "waveform.path.ecg"
        }
    }
}

struct VeilInstrumentBay<Content: View>: View {
    let title: String
    let role: VeilInstrumentBayRole
    var active = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: role.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(VeilTheme.gold)
                Text(role.label)
                    .font(.system(size: 7.5, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundColor(VeilTheme.mutedGold)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.text)
                Spacer()
                VeilIndicatorLamp(active: active)
            }

            VeilRecessedWell(cornerRadius: 11) {
                content()
            }
        }
        .padding(11)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                emphasized: false
            )
        )
        .overlay(alignment: .topTrailing) {
            VeilScrewHead().padding(5)
        }
    }
}

struct VeilStatusStrip: View {
    let leftTitle: String
    let leftValue: String
    let rightTitle: String
    let rightValue: String
    var active = true

    var body: some View {
        HStack(spacing: 10) {
            VeilInstrumentLabel(title: leftTitle, value: leftValue, active: active)
            Spacer(minLength: 8)
            VeilInstrumentLabel(title: rightTitle, value: rightValue, active: active)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(VeilAppearanceController.shared.isDarkAppearance ? 0.20 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
        )
    }
}


struct VeilCompactKeyStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: selected ? .bold : .semibold, design: .rounded))
            .foregroundColor(selected ? VeilTheme.goldBright : VeilTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: selected
                                ? [VeilTheme.keycapTop, VeilTheme.goldDeep.opacity(0.42)]
                                : [VeilTheme.keycapTop, VeilTheme.keycapBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        selected ? VeilTheme.gold.opacity(0.48) : Color.white.opacity(0.10),
                        lineWidth: selected ? 1.1 : 0.7
                    )
            )
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .shadow(
                color: Color.black.opacity(VeilMotionPolicy.allowsFullSpatialEffects ? 0.30 : 0),
                radius: configuration.isPressed ? 1 : 3,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
    }
}
