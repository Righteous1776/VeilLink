import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ownerMode: OwnerModeController
    @ObservedObject var identity: IdentityManager
    @ObservedObject var haptics: HapticEngine
    @ObservedObject var bluetooth: BLETransport
    @ObservedObject var a9Health: VeilA9HealthMonitor
    @ObservedObject var computeGovernor: VeilA9ComputeGovernor
    @State private var versionTapCount = 0
    @State private var showsLockSheet = false
    @State private var showsIdentityManager = false
    @State private var showsBackupSheet = false
    @State private var showsImporter = false
    @State private var restoreURL: URL?
    @State private var showsRestorePassword = false
    @State private var showsOwnerUnlock = false
    @State private var showsOwnerConsole = false
    @State private var diagnosticsCopied = false

    init(model: AppModel) {
        self.model = model
        ownerMode = model.ownerMode
        identity = model.identity
        haptics = model.haptics
        bluetooth = model.bluetooth
        a9Health = model.a9Health
        computeGovernor = model.computeGovernor
    }

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 16) {
                profileCard
                securityCard
                storageCard
                mediaCard
                feedbackCard
                bluetoothCard
                a9HealthCard
                versionFooter
            }
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
                        VeilLinkTrace(active: false, width: 34)
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
                Text(a9Health.databaseIntegrity.title)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(a9DatabaseColor)
            }
            Button {
                model.runA9StorageCheck()
                haptics.selection()
            } label: {
                HStack {
                    Image(systemName: "checkmark.shield")
                    Text("运行本地完整性自检")
                    Spacer()
                    Text("A9")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.mutedGold)
                }
            }
            .buttonStyle(VeilPressStyle())
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
            Label("蓝牙与链路", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline).foregroundColor(VeilTheme.goldBright)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bluetooth.statusText).fontWeight(.medium)
                    Text("已连接 \(bluetooth.connectedPeerCount) · 已追踪 \(bluetooth.linkSnapshots.count)")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Button {
                    bluetooth.refreshLinks()
                    haptics.selection()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.gold)
                .accessibilityLabel("重新检查蓝牙链路")
            }

            Text("Central / Peripheral 状态恢复、控制快车道与有限自动重连均保持启用。iOS仍可能降低后台扫描频率；重新打开应用后会继续处理加密发送队列。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)

            let activeSnapshots = bluetooth.linkSnapshots.values
                .sorted { lhs, rhs in
                    if lhs.isConnected != rhs.isConnected { return lhs.isConnected && !rhs.isConnected }
                    return lhs.healthScore > rhs.healthScore
                }
                .prefix(3)
            if !activeSnapshots.isEmpty {
                Divider().background(Color.white.opacity(0.07))
                ForEach(Array(activeSnapshots)) { snapshot in
                    HStack(spacing: 9) {
                        Circle()
                            .fill(snapshot.isConnected ? VeilTheme.success : (snapshot.isRecovering ? VeilTheme.gold : VeilTheme.tertiaryText))
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(snapshot.id.uuidString.prefix(8))) · \(snapshot.statusTitle)")
                                .font(.caption.weight(.semibold))
                            Text(snapshot.compactDetail.isEmpty ? snapshot.queueSummary : snapshot.compactDetail)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(VeilTheme.tertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        Spacer()
                        Text("H\(snapshot.healthScore)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(VeilTheme.gold)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.07))
            HStack {
                Text("待发送")
                Spacer()
                Text("\(identity.activeIdentity.map { model.database.pendingOutboundCount(localIdentityID: $0.id) } ?? 0)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
            }

            Button {
                UIPasteboard.general.string = bluetooth.diagnosticsReport()
                diagnosticsCopied = true
                haptics.resolved()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { diagnosticsCopied = false }
            } label: {
                HStack {
                    Image(systemName: diagnosticsCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(diagnosticsCopied ? "已复制连接诊断" : "复制连接诊断")
                    Spacer()
                    Text("不含消息/密钥")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.mutedGold)
                }
            }
            .buttonStyle(VeilPressStyle())
        }
        .veilCard()
    }

    private var a9HealthCard: some View {
        let decision = a9Health.decision
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(a9LightColor)
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text("A9 健康晶格")
                        .font(.headline)
                        .foregroundColor(VeilTheme.goldBright)
                    Text("本地采集 · 144 状态裁决 · Advisory Only")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Text("\(decision.level.shortTitle) · H\(decision.healthScore)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(a9LightColor)
            }

            HStack(spacing: 8) {
                a9Metric(title: "状态", value: decision.light.title)
                a9Metric(title: "风险", value: String(format: "%.0f", decision.riskPoints))
                a9Metric(title: "持续", value: "\(decision.persistenceRuns)")
                a9Metric(title: "CELL", value: "\(decision.latticeIndex)")
            }


            let compute = computeGovernor.plan
            HStack(spacing: 8) {
                a9Metric(title: "算力", value: compute.mode.title)
                a9Metric(title: "FLY预算", value: compute.maleCNS.tier.rawValue.uppercased())
                a9Metric(title: "BLE保留", value: "\(compute.transportReserveUnits)")
                a9Metric(title: "视觉", value: "\(compute.vision.sampleIntervalMilliseconds)ms")
            }

            if decision.issues.isEmpty {
                Text("当前没有需要裁决的异常。A9 不会主动断链、删数据或修改游戏状态。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(decision.issues.prefix(4))) { issue in
                        HStack(alignment: .top, spacing: 7) {
                            Text(issue.severity.rawValue)
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundColor(issue.severity == .p0 || issue.severity == .p1 ? .red : VeilTheme.gold)
                            Text(issue.detail)
                                .font(.caption)
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                    }
                    if decision.issues.count > 4 {
                        Text("另有 \(decision.issues.count - 4) 项 · 复制诊断可查看完整原因码")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.tertiaryText)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    model.refreshA9Health()
                    haptics.selection()
                } label: {
                    Label("重新采样", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.gold)

                Button {
                    UIPasteboard.general.string = model.a9DiagnosticsReport()
                    diagnosticsCopied = true
                    haptics.selection()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { diagnosticsCopied = false }
                } label: {
                    Label(diagnosticsCopied ? "已复制" : "复制 A9 诊断", systemImage: diagnosticsCopied ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.gold)
            }

            Text("A9 继续负责算力治理；V0.9.3 已加入 VFLY1 图加载器。当前图状态：\(model.maleCNS.state.displayName)。只有经过来源哈希、VFLY 校验和设备档位检查的 Lite/Core 图才会绑定到原生 VeilFly runtime；Reference 全图不会自动在手机上载入。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard()
        .onAppear { model.refreshA9Health() }
    }

    private func a9Metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.tertiaryText)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var a9LightColor: Color {
        switch a9Health.decision.light {
        case .green: return VeilTheme.success
        case .yellow: return VeilTheme.gold
        case .red: return .red
        }
    }

    private var a9DatabaseColor: Color {
        switch a9Health.databaseIntegrity {
        case .unchecked: return VeilTheme.secondaryText
        case .ok: return VeilTheme.success
        case .failed: return .red
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 5) {
            Text(VeilBuildInfo.display)
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            if VeilRenderProfile.usesStableScrollLayout {
                Text(VeilRenderProfile.diagnosticLabel)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
            } else {
                Text(VeilDevicePerformance.diagnosticLabel)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
            }
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
    @ObservedObject var bluetooth: BLETransport
    @ObservedObject var a9Health: VeilA9HealthMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProfile: LocalIdentity?
    @State private var showsCreate = false
    @State private var profileToDelete: LocalIdentity?

    init(model: AppModel) {
        self.model = model
        identity = model.identity
        haptics = model.haptics
        bluetooth = model.bluetooth
        a9Health = model.a9Health
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
