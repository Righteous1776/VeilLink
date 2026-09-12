import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ownerMode: OwnerModeController
    @ObservedObject var identity: IdentityManager
    @ObservedObject var haptics: HapticEngine
    @State private var versionTapCount = 0
    @State private var showsLockSheet = false
    @State private var showsIdentityManager = false
    @State private var showsBackupSheet = false
    @State private var showsImporter = false
    @State private var restoreURL: URL?
    @State private var showsRestorePassword = false
    @State private var showsOwnerUnlock = false
    @State private var showsOwnerConsole = false

    init(model: AppModel) {
        self.model = model
        ownerMode = model.ownerMode
        identity = model.identity
        haptics = model.haptics
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                securityCard
                storageCard
                mediaCard
                feedbackCard
                bluetoothCard
                versionFooter
            }
            .frame(maxWidth: 760)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("设置")
        .sheet(isPresented: $showsLockSheet) {
            LockConfigurationSheet(controller: model.appLock)
        }
        .sheet(isPresented: $showsIdentityManager) {
            IdentityManagementSheet(model: model)
        }
        .sheet(isPresented: $showsBackupSheet) {
            BackupPasswordSheet { password in
                model.exportBackup(password: password)
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.zip]) { result in
            if case .success(let url) = result {
                restoreURL = url
                showsRestorePassword = true
            }
        }
        .sheet(isPresented: $showsRestorePassword) {
            BackupPasswordSheet(title: "恢复加密备份", actionTitle: "验证并恢复") { password in
                if let restoreURL { model.restoreBackup(url: restoreURL, password: password) }
            }
        }
        .sheet(isPresented: Binding(
            get: { model.exportedBackupURL != nil },
            set: { if !$0 { model.exportedBackupURL = nil } }
        )) {
            if let url = model.exportedBackupURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showsOwnerUnlock) {
            OwnerUnlockSheet(model: model) {
                showsOwnerConsole = true
            }
        }
        .sheet(isPresented: $showsOwnerConsole) {
            OwnerConsoleView(model: model)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                VeilIdentityGlyph(seed: identity.activeIdentity?.id ?? "veillink-unset", size: 54, active: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCAL IDENTITY")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.25)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text(identity.activeIdentity?.displayName ?? "未创建")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    HStack(spacing: 7) {
                        Text(String((identity.activeIdentity?.id ?? "offline").prefix(12)).uppercased())
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(VeilTheme.secondaryText)
                        VeilLinkTrace(active: true, width: 34)
                    }
                }
                Spacer()
            }

            Text(identity.activeIdentity?.id ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(VeilTheme.tertiaryText)
                .textSelection(.enabled)
                .lineLimit(1)

            HStack {
                Text("设备ID")
                Spacer()
                Text(String(identity.deviceID.prefix(8)).uppercased())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Divider().background(Color.white.opacity(0.07))
            settingButton(
                title: "管理本地身份",
                detail: "\(identity.profiles.count)/\(IdentityManager.profileLimit) · 创建或安全切换",
                icon: "person.2"
            ) { showsIdentityManager = true }
        }
        .veilCard(emphasized: true)
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("安全", systemImage: "lock.shield")
                .font(.headline).foregroundColor(VeilTheme.goldBright)
            settingButton(
                title: "应用锁",
                detail: model.appLock.isEnabled ? "六位密码与生物识别已启用" : "尚未启用",
                icon: "lock.fill"
            ) { showsLockSheet = true }
            Divider().background(Color.white.opacity(0.07))
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("内容加密").fontWeight(.medium)
                    Text("ChaCha20-Poly1305 · Curve25519")
                        .font(.caption).foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
            }
        }
        .veilCard()
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("数据与备份", systemImage: "externaldrive")
                .font(.headline).foregroundColor(VeilTheme.goldBright)
            settingButton(title: "导出加密ZIP", detail: "保存到文件或分享", icon: "square.and.arrow.up") {
                showsBackupSheet = true
            }
            Divider().background(Color.white.opacity(0.07))
            settingButton(title: "恢复备份", detail: "导入身份、对话与附件", icon: "arrow.counterclockwise") {
                showsImporter = true
            }
            HStack {
                Text("SQLite完整性")
                Spacer()
                Text(model.database.integrityCheck())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
        .veilCard()
    }

    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("图片", systemImage: "photo.on.rectangle")
                .font(.headline).foregroundColor(VeilTheme.goldBright)
            Toggle(isOn: $model.autoSaveReceivedImages) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动保存收到的图片").fontWeight(.medium)
                    Text("完整性校验通过后自动加入系统照片；默认关闭。")
                        .font(.caption).foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
        }
        .veilCard()
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("触感反馈", systemImage: "waveform.path")
                .font(.headline).foregroundColor(VeilTheme.goldBright)
            Toggle(isOn: $haptics.isEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("震动反馈").fontWeight(.medium)
                    Text("用于发送、送达、配对、置顶与传输控制；不会在后台主动震动。")
                        .font(.caption).foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)
            if haptics.isEnabled {
                Divider().background(Color.white.opacity(0.07))
                HStack {
                    Text("反馈强度")
                    Spacer()
                    Picker("反馈强度", selection: $haptics.strength) {
                        ForEach(HapticEngine.Strength.allCases) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 250)
                    .onChange(of: haptics.strength) { _ in haptics.impact() }
                }
                Button {
                    haptics.resolved()
                } label: {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("测试一次触感")
                        Spacer()
                        Text("RESOLVE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(VeilTheme.mutedGold)
                    }
                }
                .buttonStyle(VeilPressStyle())
            }
        }
        .veilCard()
    }

    private var bluetoothCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("蓝牙后台", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline).foregroundColor(VeilTheme.goldBright)
            Text(model.bluetooth.statusText).fontWeight(.medium)
            Text("已启用 Central / Peripheral 状态恢复与有限自动重连。iOS仍可能降低后台扫描频率；重新打开应用后会继续处理加密发送队列。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            HStack {
                Text("待发送")
                Spacer()
                Text("\(identity.activeIdentity.map { model.database.pendingOutboundCount(localIdentityID: $0.id) } ?? 0)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
            }
        }
        .veilCard()
    }

    private var versionFooter: some View {
        VStack(spacing: 5) {
            Text("VeilLink 0.3.6-dev · Protocol 4")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            Text("ZeoStudio")
                .font(.caption2)
                .foregroundColor(VeilTheme.mutedGold)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            versionTapCount += 1
            if versionTapCount >= 7 {
                versionTapCount = 0
                ownerMode.refreshExpiration()
                if ownerMode.isUnlocked {
                    showsOwnerConsole = true
                } else {
                    showsOwnerUnlock = true
                }
            }
        }
    }

    private func settingButton(title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 24).foregroundColor(VeilTheme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).fontWeight(.medium).foregroundColor(VeilTheme.text)
                    Text(detail).font(.caption).foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(VeilTheme.secondaryText)
            }
        }
    }
}

