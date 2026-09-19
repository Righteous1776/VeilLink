import SwiftUI

struct AgentStatusView: View {
    @ObservedObject var coordinator: AgentCoordinator
    @ObservedObject var maleCNS: MaleCNSGraphManager

    private var stateColor: Color {
        switch coordinator.runtimeState {
        case .ready: return VeilTheme.success
        case .generating: return VeilTheme.goldBright
        case .loading: return VeilTheme.gold
        case .cooling: return VeilTheme.mutedGold
        case .unavailable: return VeilTheme.danger
        case .unloaded: return VeilTheme.secondaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VeilIdentityGlyph(
                    seed: "veillink-agent-foundation",
                    size: 46,
                    active: coordinator.runtimeState == .ready || coordinator.runtimeState == .generating
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("灵核")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                        Text(LocalTextModelRuntimeFactory.isRealLocalInferenceCompiled ? "REAL LOCAL" : "LOCAL FIXTURE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.9)
                            .foregroundColor(VeilTheme.gold)
                    }
                    Text("本机运行 · 无云端依赖")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(stateColor).frame(width: 6, height: 6)
                        Text(coordinator.runtimeState.displayName)
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(stateColor)
                    Text(coordinator.capabilityProfile.displayName)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilTheme.tertiaryText)
                }
            }

            HStack(spacing: 8) {
                AgentStatusChip(title: "RUNTIME", value: coordinator.runtimeManifest?.displayName ?? "未载入")
                AgentStatusChip(title: "ENGINE", value: LocalTextModelRuntimeFactory.backendName)
            }

            HStack(spacing: 8) {
                AgentStatusChip(title: "PROFILE", value: coordinator.capabilityProfile.tier.rawValue)
                AgentStatusChip(title: "MODE", value: LocalTextModelRuntimeFactory.isRealLocalInferenceCompiled ? "GGUF" : "FIXTURE")
            }

            HStack(spacing: 8) {
                AgentStatusChip(title: "A9", value: coordinator.computePlan.mode.title)
                AgentStatusChip(
                    title: "FLY",
                    value: coordinator.computePlan.maleCNS.tier.rawValue + "·" + maleCNS.state.displayName
                )
            }
        }
        .padding(14)
        .background(VeilPanelShape(cut: 14, radius: 7).fill(VeilTheme.panel.opacity(0.72)))
        .overlay(VeilPanelShape(cut: 14, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
    }
}

private struct AgentStatusChip: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundColor(VeilTheme.mutedGold)
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
