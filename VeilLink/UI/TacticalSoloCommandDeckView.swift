import SwiftUI

/// Single-player presentation shell for the legacy deterministic TacticalState.
/// It restores a dedicated command-desk presentation without mutating the tactical
/// rules, VLGM payloads or replay semantics. Nearby play continues to use Tactical V2.
struct TacticalSoloCommandDeckView: View {
    let state: TacticalState
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onMove: (Int, Int) -> Void
    let onPass: () -> Void

    private var localUnits: Int {
        state.units(for: localPlayer).count
    }

    private var phaseText: String {
        if state.currentPlayer == localPlayer {
            return enabled ? "LOCAL ORDER" : "RESOLVING"
        }
        return "ENEMY PHASE"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                VeilLCDDisplay(title: "THEATER", value: "官渡")
                    .frame(maxWidth: .infinity)
                VeilLCDDisplay(title: "TURN", value: String(state.turn + 1))
                    .frame(width: 92)
                VeilLCDDisplay(title: "UNITS", value: String(localUnits))
                    .frame(width: 92)
            }

            TacticalBoardView(
                state: state,
                localPlayer: localPlayer,
                enabled: enabled,
                onMove: onMove,
                onPass: onPass
            )
            .padding(7)
            .background(Color.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
            )

            HStack(spacing: 8) {
                VeilIndicatorLamp(
                    active: state.currentPlayer == localPlayer,
                    color: VeilTheme.goldBright
                )
                Text(phaseText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(
                        state.currentPlayer == localPlayer
                        ? VeilTheme.gold
                        : VeilTheme.secondaryText
                    )
                Spacer()
                Label("确定性规则核", systemImage: "checkmark.shield.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(VeilTheme.secondaryText)
            }
            .padding(.horizontal, 3)
        }
        .veilGameConsole(emphasized: true, cornerRadius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("官渡决战单机战役指挥台")
    }
}
