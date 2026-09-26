import SwiftUI
import UIKit

enum VeilLegalGatePresentation {
    case standalone
    case firstActivation
}

struct LegalConsentGateView: View {
    @ObservedObject var controller: VeilLegalConsentController
    var presentation: VeilLegalGatePresentation = .standalone
    let onAccepted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDocument = 0
    @State private var acknowledgment = ""
    @State private var confirmsPermissions = false
    @State private var confirmsRisk = false
    @State private var confirmsVersionRule = false
    @State private var errorText: String?
    @State private var copiedHash = false

    private var canSign: Bool {
        confirmsPermissions &&
        confirmsRisk &&
        confirmsVersionRule &&
        acknowledgment.trimmingCharacters(in: .whitespacesAndNewlines) == VeilLegalConsentController.requiredAcknowledgment
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VeilAmbientBackground()
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        header(compact: proxy.size.height < 720)
                        documentSelector
                        documentCard
                        confirmationsCard
                        signatureCard
                        footnote
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, presentation == .firstActivation ? 6 : 18)
                    .padding(.bottom, max(22, proxy.safeAreaInsets.bottom + 12))
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if presentation == .standalone {
                VeilActivationMorphCore(compact: true)
                    .scaleEffect(compact ? 0.80 : 0.92)
                    .frame(width: compact ? 92 : 108, height: compact ? 92 : 108)
            } else {
                VeilIconDisc(systemName: "signature", size: 48, highlighted: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(presentation == .firstActivation ? "授权与协议" : "使用授权与协议签署")
                    .font(.system(size: compact ? 25 : 29, weight: .bold, design: .rounded))
                    .foregroundColor(VeilTheme.text)
                Text("\(controller.currentReleaseID) · 协议 \(VeilLegalConsentController.documentVersion)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(VeilTheme.mutedGold)
                Text(controller.needsSignatureReason)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private var documentSelector: some View {
        HStack(spacing: 8) {
            legalSegment(title: "权限授权说明", icon: "hand.raised", index: 0)
            legalSegment(title: "责任边界", icon: "doc.text", index: 1)
        }
        .padding(4)
        .background(VeilTheme.obsidian.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 0.8))
    }

    private func legalSegment(title: String, icon: String, index: Int) -> some View {
        Button {
            selectedDocument = index
            VeilOnboardingHaptics.selection()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(selectedDocument == index ? VeilTheme.goldBright : VeilTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedDocument == index ? VeilTheme.elevated.opacity(0.96) : Color.clear)
                    .shadow(color: selectedDocument == index ? Color.black.opacity(0.22) : .clear, radius: 6, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selectedDocument == index ? VeilTheme.gold.opacity(0.18) : Color.clear, lineWidth: 0.8)
            )
        }
        .buttonStyle(VeilPressStyle())
    }

    private var documentCard: some View {
        VeilReleaseNeumorphicPlate(emphasized: true, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(selectedDocument == 0 ? "权限授权说明" : "使用须知与责任边界", systemImage: selectedDocument == 0 ? "shield.lefthalf.filled" : "doc.text.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(VeilTheme.goldBright)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = controller.currentDocumentSHA256
                        copiedHash = true
                        VeilOnboardingHaptics.selection()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedHash = false }
                    } label: {
                        Text(copiedHash ? "已复制" : "SHA-256")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(VeilTheme.mutedGold)
                    }
                    .buttonStyle(.plain)
                }

                Text(selectedDocument == 0 ? VeilLegalDocuments.permissions : VeilLegalDocuments.terms)
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundColor(VeilTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var confirmationsCard: some View {
        VeilReleaseNeumorphicPlate(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 13) {
                Label("签署确认", systemImage: "checkmark.seal")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(VeilTheme.goldBright)

                confirmationRow(
                    "我理解系统权限仍由 iOS 单独控制，本协议不能代替系统授权。",
                    isOn: $confirmsPermissions
                )
                confirmationRow(
                    "我已阅读风险告知与责任边界，理解 VeilLink 不适用于紧急或生命安全通信。",
                    isOn: $confirmsRisk
                )
                confirmationRow(
                    "我理解每次版本、Build 或协议正文变化后都需要重新签署。",
                    isOn: $confirmsVersionRule
                )
            }
        }
    }

    private var signatureCard: some View {
        VeilReleaseNeumorphicPlate(emphasized: canSign, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("输入确认语")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(VeilTheme.text)
                    Spacer()
                    Text("LOCAL EVIDENCE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.mutedGold)
                }

                HStack(spacing: 10) {
                    Image(systemName: "signature")
                        .foregroundColor(VeilTheme.goldBright)
                    TextField("请输入：\(VeilLegalConsentController.requiredAcknowledgment)", text: $acknowledgment)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 14, design: .rounded))
                }
                .padding(.horizontal, 13)
                .frame(height: 48)
                .background(VeilTheme.obsidian.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(canSign ? VeilTheme.gold.opacity(0.30) : VeilTheme.hairline, lineWidth: 0.9))

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.90))
                        .transition(.opacity)
                }

                VeilReleasePrimaryButton(title: "签署并进入 VeilLink", systemImage: "checkmark.shield.fill", enabled: canSign) {
                    sign()
                }

                Button {
                    errorText = "当前版本必须完成协议签署后才能启动核心通信服务。"
                    VeilOnboardingHaptics.selection()
                } label: {
                    Text("暂不签署")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(VeilTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footnote: some View {
        Text("不同意不会触发崩溃或自动删除数据；App 将保持锁定，且不会创建聊天数据库或启动 BLE、LAN、Internet Relay、Mesh 等核心通信服务。")
            .font(.system(size: 10.5, design: .rounded))
            .foregroundColor(VeilTheme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func confirmationRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            VeilOnboardingHaptics.selection()
        } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isOn.wrappedValue ? VeilTheme.gold.opacity(0.15) : VeilTheme.obsidian.opacity(0.64))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isOn.wrappedValue ? VeilTheme.gold.opacity(0.48) : VeilTheme.hairline, lineWidth: 0.9)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(VeilTheme.goldBright)
                        .opacity(isOn.wrappedValue ? 1 : 0)
                        .scaleEffect(isOn.wrappedValue || reduceMotion ? 1 : 0.88)
                }
                .frame(width: 25, height: 25)
                Text(title)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(VeilTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(VeilPressStyle())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isOn.wrappedValue)
    }

    private func sign() {
        guard canSign else {
            errorText = "请完成三项确认，并准确输入签署确认语。"
            return
        }
        if controller.accept(acknowledgment: acknowledgment) {
            errorText = nil
            VeilOnboardingHaptics.confirm()
            onAccepted()
        } else {
            errorText = "签署记录未能安全保存，请重试。"
        }
    }
}

