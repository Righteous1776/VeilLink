import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var pin = ""
    @State private var showsImporter = false
    @State private var restoreURL: URL?
    @State private var showsRestorePassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 36)
                VeilOnboardingMark()
                    .frame(width: 88, height: 88)
                VStack(spacing: 7) {
                    HStack(spacing: 8) {
                        Text("VEIL")
                            .foregroundColor(VeilTheme.text)
                        Text("//")
                            .foregroundColor(VeilTheme.mutedGold)
                        Text("LINK")
                            .foregroundColor(VeilTheme.goldBright)
                    }
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("PRIVATE  /  NEARBY  /  SERVERLESS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("创建只属于这台设备的离线身份")
                        .font(.subheadline)
                        .foregroundColor(VeilTheme.secondaryText)
                }

                VStack(spacing: 14) {
                    TextField("用户名", text: $name)
                        .textContentType(.nickname)
                    SecureField("账户密码（至少 8 位）", text: $password)
                        .textContentType(.newPassword)
                    SecureField("确认账户密码", text: $confirmPassword)
                        .textContentType(.newPassword)
                    SecureField("6 位应用锁密码", text: $pin)
                        .keyboardType(.numberPad)
                        .onChange(of: pin) { value in
                            pin = String(value.filter { "0123456789".contains($0) }.prefix(6))
                        }
                }
                .textFieldStyle(VeilTextFieldStyle())
                .padding(16)
                .veilGlass(cornerRadius: 20)

                Button {
                    guard password == confirmPassword else {
                        model.alertMessage = "两次输入的账户密码不一致。"
                        return
                    }
                    _ = model.createInitialProfile(name: name, password: password, pin: pin)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                        Text("创建加密身份")
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canCreate ? VeilTheme.goldGradient : LinearGradient(colors: [VeilTheme.panel, VeilTheme.panel], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(canCreate ? Color.black.opacity(0.90) : VeilTheme.tertiaryText)
                    .clipShape(VeilPanelShape(cut: 12, radius: 7))
                    .overlay(
                        VeilPanelShape(cut: 12, radius: 7)
                            .stroke(canCreate ? Color.white.opacity(0.12) : VeilTheme.hairline, lineWidth: 1)
                    )
                    .shadow(color: canCreate ? VeilTheme.gold.opacity(0.18) : .clear, radius: 12, x: 0, y: 6)
                }
                .buttonStyle(VeilPressStyle())
                .disabled(!canCreate)

                HStack(spacing: 12) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    Text("或")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }

                Button {
                    showsImporter = true
                } label: {
                    Label("从加密备份恢复", systemImage: "arrow.counterclockwise.circle")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(VeilTheme.elevated.opacity(0.82))
                        .foregroundColor(VeilTheme.goldBright)
                        .clipShape(VeilPanelShape(cut: 12, radius: 7))
                        .overlay(
                            VeilPanelShape(cut: 12, radius: 7)
                                .stroke(VeilTheme.gold.opacity(0.20), lineWidth: 1)
                        )
                }
                .buttonStyle(VeilPressStyle())

                Text("账户密码保护本地身份；完整备份使用你单独设置的备份密码。六位密码只用于本机应用锁。完全离线意味着这些密码无法通过服务器找回。")
                    .font(.footnote)
                    .foregroundColor(VeilTheme.secondaryText)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 36)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(VeilAmbientBackground())
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.zip]) { result in
            switch result {
            case .success(let url):
                restoreURL = url
                showsRestorePassword = true
            case .failure(let error):
                model.alertMessage = "无法选择备份：\(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showsRestorePassword) {
            BackupPasswordSheet(title: "恢复加密备份", actionTitle: "验证并恢复") { backupPassword in
                if let restoreURL { model.restoreBackup(url: restoreURL, password: backupPassword) }
            }
        }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 8 && password == confirmPassword && pin.utf8.count == 6
    }
}

private struct VeilOnboardingMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            VeilIdentityGlyph(seed: "VeilLink/Genesis/Identity", size: 88, active: true)
                .scaleEffect(revealed ? 1 : 0.88)
                .opacity(revealed ? 1 : 0.25)

            VeilPanelShape(cut: 10, radius: 4)
                .stroke(VeilTheme.goldBright.opacity(0.34), lineWidth: 1)
                .frame(width: 44, height: 16)
                .rotationEffect(.degrees(-42))
                .offset(x: revealed ? 18 : 4, y: -20)
                .opacity(revealed ? 0.85 : 0)

            VeilPanelShape(cut: 8, radius: 4)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: 34, height: 12)
                .rotationEffect(.degrees(-42))
                .offset(x: revealed ? -18 : -4, y: 22)
                .opacity(revealed ? 0.75 : 0)
        }
        .shadow(color: VeilTheme.gold.opacity(0.16), radius: 18)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(VeilMotion.reveal) { revealed = true }
            }
        }
    }
}

struct VeilTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.black.opacity(0.16))
            .clipShape(VeilPanelShape(cut: 9, radius: 6))
            .overlay(
                VeilPanelShape(cut: 9, radius: 6)
                    .stroke(VeilTheme.hairline, lineWidth: 1)
            )
    }
}
