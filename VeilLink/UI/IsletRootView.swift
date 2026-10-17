import SwiftUI

/// 浮屿（Islet）风格的深海极光底色。
/// 靛海之上三团径向微光：金在左上、极光青在右下、月晕在中顶。
struct VeilIsletBackground: View {
    var body: some View {
        ZStack {
            VeilTheme.background
            RadialGradient(
                colors: [VeilTheme.gold.opacity(0.10), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(red: 0.18, green: 0.75, blue: 0.70).opacity(0.12), Color.clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 460
            )
            RadialGradient(
                colors: [VeilTheme.elevated.opacity(0.55), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
        }
    }
}

/// 浮屿（Islet）风格的根容器。
///
/// 导航不做常驻栏：收缩为一枚悬浮「罗经胶囊」停在底部中央，
/// 点按向上展开成浮岛选单（大号编辑排版 + 圆形图标章），选定即合。
/// 内容区与遥测完全复用既有五个分区视图，本视图只负责框架（chrome）。
struct VeilIsletRootView: View {
    @ObservedObject var model: AppModel
    @State private var isNavExpanded = false

    var body: some View {
        sectionContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: VeilSpacing.sm) {
                compassCapsule
            }
            .overlay {
                if isNavExpanded {
                    expansionOverlay
                }
            }
            .onChange(of: model.selectedSection) { section in
                RuntimeDiagnosticsBridge.shared.recordSemanticAction(
                    "navigation.tab",
                    metadata: ["section": section.rawValue, "chrome": "islet"]
                )
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    isNavExpanded = false
                }
            }
    }

    /// 内容区：五个既有分区视图原样复用（含各自遥测），保持导航栈行为一致。
    private var sectionContent: some View {
        Group {
            switch model.selectedSection {
            case .chats:
                NavigationView {
                    ConversationListView(model: model, usesNavigationLinks: true)
                        .telemetryScreen("chats.list")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .nearby:
                NavigationView {
                    NearbyView(model: model)
                        .telemetryScreen("nearby")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .games:
                NavigationView {
                    GameLobbyView(model: model)
                        .telemetryScreen("games.lobby")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .agent:
                NavigationView {
                    AgentHomeView(model: model)
                        .telemetryScreen("agent.home")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .settings:
                NavigationView {
                    SettingsView(model: model)
                        .telemetryScreen("settings")
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    /// 罗经胶囊：当前分区 + 未读微记 + 展开指示。点按开合浮岛选单。
    private var compassCapsule: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isNavExpanded.toggle()
            }
        } label: {
            HStack(spacing: VeilSpacing.xs) {
                Image(systemName: model.selectedSection.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VeilTheme.gold)
                Text(model.selectedSection.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VeilTheme.text)
                if model.totalUnreadCount > 0 {
                    Text(model.totalUnreadCount > 99 ? "99+" : "\(model.totalUnreadCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 18)
                        .background(VeilTheme.gold.opacity(0.14))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(VeilTheme.secondaryText)
                    .rotationEffect(.degrees(isNavExpanded ? 180 : 0))
            }
            .padding(.horizontal, VeilSpacing.lg)
            .frame(height: 46)
            .background(
                Capsule()
                    .fill(VeilTheme.panel)
            )
            .overlay(
                Capsule()
                    .stroke(VeilTheme.hairline, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isNavExpanded ? "收起导航" : "打开导航")
        .accessibilityHint("展开后选择要前往的分区")
    }

    /// 展开态：压暗层 + 浮岛选单（点空白或选定后收起）。
    private var expansionOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                        isNavExpanded = false
                    }
                }
            VStack(spacing: 2) {
                ForEach(SidebarSection.allCases) { section in
                    Button {
                        model.selectedSection = section
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(model.selectedSection == section ? VeilTheme.gold.opacity(0.16) : VeilTheme.elevated)
                                Image(systemName: section.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(model.selectedSection == section ? VeilTheme.gold : VeilTheme.secondaryText)
                            }
                            .frame(width: 34, height: 34)
                            Text(section.rawValue)
                                .font(.system(size: 17, weight: model.selectedSection == section ? .bold : .medium))
                                .foregroundColor(model.selectedSection == section ? VeilTheme.text : VeilTheme.secondaryText)
                            Spacer()
                            if section == .chats, model.totalUnreadCount > 0 {
                                Text(model.totalUnreadCount > 99 ? "99+" : "\(model.totalUnreadCount)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(VeilTheme.gold)
                            }
                            if model.selectedSection == section {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(VeilTheme.gold)
                            }
                        }
                        .padding(.horizontal, VeilSpacing.md)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(model.selectedSection == section ? VeilTheme.gold.opacity(0.10) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.selectedSection == section ? .isSelected : [])
                }
            }
            .padding(VeilSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(VeilTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(VeilTheme.hairline, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.34), radius: 24, x: 0, y: 14)
            .padding(.horizontal, VeilSpacing.lg)
            .padding(.bottom, 88)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
