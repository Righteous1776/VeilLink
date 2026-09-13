import SwiftUI

struct TacticalBoardView: View {
    let state: TacticalState
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onMove: (Int, Int) -> Void
    let onPass: () -> Void

    @State private var selectedUnitID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedUnit: TacticalUnit? {
        guard let selectedUnitID else { return nil }
        return state.unit(id: selectedUnitID)
    }

    private var legalDestinations: Set<Int> {
        guard enabled, let selectedUnit else { return [] }
        return state.legalDestinations(from: selectedUnit.position, actor: localPlayer)
    }

    var body: some View {
        VStack(spacing: 10) {
            battleHeader
            board
            selectionPanel
        }
        .onChange(of: state.turn) { _ in selectedUnitID = nil }
    }

    private var battleHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metric("回合", "\(min(state.round, TacticalState.maxRounds))/\(TacticalState.maxRounds)")
                factionMetric(.cao, value: "\(state.victoryPoints(for: .host))点")
                factionMetric(.yuan, value: "\(state.victoryPoints(for: .guest))点")
                metric("命令", "\(state.ordersRemaining)")
            }
            HStack(spacing: 7) {
                Image(systemName: state.currentPlayer == localPlayer ? "bolt.horizontal.circle.fill" : "hourglass.circle")
                    .font(.system(size: 12, weight: .semibold))
                Text(state.currentPlayer == localPlayer ? "轮到你下达命令" : "等待对方行动")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(state.lastActionText)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(state.currentPlayer == localPlayer ? VeilTheme.gold : VeilTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [
                        (state.currentPlayer == localPlayer ? VeilTheme.gold : VeilTheme.secondaryText).opacity(0.12),
                        Color.white.opacity(0.018)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(VeilPanelShape(cut: 8, radius: 5))
            .overlay(VeilPanelShape(cut: 8, radius: 5).stroke(VeilTheme.hairline, lineWidth: 1))
        }
    }


    private func factionMetric(_ faction: TacticalFaction, value: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                TacticalFactionFlagView(faction: faction, compact: true)
                Text(value)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(VeilTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Text(faction.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(VeilTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(VeilTheme.elevated.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(VeilTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(VeilTheme.elevated.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var board: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let hexWidth = width * TacticalLocalRenderCache.hexWidthFactor
            let hexHeight = width * TacticalLocalRenderCache.hexHeightFactor
            let boardHeight = hexHeight * (1 + 0.75 * CGFloat(TacticalState.rows - 1))
            let selected = selectedUnit
            let destinations = legalDestinations
            let activeUnitsByPosition: [Int: TacticalUnit] = state.units.reduce(into: [:]) { result, unit in
                if !unit.isDestroyed { result[unit.position] = unit }
            }

            ZStack(alignment: .topLeading) {
                ForEach(TacticalLocalRenderCache.cells) { layout in
                    let hex = TacticalState.hexes[layout.index]
                    let unit = activeUnitsByPosition[hex.index]
                    let isSelected = selected?.position == hex.index
                    let isLegal = destinations.contains(hex.index)
                    TacticalHexTile(
                        hex: hex,
                        unit: unit,
                        selected: isSelected,
                        legal: isLegal,
                        attack: selected.map { isLegal && state.isAttack(from: $0.position, to: hex.index) } ?? false,
                        acted: unit.map { state.actedUnitIDs.contains($0.id) } ?? false
                    )
                    .frame(width: hexWidth, height: hexHeight)
                    .scaleEffect(isSelected ? 1.025 : 1)
                    .zIndex(isSelected ? 2 : (isLegal ? 1 : 0))
                    .position(
                        x: layout.centerX * width,
                        y: layout.centerY * width
                    )
                    .onTapGesture { handleTap(hex.index) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: hex, unit: unit, isLegal: isLegal))
                }
            }
            .frame(width: width, height: boardHeight, alignment: .topLeading)
        }
        .aspectRatio(TacticalLocalRenderCache.boardAspectRatio, contentMode: .fit)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.20))
        .clipShape(VeilPanelShape(cut: 12, radius: 7))
        .overlay(VeilPanelShape(cut: 12, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private var selectionPanel: some View {
        if let selectedUnit {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        TacticalUnitCounterView(unit: selectedUnit, acted: false)
                            .scaleEffect(0.86)
                            .frame(width: 27, height: 25)
                        Text(selectedUnit.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(VeilTheme.text)
                    }
                    HStack(spacing: 8) {
                        Text("兵力 \(selectedUnit.steps)/\(selectedUnit.kind.maxSteps)")
                        Text(state.isSupplied(unitID: selectedUnit.id) ? "补给正常" : "补给中断")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(state.isSupplied(unitID: selectedUnit.id) ? VeilTheme.secondaryText : VeilTheme.gold)
                }
                Spacer()
                Text(legalDestinations.isEmpty ? "无可用行动" : "选择高亮六角格")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(VeilTheme.gold)
            }
            .padding(10)
            .background(VeilTheme.elevated.opacity(0.74))
            .clipShape(VeilPanelShape(cut: 9, radius: 6))
        } else {
            HStack(spacing: 10) {
                Text("◎")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(VeilTheme.gold)
                Text(enabled ? "点选己方算子，再选择机动或交战目标。" : "对方行动中，可查看战场态势。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                Spacer()
                if enabled {
                    Button("结束阶段", action: onPass)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.gold)
                }
            }
            .padding(10)
            .background(VeilTheme.elevated.opacity(0.64))
            .clipShape(VeilPanelShape(cut: 9, radius: 6))
        }

        if let combat = state.lastCombat {
            HStack(spacing: 9) {
                Text("战")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(VeilTheme.gold)
                Text("战斗结算 \(combat.attackerScore) : \(combat.defenderScore) · \(combat.summary)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(VeilTheme.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 10)
        }
    }

    private func handleTap(_ position: Int) {
        guard enabled else { return }
        if let selectedUnit, legalDestinations.contains(position) {
            onMove(selectedUnit.position, position)
            updateSelection(nil)
            return
        }
        if let unit = state.unit(at: position), unit.faction.player == localPlayer,
           !state.actedUnitIDs.contains(unit.id) {
            updateSelection(unit.id)
        } else {
            updateSelection(nil)
        }
    }

    private func updateSelection(_ unitID: String?) {
        if reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal {
            selectedUnitID = unitID
        } else {
            withAnimation(.easeOut(duration: 0.16)) { selectedUnitID = unitID }
        }
    }

    private func accessibilityLabel(for hex: TacticalHex, unit: TacticalUnit?, isLegal: Bool) -> String {
        var parts = [hex.name ?? hex.terrain.title]
        if let unit { parts.append("\(unit.faction.title)\(unit.name)") }
        if isLegal { parts.append("可行动") }
        return parts.joined(separator: "，")
    }

}

struct TacticalReplayBoardView: View {
    let state: TacticalState
    let localPlayer: MiniGamePlayer

    var body: some View {
        TacticalBoardView(state: state, localPlayer: localPlayer, enabled: false, onMove: { _, _ in }, onPass: {})
    }
}

private struct TacticalHexTile: View {
    let hex: TacticalHex
    let unit: TacticalUnit?
    let selected: Bool
    let legal: Bool
    let attack: Bool
    let acted: Bool

    var body: some View {
        ZStack {
            TacticalCachedHexShape()
                .fill(fillColor)
            TacticalCachedHexShape()
                .stroke(strokeColor, lineWidth: selected ? 2.2 : (legal ? 1.6 : 0.7))

            if legal {
                TacticalCachedHexShape()
                    .fill((attack ? Color.red : VeilTheme.gold).opacity(attack ? 0.09 : 0.055))
                    .padding(2)
            }

            TacticalTerrainCodeMark(terrain: hex.terrain)
                .padding(7)

            if let name = hex.name, unit == nil {
                Text(name)
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundColor(VeilTheme.text.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else if hex.isObjective, unit != nil {
                // Keep occupied objective labels from spilling into the next hex row.
                // The small gold notch preserves objective identity without fighting the counter.
                Circle()
                    .fill(VeilTheme.gold.opacity(0.72))
                    .frame(width: 4.5, height: 4.5)
                    .offset(y: 8.5)
            }

            if let unit {
                TacticalUnitCounterView(unit: unit, acted: acted)
            }

            if legal && unit == nil {
                Circle()
                    .fill(VeilTheme.gold.opacity(0.74))
                    .frame(width: 7, height: 7)
            }
            if attack {
                Circle()
                    .stroke(Color.red.opacity(0.86), lineWidth: 1.8)
                    .frame(width: 23, height: 23)
            }
        }
        .contentShape(TacticalCachedHexShape())
    }

    private var fillColor: Color {
        switch hex.terrain {
        case .plain: return Color(red: 0.18, green: 0.20, blue: 0.17)
        case .road: return Color(red: 0.24, green: 0.22, blue: 0.17)
        case .forest: return Color(red: 0.12, green: 0.22, blue: 0.16)
        case .hill: return Color(red: 0.25, green: 0.20, blue: 0.16)
        case .river: return Color(red: 0.10, green: 0.20, blue: 0.27)
        case .ford: return Color(red: 0.18, green: 0.25, blue: 0.26)
        case .camp: return Color(red: 0.25, green: 0.16, blue: 0.14)
        }
    }

    private var strokeColor: Color {
        if selected { return VeilTheme.gold }
        if attack { return Color.red.opacity(0.8) }
        if legal { return VeilTheme.gold.opacity(0.75) }
        if hex.isObjective { return VeilTheme.mutedGold.opacity(0.65) }
        return Color.white.opacity(0.11)
    }

}
