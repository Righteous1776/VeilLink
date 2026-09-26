import SwiftUI

struct VeilAppleSoftRootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                VeilAppleSoftTabletRoot(model: model)
            } else {
                VeilAppleSoftPhoneRoot(model: model)
            }
        }
        .background(VeilAppleSoftBackground())
    }
}

private struct VeilAppleSoftPhoneRoot: View {
    @ObservedObject var model: AppModel

    var body: some View {
        selectedContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VeilAppleSoftDock(model: model)
                    .padding(.horizontal, 14)
                    .padding(.top, 7)
                    .padding(.bottom, 5)
            }
            .onChange(of: model.selectedSection) { section in
                RuntimeDiagnosticsBridge.shared.recordSemanticAction(
                    "navigation.apple_soft_tab",
                    metadata: ["section": section.rawValue]
                )
            }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch model.selectedSection {
        case .chats:
            NavigationView {
                ConversationListView(model: model, usesNavigationLinks: true)
                    .telemetryScreen("chats.list")
            }
            .navigationViewStyle(StackNavigationViewStyle())
        case .nearby:
            NavigationView { NearbyView(model: model).telemetryScreen("nearby") }
                .navigationViewStyle(StackNavigationViewStyle())
        case .games:
            NavigationView { GameLobbyView(model: model).telemetryScreen("games.lobby") }
                .navigationViewStyle(StackNavigationViewStyle())
        case .agent:
            NavigationView { AgentHomeView(model: model).telemetryScreen("agent.home") }
                .navigationViewStyle(StackNavigationViewStyle())
        case .settings:
            NavigationView { SettingsView(model: model).telemetryScreen("settings") }
                .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

private struct VeilAppleSoftDock: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VeilPlatformGlassCluster(spacing: 9) {
            HStack(spacing: 5) {
                ForEach(SidebarSection.allCases) { section in
                    let selected = model.selectedSection == section
                    Button {
                        model.haptics.selection()
                        withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.30, dampingFraction: 0.82, blendDuration: 0.06)) {
                            model.selectedSection = section
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(selected ? VeilTheme.gold.opacity(0.13) : Color.clear)
                                    .frame(width: 42, height: 31)
                                Image(systemName: section.icon)
                                    .font(.system(size: 15, weight: selected ? .semibold : .medium))
                                    .foregroundColor(selected ? VeilTheme.goldBright : VeilTheme.secondaryText)
                                    .scaleEffect(selected && !reduceMotion ? 1.04 : 1)
                            }
                            Text(section.rawValue)
                                .font(.system(size: 9.5, weight: selected ? .semibold : .medium, design: .rounded))
                                .foregroundColor(selected ? VeilTheme.text : VeilTheme.secondaryText)
                                .lineLimit(1)
                            VeilMorphIcon(
                                from: .appleDot,
                                to: .appleCheck,
                                toggled: selected,
                                size: 8,
                                color: selected ? VeilTheme.goldBright : VeilTheme.tertiaryText,
                                lineWidth: 1.4
                            )
                            .frame(height: 7)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(VeilAppleDockPressStyle())
                    .accessibilityLabel(section.rawValue)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
            .veilPlatformGlass(cornerRadius: 28, interactive: true)
        }
    }
}

private struct VeilAppleDockPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct VeilAppleSoftTabletRoot: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 12) {
                VeilIdentityGlyph(seed: model.identity.activeIdentity?.id ?? "veillink-apple-soft", size: 48, active: true)
                    .padding(.top, 18)
                Text(model.identity.activeIdentity?.displayName ?? "VeilLink")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(VeilTheme.text)
                    .lineLimit(1)

                VeilPlatformGlassCluster(spacing: 9) {
                    VStack(spacing: 7) {
                        ForEach(SidebarSection.allCases) { section in
                            Button {
                                model.haptics.selection()
                                model.selectedSection = section
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: section.icon)
                                        .frame(width: 24)
                                    Text(section.rawValue)
                                    Spacer(minLength: 0)
                                    if model.selectedSection == section {
                                        VeilMorphIcon(from: .appleDot, to: .appleCheck, toggled: true, size: 13, color: VeilTheme.goldBright, lineWidth: 1.8)
                                    }
                                }
                                .font(.system(.subheadline, design: .rounded).weight(model.selectedSection == section ? .semibold : .medium))
                                .foregroundColor(model.selectedSection == section ? VeilTheme.text : VeilTheme.secondaryText)
                                .padding(.horizontal, 13)
                                .frame(height: 46)
                                .background(model.selectedSection == section ? VeilTheme.gold.opacity(0.12) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(VeilPressStyle())
                        }
                    }
                    .padding(8)
                    .veilPlatformGlass(cornerRadius: 26, interactive: true)
                }
                Spacer()
                Text(VeilPlatformMaterialEngine.diagnosticLabel)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.tertiaryText)
                    .padding(.bottom, 12)
            }
            .frame(width: 235)
            .padding(.horizontal, 10)

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.leading, 6)
        .background(VeilAppleSoftBackground())
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch model.selectedSection {
        case .chats:
            NavigationView { ConversationListView(model: model, usesNavigationLinks: true) }
        case .nearby:
            NavigationView { NearbyView(model: model) }
        case .games:
            NavigationView { GameLobbyView(model: model) }
        case .agent:
            NavigationView { AgentHomeView(model: model) }
        case .settings:
            NavigationView { SettingsView(model: model) }
        }
    }
}
