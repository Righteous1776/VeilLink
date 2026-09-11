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
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 54, weight: .light))
                    .foregroundColor(VeilTheme.gold)
                VStack(spacing: 8) {
                    Text("VeilLink")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("创建只属于这台设备的离线身份")
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

                Button {
                    guard password == confirmPassword else {
                        model.alertMessage = "两次输入的账户密码不一致。"
                        return
                    }
                    _ = model.createInitialProfile(name: name, password: password, pin: pin)
                } label: {
                    Text("创建加密身份")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canCreate ? VeilTheme.gold : VeilTheme.mutedGold.opacity(0.45))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
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
                        .background(VeilTheme.elevated)
                        .foregroundColor(VeilTheme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(VeilTheme.gold.opacity(0.25), lineWidth: 1)
                        )
                }

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

struct VeilTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(VeilTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}
