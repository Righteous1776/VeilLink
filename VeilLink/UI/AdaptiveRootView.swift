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
        .background(VeilTheme.background)
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
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(model.selectedSection == section ? VeilTheme.gold.opacity(0.16) : Color.clear)
                            .foregroundColor(model.selectedSection == section ? VeilTheme.gold : VeilTheme.text)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
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
            .background(VeilTheme.elevated)

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
            Circle()
                .fill(VeilTheme.gold.opacity(0.17))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "person.crop.circle.fill").foregroundColor(VeilTheme.gold))
            VStack(alignment: .leading, spacing: 3) {
                Text(identity?.displayName ?? "VeilLink").font(.headline)
                Text(identity?.id ?? "离线身份")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(18)
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(VeilTheme.gold.opacity(0.75))
            Text("选择一段加密对话").font(.title3.weight(.semibold))
            Text("消息只在附近设备与本地存储之间流动")
                .font(.subheadline)
                .foregroundColor(VeilTheme.secondaryText)
        }
    }
}
