import SwiftUI

struct AdaptiveRootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                TabletLayout(model: model)
            } else {
                PhoneLayout(model: model)
            }
        }
        .background(VeilAmbientBackground())
    }
}

private struct PhoneLayout: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedSection) {
            NavigationView {
                ConversationListView(model: model, usesNavigationLinks: true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("对话", systemImage: SidebarSection.chats.icon) }
            .badge(model.totalUnreadCount)
            .tag(SidebarSection.chats)

            NavigationView {
                NearbyView(model: model)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("附近", systemImage: SidebarSection.nearby.icon) }
            .tag(SidebarSection.nearby)

            NavigationView {
                SettingsView(model: model)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("设置", systemImage: SidebarSection.settings.icon) }
            .tag(SidebarSection.settings)
        }
        .accentColor(VeilTheme.gold)
    }
}

private struct TabletLayout: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                IdentityHeader(identity: model.identity.activeIdentity)
                VStack(spacing: 6) {
                    ForEach(SidebarSection.allCases) { section in
                        Button {
                            model.selectedSection = section
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: section.icon).frame(width: 24)
                                Text(section.rawValue).fontWeight(.medium)
                                Spacer()
                                if section == .chats, model.totalUnreadCount > 0 {
                                    Text(model.totalUnreadCount > 99 ? "99+" : "\(model.totalUnreadCount)")
                                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color.black.opacity(0.86))
                                        .padding(.horizontal, 6)
                                        .frame(minWidth: 20, minHeight: 18)
                                        .background(VeilTheme.goldBright)
                                        .clipShape(Capsule())
                                }
                                if model.selectedSection == section {
                                    VeilResolveMark(resolved: true)
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(
                                VeilPanelShape(cut: 10, radius: 6)
                                    .fill(model.selectedSection == section ? VeilTheme.gold.opacity(0.105) : Color.clear)
                            )
                            .foregroundColor(model.selectedSection == section ? VeilTheme.goldBright : VeilTheme.text)
                            .overlay(
                                VeilPanelShape(cut: 10, radius: 6)
                                    .stroke(model.selectedSection == section ? VeilTheme.gold.opacity(0.20) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(VeilPressStyle())
                    }
                }
                .padding(12)

                Divider().background(Color.white.opacity(0.08))
                if model.selectedSection == .chats {
                    ConversationListView(model: model, usesNavigationLinks: false)
                } else {
                    Spacer()
                }
            }
            .frame(width: 330)
            .background(VeilTheme.elevated.opacity(0.94))
            .overlay(alignment: .trailing) {
                LinearGradient(colors: [Color.clear, VeilTheme.gold.opacity(0.12), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: 1)
            }

            Divider().background(Color.white.opacity(0.08))

            Group {
                switch model.selectedSection {
                case .chats:
                    if let conversation = model.selectedConversation {
                        ChatView(model: model, conversation: conversation)
                    } else {
                        EmptyDetailView()
                    }
                case .nearby:
                    NearbyView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct IdentityHeader: View {
    let identity: LocalIdentity?

    var body: some View {
        HStack(spacing: 12) {
            VeilIdentityGlyph(seed: identity?.id ?? "veillink-local", size: 44, active: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(identity?.displayName ?? "VeilLink")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                HStack(spacing: 7) {
                    Text("LOCAL ID")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(VeilTheme.mutedGold)
                    VeilLinkTrace(active: true, width: 34)
                    Text(String((identity?.id ?? "offline").prefix(8)).uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }
            Spacer()
        }
        .padding(18)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(LinearGradient(colors: [VeilTheme.gold.opacity(0.45), Color.clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 150, height: 1)
                .padding(.leading, 18)
        }
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 15) {
            VeilIdentityGlyph(seed: "veillink-empty-session", size: 92, active: false)
            Text("选择一段加密对话")
                .font(.system(.title3, design: .rounded).weight(.semibold))
            HStack(spacing: 8) {
                Text("LOCAL")
                VeilLinkTrace(active: false, width: 52)
                Text("PEER")
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(VeilTheme.mutedGold)
            Text("消息只在附近设备与本地存储之间流动")
                .font(.subheadline)
                .foregroundColor(VeilTheme.secondaryText)
        }
    }
}
