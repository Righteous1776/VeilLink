import SwiftUI

/// Shared skeuomorphic game chrome. This layer is intentionally presentation-only:
/// no game rule, wire protocol, replay or persistence semantics are changed here.
struct VeilGameCabinetRow: View {
    let game: MiniGameKind
    let detail: String
    let status: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                VeilInstrumentPlate(
                    shape: RoundedRectangle(cornerRadius: 13, style: .continuous),
                    emphasized: enabled
                )
                Image(systemName: game.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(enabled ? VeilTheme.goldBright : VeilTheme.tertiaryText)
            }
            .frame(width: 48, height: 48)
            .overlay(alignment: .topLeading) {
                VeilCabinetScrew()
                    .offset(x: 5, y: 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    VeilIndicatorLamp(active: enabled, color: VeilTheme.goldBright)
                    Text(game.title)
                        .font(.headline)
                        .foregroundColor(enabled ? VeilTheme.text : VeilTheme.secondaryText)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                Text(status)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.tertiaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                    )
                Image(systemName: enabled ? "chevron.right" : "lock.fill")
                    .font(.caption.bold())
                    .foregroundColor(VeilTheme.tertiaryText)
            }
        }
        .padding(12)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 15, style: .continuous),
                emphasized: enabled
            )
        )
        .overlay(alignment: .topTrailing) {
            VeilCabinetScrew()
                .offset(x: -6, y: 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(VeilTheme.hairline, lineWidth: 0.8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue(enabled ? "可以开始人机对局" : "尚未开放")
    }
}

private struct VeilCabinetScrew: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.black.opacity(0.34)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Capsule()
                .fill(Color.black.opacity(0.46))
                .frame(width: 5, height: 1)
                .rotationEffect(.degrees(-18))
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
}

private struct VeilGameConsoleModifier: ViewModifier {
    let emphasized: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(
                VeilInstrumentPlate(
                    shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    emphasized: emphasized
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(VeilTheme.hairline, lineWidth: 0.8)
            )
            .overlay(alignment: .topLeading) {
                VeilCabinetScrew().offset(x: 7, y: 7)
            }
            .overlay(alignment: .bottomTrailing) {
                VeilCabinetScrew().offset(x: -7, y: -7)
            }
    }
}

extension View {
    func veilGameConsole(emphasized: Bool = false, cornerRadius: CGFloat = 18) -> some View {
        modifier(VeilGameConsoleModifier(emphasized: emphasized, cornerRadius: cornerRadius))
    }
}