struct LegalAgreementReviewView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: VeilLegalConsentController
    @State private var selectedDocument = 0
    @State private var confirmsWithdrawal = false
    @State private var copied = false

    init(model: AppModel) {
        self.model = model
        controller = model.legalConsent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VeilReleaseNeumorphicPlate(emphasized: true, cornerRadius: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前签署")
                            .font(.headline)
                            .foregroundColor(VeilTheme.goldBright)
                        legalMetric("版本", controller.currentReleaseID)
                        legalMetric("协议", VeilLegalConsentController.documentVersion)
                        legalMetric("SHA-256", String(controller.currentDocumentSHA256.prefix(20)) + "…")
                        if let record = controller.currentRecord {
                            legalMetric("签署时间", record.acceptedAt.formatted(date: .abbreviated, time: .standard))
                            legalMetric("记录 ID", String(record.acceptanceID.prefix(18)) + "…")
                        }
                    }
                }

                HStack(spacing: 8) {
                    legalReviewSegment("权限授权说明", index: 0)
                    legalReviewSegment("责任边界", index: 1)
                }

                VeilReleaseNeumorphicPlate(cornerRadius: 20) {
                    Text(selectedDocument == 0 ? VeilLegalDocuments.permissions : VeilLegalDocuments.terms)
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundColor(VeilTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                Button {
                    if let data = controller.evidenceJSON(), let text = String(data: data, encoding: .utf8) {
                        UIPasteboard.general.string = text
                        copied = true
                        model.haptics.resolved()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                } label: {
                    Label(copied ? "已复制签署凭据" : "复制签署凭据 JSON", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .background(VeilTheme.elevated.opacity(0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(VeilPressStyle())

                VeilReleaseNeumorphicPlate(cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("我确认要撤回当前版本的使用授权并锁定 VeilLink", isOn: $confirmsWithdrawal)
                            .font(.caption)
                            .tint(VeilTheme.gold)
                        Button(role: .destructive) {
                            model.sealForLegalWithdrawal()
                            controller.withdraw()
                        } label: {
                            Label("撤回授权并安全封存", systemImage: "lock.shield")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!confirmsWithdrawal)
                        Text("安全封存会停止 BLE、LAN、Internet Relay、远程配对并清理临时会话/缓存；不会故意崩溃，也不会自动删除聊天数据库。")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.tertiaryText)
                    }
                }
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("协议与授权")
    }

    private func legalReviewSegment(_ title: String, index: Int) -> some View {
        Button {
            selectedDocument = index
            model.haptics.selection()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(selectedDocument == index ? VeilTheme.goldBright : VeilTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(VeilTheme.elevated.opacity(selectedDocument == index ? 0.98 : 0.70))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(selectedDocument == index ? VeilTheme.gold.opacity(0.24) : VeilTheme.hairline, lineWidth: 0.8))
        }
        .buttonStyle(VeilPressStyle())
    }

    private func legalMetric(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundColor(VeilTheme.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(VeilTheme.text)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
