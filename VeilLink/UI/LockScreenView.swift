import SwiftUI

struct LockScreenView: View {
    @ObservedObject var controller: AppLockController
    @ObservedObject var haptics: HapticEngine
    @ObservedObject private var appearance = VeilAppearanceController.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var pin = ""

    var body: some View {
        GeometryReader { proxy in
            let horizontal = VeilUILayoutPolicy.lockUsesHorizontalLayout(size: proxy.size)
            let keySize = VeilUILayoutPolicy.lockKeySize(size: proxy.size)
            let gridSpacing: CGFloat = horizontal ? 9 : 16

            ZStack {
                VeilAmbientBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if horizontal {
                            HStack(spacing: 24) {
                                identityBlock(compact: true)
                                    .frame(maxWidth: .infinity)
                                keypad(keySize: keySize, spacing: gridSpacing)
                                    .frame(width: min(228, proxy.size.width * 0.48))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        } else {
                            VStack(spacing: 20) {
                                Spacer(minLength: 8)
                                identityBlock(compact: false)
                                keypad(keySize: keySize, spacing: gridSpacing)
                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                        }
                    }
                    .frame(minHeight: max(1, proxy.size.height - 1))
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func identityBlock(compact: Bool) -> some View {
        VStack(spacing: compact ? 11 : 18) {
            VeilIdentityGlyph(seed: "VeilLink/Locked/Local", size: compact ? 58 : 78, active: true)
            VStack(spacing: 4) {
                Text("VEIL // LOCKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(VeilTheme.mutedGold)
                Text("输入 VeilLink 密码")
                    .font(.system(compact ? .headline : .title3, design: .rounded).weight(.semibold))
            }
            HStack(spacing: compact ? 11 : 16) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? VeilTheme.goldBright : Color.clear)
                        .overlay(Circle().stroke(index < pin.count ? VeilTheme.gold.opacity(0.52) : VeilTheme.hairline, lineWidth: 1.2))
                        .frame(width: 12, height: 12)
                        .shadow(color: index < pin.count ? VeilTheme.gold.opacity(0.32) : .clear, radius: 5)
                }
            }
            .frame(height: 22)

            if let error = controller.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(VeilTheme.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { appearance.update(colorScheme: colorScheme) }
        .onChange(of: colorScheme) { appearance.update(colorScheme: $0) }
    }

    private func keypad(keySize: CGFloat, spacing: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach([1,2,3,4,5,6,7,8,9], id: \.self) { digit in
                key(String(digit), size: keySize)
            }
            Button {
                Task {
                    if await controller.unlockWithBiometrics() {
                        haptics.resolved()
                    } else {
                        haptics.error()
                    }
                }
            } label: {
                VeilIconDisc(systemName: "touchid", size: max(42, keySize - 10), highlighted: true)
            }
            .buttonStyle(VeilPressStyle())
            .frame(width: keySize, height: keySize)

            key("0", size: keySize)

            Button {
                if !pin.isEmpty {
                    pin.removeLast()
                    haptics.selection()
                }
            } label: {
                VeilIconDisc(systemName: "delete.left", size: max(42, keySize - 10))
            }
            .buttonStyle(VeilPressStyle())
            .frame(width: keySize, height: keySize)
        }
        .foregroundColor(VeilTheme.text)
        .frame(maxWidth: 270)
    }

    private func key(_ value: String, size: CGFloat) -> some View {
        Button {
            guard pin.count < 6 else { return }
            pin.append(value)
            haptics.selection()
            if pin.count == 6 {
                if controller.unlock(pin: pin) {
                    haptics.resolved()
                } else {
                    haptics.error()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pin = "" }
                }
            }
        } label: {
            Text(value)
                .font(.system(size: size >= 60 ? 27 : 22, weight: .regular, design: .rounded))
                .foregroundColor(VeilTheme.text)
                .frame(width: size, height: size)
                .background(lockKeySurface)
        }
        .buttonStyle(VeilPressStyle())
    }

    @ViewBuilder
    private var lockKeySurface: some View {
        if appearance.isAppleSoft {
            VeilAppleSoftSurface(cornerRadius: 22, emphasized: false)
        } else if appearance.isInstrument {
            VeilInstrumentPlate(shape: RoundedRectangle(cornerRadius: 18, style: .continuous), emphasized: false)
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VeilTheme.elevated.opacity(0.90))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(VeilTheme.hairline, lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(VeilRenderProfile.usesLegacyCompositorPath ? 0.08 : 0.14),
                    radius: VeilRenderProfile.usesLegacyCompositorPath ? 2 : 7,
                    x: 0,
                    y: VeilRenderProfile.usesLegacyCompositorPath ? 1 : 4
                )
        }
    }
}
