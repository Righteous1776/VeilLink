import SwiftUI

struct LockScreenView: View {
    @ObservedObject var controller: AppLockController
    @ObservedObject var haptics: HapticEngine
    @State private var pin = ""
    private let columns = Array(repeating: GridItem(.fixed(72), spacing: 18), count: 3)

    var body: some View {
        ZStack {
            VeilAmbientBackground()
            VStack(spacing: 24) {
            Spacer()
            VeilIdentityGlyph(seed: "VeilLink/Locked/Local", size: 78, active: true)
            VStack(spacing: 4) {
                Text("VEIL // LOCKED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(VeilTheme.mutedGold)
                Text("输入 VeilLink 密码")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
            }
            HStack(spacing: 16) {
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
                Text(error).font(.footnote).foregroundColor(VeilTheme.danger)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach([1,2,3,4,5,6,7,8,9], id: \.self) { digit in
                    key(String(digit))
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
                    VeilIconDisc(systemName: "touchid", size: 58, highlighted: true)
                }
                .buttonStyle(VeilPressStyle())
                key("0")
                Button {
                    if !pin.isEmpty {
                        pin.removeLast()
                        haptics.selection()
                    }
                } label: {
                    VeilIconDisc(systemName: "delete.left", size: 58)
                }
                .buttonStyle(VeilPressStyle())
            }
            .foregroundColor(VeilTheme.text)
            Spacer()
            }
            .padding(24)
        }
    }

    private func key(_ value: String) -> some View {
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
                .font(.system(size: 27, weight: .regular, design: .rounded))
                .frame(width: 68, height: 68)
                .background(VeilTheme.elevated.opacity(0.78))
                .clipShape(VeilPanelShape(cut: 11, radius: 7))
                .overlay(
                    VeilPanelShape(cut: 11, radius: 7)
                        .stroke(VeilTheme.hairline, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Rectangle().fill(VeilTheme.gold.opacity(0.22)).frame(width: 13, height: 1).padding(.leading, 7)
                }
        }
        .buttonStyle(VeilPressStyle())
    }
}
