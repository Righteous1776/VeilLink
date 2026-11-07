import SwiftUI

enum VeilSettingsSection: String, CaseIterable, Identifiable, Sendable {
    case appearanceAndData
    case connectivity
    case intelligence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearanceAndData: return "外观与数据"
        case .connectivity: return "连接与通信"
        case .intelligence: return "智能与性能"
        }
    }

    var subtitle: String {
        switch self {
        case .appearanceAndData: return "主题、协议、存储、媒体与反馈"
        case .connectivity: return "蓝牙、后台、运行环境与互联网中继"
        case .intelligence: return "灵核助手、A9 健康与内核运行时"
        }
    }

    var systemImage: String {
        switch self {
        case .appearanceAndData: return "slider.horizontal.3"
        case .connectivity: return "antenna.radiowaves.left.and.right"
        case .intelligence: return "cpu"
        }
    }

    var storageKey: String { "settings.section.\(rawValue).expanded" }
    var defaultExpanded: Bool { false }
}

struct VeilSettingsDisclosureSection<Content: View>: View {
    let section: VeilSettingsSection
    @Binding var isExpanded: Bool
    private let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        section: VeilSettingsSection,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.section = section
        _isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(spacing: 11) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(VeilTheme.gold.opacity(isExpanded ? 0.16 : 0.08))
                            .frame(width: 42, height: 42)
                        Image(systemName: section.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isExpanded ? VeilTheme.goldBright : VeilTheme.mutedGold)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundColor(VeilTheme.text)
                        Text(section.subtitle)
                            .font(.caption)
                            .foregroundColor(VeilTheme.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(VeilTheme.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(VeilPressStyle())
            .veilCard(emphasized: isExpanded)
            .accessibilityLabel(section.title)
            .accessibilityValue(isExpanded ? "已展开" : "已折叠")
            .accessibilityHint(isExpanded ? "轻点折叠" : "轻点展开")

            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }

    private func toggle() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                isExpanded.toggle()
            }
        }
    }
}