private struct LockConfigurationSheet: View {
    @ObservedObject var controller: AppLockController
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var newPIN = ""

    var body: some View {
        NavigationView {
            Form {
                if controller.isEnabled {
                    SecureField("当前六位密码", text: $current).keyboardType(.numberPad)
                }
                SecureField("新的六位密码", text: $newPIN).keyboardType(.numberPad)
                if let error = controller.errorMessage {
                    Text(error).foregroundColor(.red)
                }
            }
            .navigationTitle("应用锁")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let success = controller.isEnabled
                            ? controller.changePIN(current: current, new: newPIN)
                            : controller.configure(pin: newPIN)
                        if success { dismiss() }
                    }
                }
            }
        }
    }
}

struct BackupPasswordSheet: View {
    let title: String
    let actionTitle: String
    let action: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    init(title: String = "导出加密备份", actionTitle: String = "生成ZIP", action: @escaping (String) -> Void) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        NavigationView {
            Form {
                SecureField("备份密码", text: $password)
                Text("该密码独立用于加密完整备份（全部本地身份、对话与附件），不是身份账户密码或六位应用锁密码。")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle) {
                        action(password)
                        dismiss()
                    }
                    .disabled(password.count < 8)
                }
            }
        }
    }
}


private struct IdentityManagementSheet: View {
    @ObservedObject var model: AppModel
    @ObservedObject var identity: IdentityManager
    @ObservedObject var haptics: HapticEngine
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProfile: LocalIdentity?
    @State private var showsCreate = false
    @State private var profileToDelete: LocalIdentity?

    init(model: AppModel) {
        self.model = model
        identity = model.identity
    }

    var body: some View {
        NavigationView {
            List {
                Section("本机身份") {
                    ForEach(identity.profiles) { profile in
                        Button {
                            if profile.id != identity.activeIdentity?.id { selectedProfile = profile }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: profile.id == identity.activeIdentity?.id ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                                    .foregroundColor(VeilTheme.gold)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.displayName).foregroundColor(.primary)
                                    Text(profile.id).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if profile.id == identity.activeIdentity?.id {
                                    Text("当前").font(.caption.weight(.semibold)).foregroundColor(.green)
                                }
                            }
                        }
                        .disabled(profile.id == identity.activeIdentity?.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if profile.id != identity.activeIdentity?.id {
                                Button(role: .destructive) { profileToDelete = profile } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                Section {
                    Button {
                        showsCreate = true
                    } label: {
                        Label("创建新身份", systemImage: "person.badge.plus")
                    }
                    .disabled(identity.profiles.count >= IdentityManager.profileLimit)
                } footer: {
                    Text("切换身份会立即销毁当前临时会话密钥并重新握手；不同身份不会共享会话密钥。")
                }
            }
            .navigationTitle("身份管理")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        }
        .sheet(item: $selectedProfile) { profile in
            ProfilePasswordSheet(profile: profile) { password in
                _ = model.switchIdentity(to: profile.id, password: password)
            }
        }
        .sheet(isPresented: $showsCreate) {
            NewIdentitySheet { name, password in
                _ = model.createAdditionalProfile(name: name, password: password)
            }
        }
        .sheet(item: $profileToDelete) { profile in
            DeleteIdentitySheet(profile: profile) { password in
                model.deleteIdentity(id: profile.id, password: password)
            }
        }
    }
}

private struct DeleteIdentitySheet: View {
    let profile: LocalIdentity
    let onConfirm: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("删除「\(profile.displayName)」")
                        .font(.headline)
                    Text("将删除这个身份的本机私钥、联系人、对话、消息和附件。此操作不能撤销；如需保留，请先创建加密备份。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                SecureField("输入该身份密码确认", text: $password)
            }
            .navigationTitle("删除身份")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("删除", role: .destructive) {
                        if onConfirm(password) { dismiss() }
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
    }
}

private struct ProfilePasswordSheet: View {
    let profile: LocalIdentity
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationView {
            Form {
                Text("切换到「\(profile.displayName)」")
                SecureField("身份密码", text: $password)
            }
            .navigationTitle("验证身份")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("切换") { onConfirm(password); dismiss() }.disabled(password.isEmpty)
                }
            }
        }
    }
}

private struct NewIdentitySheet: View {
    let onCreate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("身份名称", text: $name)
                SecureField("身份密码（至少 8 个字符）", text: $password)
                Text("每个身份都有独立的长期签名密钥。创建后会自动切换到新身份，并销毁旧会话。")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .navigationTitle("新建身份")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { onCreate(name, password); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 8)
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
