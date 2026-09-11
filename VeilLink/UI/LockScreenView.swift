import SwiftUI

struct LockScreenView: View {
    @ObservedObject var controller: AppLockController
    @State private var pin = ""
    private let columns = Array(repeating: GridItem(.fixed(72), spacing: 18), count: 3)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 42, weight: .light))
                .foregroundColor(VeilTheme.gold)
            Text("输入 VeilLink 密码")
                .font(.title3.weight(.semibold))
            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? VeilTheme.gold : Color.clear)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
                        .frame(width: 13, height: 13)
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
                    Task { _ = await controller.unlockWithBiometrics() }
                } label: {
                    Image(systemName: "touchid").font(.title2)
                }
                key("0")
                Button {
                    if !pin.isEmpty { pin.removeLast() }
                } label: {
                    Image(systemName: "delete.left").font(.title2)
                }
            }
            .foregroundColor(VeilTheme.text)
            Spacer()
        }
        .padding(24)
    }

    private func key(_ value: String) -> some View {
        Button {
            guard pin.count < 6 else { return }
            pin.append(value)
            if pin.count == 6 {
                if !controller.unlock(pin: pin) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pin = "" }
                }
            }
        } label: {
            Text(value)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.075))
                .clipShape(Circle())
        }
    }
}
