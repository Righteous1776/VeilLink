import SwiftUI

struct VeilReleaseActivationView: View {
    @ObservedObject var controller: VeilFirstRunOnboardingController
    @ObservedObject var legal: VeilLegalConsentController
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: Int
    @State private var activationProgress: CGFloat = 0
    @State private var contentVisible = false
    @GestureState private var dragX: CGFloat = 0

    private let pageCount = 5

    init(
        controller: VeilFirstRunOnboardingController,
        legal: VeilLegalConsentController,
        onFinished: @escaping () -> Void
    ) {
        self.controller = controller
        self.legal = legal
        self.onFinished = onFinished
        _page = State(initialValue: min(max(controller.resumePage, 0), 4))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VeilAmbientBackground()

                VStack(spacing: 0) {
                    topChrome
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                    ZStack {
                        pageContent(proxy: proxy)
                            .id(page)
                            .opacity(contentVisible ? 1 : 0)
                            .scaleEffect(contentVisible || reduceMotion ? 1 : 0.975)
                            .offset(x: reduceMotion ? 0 : dragX * 0.12, y: contentVisible || reduceMotion ? 0 : 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(swipeGesture, including: page < 4 ? .all : .none)

                    if page < 4 {
                        bottomNavigation
                            .padding(.horizontal, 18)
                            .padding(.bottom, max(10, proxy.safeAreaInsets.bottom + 4))
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            startPageEntrance()
            if page == 0 { runActivationIfNeeded() }
        }
        .onChange(of: page) { newPage in
            controller.remember(page: newPage)
            startPageEntrance()
            if newPage == 0 { runActivationIfNeeded() }
            VeilOnboardingHaptics.selection()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, page == 0 { runActivationIfNeeded() }
        }
    }

    private var topChrome: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                VeilIdentityGlyph(seed: "veillink.release.activation", size: 30, active: true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("VEILLINK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(VeilTheme.text)
                    Text("FIRST ACTIVATION")
                        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                        .tracking(0.9)
                        .foregroundColor(VeilTheme.mutedGold)
                }
            }
            Spacer()
            if page > 0 && page < 4 {
                Button("直接阅读协议") { move(to: 4) }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(VeilTheme.secondaryText)
                    .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private func pageContent(proxy: GeometryProxy) -> some View {
        switch page {
        case 0:
            activationPage(proxy: proxy)
        case 1:
            connectivityPage(proxy: proxy)
        case 2:
            trustAndCommunityPage(proxy: proxy)
        case 3:
            howToPage(proxy: proxy)
        default:
            legalPage
        }
    }

    private func activationPage(proxy: GeometryProxy) -> some View {
        let compact = proxy.size.height < 720 || VeilRenderProfile.usesLegacyCompositorPath
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: compact ? 20 : 28) {
                Spacer(minLength: compact ? 8 : 24)

                VStack(spacing: 9) {
                    Text("欢迎来到 VeilLink")
                        .font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
                        .foregroundColor(VeilTheme.text)
                    Text("PRIVATE LINKS · YOUR WAY")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("离线、局域网、Mesh 与远程中继，统一在一套端到端加密通信栈里。")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(VeilTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }

                VeilActivationMorphCore(compact: compact)

                VeilReleaseNeumorphicPlate(emphasized: true, cornerRadius: 22) {
                    VStack(spacing: 13) {
                        HStack {
                            Text(activationLabel)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundColor(VeilTheme.text)
                            Spacer()
                            Text("\(Int(activationProgress * 100))%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(VeilTheme.mutedGold)
                        }
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.055))
                            Capsule()
                                .fill(VeilTheme.goldGradient)
                                .scaleEffect(x: max(0.02, activationProgress), y: 1, anchor: .leading)
                        }
                        .frame(height: 4)
                        HStack(spacing: 6) {
                            statusChip("LOCAL FIRST", active: activationProgress > 0.18)
                            statusChip("E2EE", active: activationProgress > 0.46)
                            statusChip("MULTI-LINK", active: activationProgress > 0.72)
                        }
                    }
                }
                .frame(maxWidth: 520)

                Text("这段激活动画只在首次启用时出现，不会占用日常启动时间。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.tertiaryText)

                Spacer(minLength: compact ? 6 : 22)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: max(520, proxy.size.height - 150))
        }
    }

    private var activationLabel: String {
        switch activationProgress {
        case ..<0.24: return "建立本地安全上下文"
        case ..<0.50: return "校验加密与身份组件"
        case ..<0.76: return "准备多链路路由能力"
        case ..<1: return "完成首次激活"
        default: return "安全环境已就绪"
        }
    }

    private func connectivityPage(proxy: GeometryProxy) -> some View {
        onboardingScroll(proxy: proxy) {
            pageHeader(
                eyebrow: "01 · CONNECTIVITY",
                title: "一套应用，多条链路",
                detail: "VeilLink 会根据实际可达性与链路质量选择路径；近距离优先本地，不必为了速度强制绕云。"
            )

            HStack(spacing: 14) {
                VeilActivationMorphCore(compact: true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("LOCAL → MESH → RELAY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("链路可以共存；LAN 断开时仍可回落 BLE，远距离再使用 Internet Relay。")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)

            VeilReleaseNeumorphicPlate(cornerRadius: 22) {
                VStack(spacing: 15) {
                    VeilReleaseFeatureRow(icon: "dot.radiowaves.left.and.right", title: "BLE 离线通信", detail: "没有互联网时仍可发现附近设备、建立端到端加密会话。", highlighted: true)
                    Divider().background(VeilTheme.hairline)
                    VeilReleaseFeatureRow(icon: "wifi", title: "LAN Turbo", detail: "同一 Wi‑Fi / 热点优先高速 TCP 直连，适合图片、语音和文件。")
                    Divider().background(VeilTheme.hairline)
                    VeilReleaseFeatureRow(icon: "point.3.connected.trianglepath.dotted", title: "Mesh 多跳", detail: "可信 VeilLink 节点可转发密文，包含 TTL、去重和广播风暴限制。")
                    Divider().background(VeilTheme.hairline)
                    VeilReleaseFeatureRow(icon: "network", title: "Internet Relay", detail: "国内 / 国际双通道用于远距离传输，Relay 只处理二次加密后的数据。")
                }
            }
        }
    }

    private func trustAndCommunityPage(proxy: GeometryProxy) -> some View {
        onboardingScroll(proxy: proxy) {
            pageHeader(
                eyebrow: "02 · TRUST & COMMUNITY",
                title: "安全不是一个开关",
                detail: "身份、配对、内容加密、重放防护和中继隐私组成一条完整信任链。"
            )

            VeilReleaseNeumorphicPlate(emphasized: true, cornerRadius: 22) {
                VStack(spacing: 16) {
                    VeilReleaseFeatureRow(icon: "lock.shield", title: "端到端加密", detail: "消息、文件和配对流程使用现有 VeilLink 安全会话；服务器不拥有聊天解密密钥。", highlighted: true)
                    Divider().background(VeilTheme.hairline)
                    VeilReleaseFeatureRow(icon: "qrcode", title: "60 秒远程二维码", detail: "二维码是一次性 Rendezvous Capability，不直接暴露长期身份或聊天密钥。")
                    Divider().background(VeilTheme.hairline)
                    VeilReleaseFeatureRow(icon: "person.3", title: "群聊与公开频道", detail: "普通群采用房间密钥；公开频道支持实名或频道独立匿名身份。")
                    Divider().background(VeilTheme.hairline)
                    VeilReleaseFeatureRow(icon: "wave.3.right.circle", title: "后台连续性", detail: "在系统允许范围内结合 CoreBluetooth、Live Activity 与后台任务保持连接连续性。")
                }
            }

            HStack(spacing: 10) {
                microMetric("PAIR", "双向确认")
                microMetric("REPLAY", "窗口防护")
                microMetric("RELAY", "密文中继")
            }
        }
    }

    private func howToPage(proxy: GeometryProxy) -> some View {
        onboardingScroll(proxy: proxy) {
            pageHeader(
                eyebrow: "03 · QUICK START",
                title: "三步开始通信",
                detail: "首次使用只需要建立本地身份、选择配对方式，然后让 VeilLink 自动处理后续链路。"
            )

            VStack(spacing: 12) {
                stepCard(number: "1", icon: "person.crop.circle.badge.plus", title: "创建本地身份", detail: "设置显示名称、身份密码和 App 锁 PIN。本地密钥不会因为查看介绍页而提前上传。")
                stepCard(number: "2", icon: "link", title: "建立信任", detail: "附近设备可直接配对；远方好友可发送 60 秒二维码，双方核对六码后再固定长期身份。")
                stepCard(number: "3", icon: "message", title: "开始通信", detail: "文字、图片、语音、PTT、群聊和公开频道会使用当前可用的最佳链路。")
            }

            VeilReleaseNeumorphicPlate(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 11) {
                    Label("权限如何请求", systemImage: "hand.raised")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(VeilTheme.goldBright)
                    Text("签署协议不会替代 iOS 权限。蓝牙、局域网、麦克风、照片、通知等仍在功能真正需要时由系统单独询问；拒绝某项权限只影响对应能力。")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(VeilTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var legalPage: some View {
        if legal.isSatisfied {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(VeilTheme.goldBright)
                Text("当前版本已完成协议签署")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("你可以完成首次激活。以后 App 版本、Build 或协议正文变化时，只会重新进入协议门禁，不会重复播放新手介绍。")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(VeilTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                VeilReleasePrimaryButton(title: "完成激活", systemImage: "checkmark") {
                    finishActivation()
                }
                .frame(maxWidth: 520)
                Spacer()
            }
            .padding(20)
        } else {
            LegalConsentGateView(controller: legal, presentation: .firstActivation) {
                finishActivation()
            }
        }
    }

    private var bottomNavigation: some View {
        VStack(spacing: 13) {
            VeilReleasePageDots(page: page, count: pageCount)
            HStack(spacing: 10) {
                if page > 0 {
                    Button {
                        move(to: page - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(VeilTheme.secondaryText)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(VeilTheme.elevated.opacity(0.88)))
                            .overlay(Circle().stroke(VeilTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(VeilPressStyle())
                }

                VeilReleasePrimaryButton(
                    title: page == 0 && activationProgress < 0.92 ? "继续了解" : (page == 3 ? "阅读并签署协议" : "继续"),
                    systemImage: page == 3 ? "signature" : "arrow.right"
                ) {
                    move(to: min(4, page + 1))
                }
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragX) { value, state, _ in state = value.translation.width }
            .onEnded { value in
                guard abs(value.predictedEndTranslation.width) > 72 else { return }
                if value.predictedEndTranslation.width < 0, page < 3 {
                    move(to: page + 1)
                } else if value.predictedEndTranslation.width > 0, page > 0 {
                    move(to: page - 1)
                }
            }
    }

    private func onboardingScroll<Content: View>(proxy: GeometryProxy, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, proxy.size.height < 720 ? 8 : 20)
            .padding(.bottom, 24)
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func pageHeader(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.35)
                .foregroundColor(VeilTheme.mutedGold)
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(VeilTheme.text)
            Text(detail)
                .font(.system(size: 13.5, design: .rounded))
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusChip(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(active ? VeilTheme.goldBright : VeilTheme.tertiaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(active ? VeilTheme.gold.opacity(0.10) : Color.white.opacity(0.025)))
            .overlay(Capsule().stroke(active ? VeilTheme.gold.opacity(0.22) : VeilTheme.hairline, lineWidth: 0.8))
    }

    private func microMetric(_ code: String, _ detail: String) -> some View {
        VStack(spacing: 4) {
            Text(code)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.goldBright)
            Text(detail)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundColor(VeilTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(VeilTheme.elevated.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 0.8))
    }

    private func stepCard(number: String, icon: String, title: String, detail: String) -> some View {
        VeilReleaseNeumorphicPlate(cornerRadius: 20) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(VeilTheme.gold.opacity(0.10))
                    Circle().stroke(VeilTheme.gold.opacity(0.26), lineWidth: 1)
                    Text(number)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.goldBright)
                }
                .frame(width: 32, height: 32)
                VeilIconDisc(systemName: icon, size: 38, highlighted: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(detail)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundColor(VeilTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func move(to target: Int) {
        let target = min(max(target, 0), 4)
        guard target != page else { return }
        if !reduceMotion { contentVisible = false }
        page = target
    }

    private func startPageEntrance() {
        contentVisible = reduceMotion
        guard !reduceMotion else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) { contentVisible = true }
        }
    }

    private func runActivationIfNeeded() {
        if reduceMotion {
            activationProgress = 1
            return
        }
        activationProgress = 0
        // This is explanatory first-run motion, so a longer sequence is intentional.
        withAnimation(.linear(duration: 2.15)) { activationProgress = 1 }
    }

    private func finishActivation() {
        guard legal.isSatisfied else { return }
        VeilOnboardingHaptics.confirm()
        onFinished()
    }
}
