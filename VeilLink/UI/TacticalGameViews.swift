import SwiftUI

private enum TacticalIntelLayer: String, CaseIterable, Identifiable {
    case battlefield
    case supply
    case threat
    case objectives

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battlefield: return "战场"
        case .supply: return "补给"
        case .threat: return "威胁"
        case .objectives: return "目标"
        }
    }

    var glyph: String {
        switch self {
        case .battlefield: return "战"
        case .supply: return "粮"
        case .threat: return "危"
        case .objectives: return "点"
        }
    }
}

struct TacticalBoardView: View {
    let state: TacticalState
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onMove: (Int, Int) -> Void
    let onPass: () -> Void

    @State private var selectedUnitID: String?
    @State private var pendingAttackTargetID: String?
    @State private var intelLayer: TacticalIntelLayer = .battlefield
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var localFaction: TacticalFaction { localPlayer == .host ? .cao : .yuan }

    private var selectedUnit: TacticalUnit? {
        guard let selectedUnitID else { return nil }
        return state.unit(id: selectedUnitID)
    }

    private var pendingAttackTarget: TacticalUnit? {
        guard let pendingAttackTargetID else { return nil }
        return state.unit(id: pendingAttackTargetID)
    }

    private var legalDestinations: Set<Int> {
        guard enabled, let selectedUnit, selectedUnit.faction.player == localPlayer else { return [] }
        return state.legalDestinations(from: selectedUnit.position, actor: localPlayer)
    }

    private var combatForecast: TacticalCombatForecast? {
        guard let selectedUnit, let pendingAttackTarget else { return nil }
        return state.combatForecast(attackerID: selectedUnit.id, defenderID: pendingAttackTarget.id)
    }

    var body: some View {
        VStack(spacing: 9) {
            battleHeader
            intelLayerBar
            board
            layerSummary
            selectionPanel
        }
        .onChange(of: state.turn) { _ in
            selectedUnitID = nil
            pendingAttackTargetID = nil
        }
        .onChange(of: intelLayer) { _ in pendingAttackTargetID = nil }
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
                Text(state.currentPlayer == localPlayer ? "●" : "◷")
                    .font(.system(size: 10, weight: .heavy))
                Text(state.currentPlayer == localPlayer ? "轮到你下达命令" : "等待对方行动")
                    .font(.caption.weight(.semibold))
                Text("· \(localFaction.title)视角")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(VeilTheme.tertiaryText)
                Spacer(minLength: 6)
                Text(state.lastActionText)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
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

    private var intelLayerBar: some View {
        HStack(spacing: 6) {
            ForEach(TacticalIntelLayer.allCases) { layer in
                Button {
                    if reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal {
                        intelLayer = layer
                    } else {
                        withAnimation(.easeOut(duration: 0.14)) { intelLayer = layer }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(layer.glyph)
                            .font(.system(size: 9, weight: .heavy, design: .serif))
                        Text(layer.title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(intelLayer == layer ? VeilTheme.gold : VeilTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background((intelLayer == layer ? VeilTheme.gold : Color.white).opacity(intelLayer == layer ? 0.11 : 0.025))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(intelLayer == layer ? VeilTheme.mutedGold.opacity(0.55) : VeilTheme.hairline, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
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
            let localSupply = state.supplyNetwork(for: localFaction)
            let friendlyThreat = state.threatenedHexes(by: localFaction)
            let enemyThreat = state.threatenedHexes(by: localFaction.opponent)
            let selectedCommandZone: Set<Int> = selected?.kind == .command ? state.commandZone(for: selected?.faction ?? localFaction) : []
            let activeUnitsByPosition: [Int: TacticalUnit] = state.units.reduce(into: [:]) { result, unit in
                if !unit.isDestroyed { result[unit.position] = unit }
            }

            ZStack(alignment: .topLeading) {
                ForEach(TacticalLocalRenderCache.cells) { layout in
                    let hex = TacticalState.hexes[layout.index]
                    let unit = activeUnitsByPosition[hex.index]
                    let isSelected = selected?.position == hex.index
                    let isLegal = destinations.contains(hex.index)
                    let display = TacticalLocalRenderCache.displayCenter(for: layout, flipped: localPlayer == .guest)
                    TacticalHexTile(
                        hex: hex,
                        unit: unit,
                        selected: isSelected,
                        legal: isLegal,
                        attack: selected.map { isLegal && state.isAttack(from: $0.position, to: hex.index) } ?? false,
                        attackTarget: pendingAttackTarget?.position == hex.index,
                        acted: unit.map { state.actedUnitIDs.contains($0.id) } ?? false,
                        supplyReachable: intelLayer == .supply && localSupply.contains(hex.index),
                        supplyBroken: intelLayer == .supply && unit?.faction == localFaction && unit.map { !state.isSupplied(unitID: $0.id) } == true,
                        friendlyThreat: intelLayer == .threat && friendlyThreat.contains(hex.index),
                        enemyThreat: intelLayer == .threat && enemyThreat.contains(hex.index),
                        commandZone: selectedCommandZone.contains(hex.index),
                        objectivePressure: intelLayer == .objectives && hex.isObjective ? state.objectivePressure(at: hex.index) : nil,
                        localFaction: localFaction
                    )
                    .frame(width: hexWidth, height: hexHeight)
                    .scaleEffect(isSelected ? 1.035 : 1)
                    .zIndex(isSelected ? 3 : (pendingAttackTarget?.position == hex.index ? 2 : (isLegal ? 1 : 0)))
                    .position(x: display.x * width, y: display.y * width)
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

    private var layerSummary: some View {
        HStack(spacing: 7) {
            Text(intelLayer.glyph)
                .font(.system(size: 10, weight: .heavy, design: .serif))
                .foregroundColor(VeilTheme.gold)
            Text(layerSummaryText)
                .font(.caption2.monospacedDigit())
                .foregroundColor(VeilTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(VeilTheme.elevated.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var layerSummaryText: String {
        switch intelLayer {
        case .battlefield:
            return "己方完整算子 \(state.units(for: localPlayer).count) · 点选任意算子可查看战术数据"
        case .supply:
            let friendly = state.units(for: localPlayer)
            let supplied = friendly.filter { state.isSupplied(unitID: $0.id) }.count
            return "己方补给 \(supplied)/\(friendly.count) · 亮区为当前可通达补给网"
        case .threat:
            let ours = state.threatenedHexes(by: localFaction).count
            let enemy = state.threatenedHexes(by: localFaction.opponent).count
            return "己方威胁 \(ours) 格 · 敌方威胁 \(enemy) 格 · 重叠区风险最高"
        case .objectives:
            return TacticalState.hexes.filter(\.isObjective).map { hex in
                let pressure = state.objectivePressure(at: hex.index)
                return "\(hex.name ?? "目标") \(pressure.caoStrength):\(pressure.yuanStrength)"
            }.joined(separator: " · ")
        }
    }

    @ViewBuilder
    private var selectionPanel: some View {
        if let forecast = combatForecast, let attacker = selectedUnit, let defender = pendingAttackTarget {
            combatPreview(forecast: forecast, attacker: attacker, defender: defender)
        }

        if let selectedUnit {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    TacticalUnitCounterView(unit: selectedUnit, acted: state.actedUnitIDs.contains(selectedUnit.id))
                        .scaleEffect(0.90)
                        .frame(width: 29, height: 27)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(selectedUnit.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(VeilTheme.text)
                            if selectedUnit.faction != localFaction {
                                Text("敌")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundColor(Color.red.opacity(0.88))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                        }
                        HStack(spacing: 7) {
                            Text("兵力 \(selectedUnit.steps)/\(selectedUnit.kind.maxSteps)")
                            Text(state.isSupplied(unitID: selectedUnit.id) ? "补给正常" : "补给中断")
                            Text(state.commandZone(for: selectedUnit.faction).contains(selectedUnit.position) ? "受中军支援" : "无中军支援")
                        }
                        .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                        .foregroundColor(state.isSupplied(unitID: selectedUnit.id) ? VeilTheme.secondaryText : VeilTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    }
                    Spacer(minLength: 4)
                    Button("关闭") { updateSelection(nil) }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(VeilTheme.secondaryText)
                }

                HStack(spacing: 6) {
                    unitStat("攻", selectedUnit.kind.attack)
                    unitStat("防", selectedUnit.kind.defense)
                    unitStat("移", selectedUnit.kind.movement)
                    unitStat("射", selectedUnit.kind.attackRange)
                    unitTextStat("地形", state.hex(at: selectedUnit.position)?.terrain.title ?? "-")
                }

                HStack {
                    Text(selectionInstruction(for: selectedUnit))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(VeilTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer()
                    if enabled, selectedUnit.faction.player == localPlayer,
                       !state.actedUnitIDs.contains(selectedUnit.id), pendingAttackTargetID == nil {
                        Text("可达 \(legalDestinations.count) 格")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(VeilTheme.tertiaryText)
                    }
                }
            }
            .padding(10)
            .background(VeilTheme.elevated.opacity(0.74))
            .clipShape(VeilPanelShape(cut: 9, radius: 6))
        } else {
            HStack(spacing: 10) {
                Text("◎")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(VeilTheme.gold)
                Text(enabled ? "点选己方算子下达命令；也可点选敌军查看态势。" : "对方行动中，仍可查看全部战场态势。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(2)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
            }
            .padding(.horizontal, 10)
        }
    }

    private func combatPreview(forecast: TacticalCombatForecast, attacker: TacticalUnit, defender: TacticalUnit) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("交战预估")
                    .font(.caption.weight(.bold))
                    .foregroundColor(VeilTheme.gold)
                Text("\(attacker.name) → \(defender.name)")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(1)
                Spacer()
            }
            HStack(spacing: 6) {
                forecastMetric("造成损失", forecast.defenderLossChancePercent)
                forecastMetric("击溃", forecast.defenderDestroyedChancePercent)
                forecastMetric("己方受损", forecast.attackerLossChancePercent)
                forecastMetric("僵持", forecast.stalemateChancePercent)
            }
            Text("基础 \(forecast.attackerBaseScore):\(forecast.defenderBaseScore) · 守方地形 +\(forecast.terrainBonus) · 中军 \(signed(forecast.attackerCommandBonus))/\(signed(forecast.defenderCommandBonus)) · 补给 \(signed(forecast.attackerSupplyModifier))/\(signed(forecast.defenderSupplyModifier))")
                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                .foregroundColor(VeilTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.60)
            HStack(spacing: 8) {
                Button("取消") { pendingAttackTargetID = nil }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Button("确认交战") {
                    onMove(attacker.position, defender.position)
                    updateSelection(nil)
                }
                .font(.caption.weight(.bold))
                .foregroundColor(VeilTheme.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(VeilTheme.gold.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(10)
        .background(Color.red.opacity(0.055))
        .clipShape(VeilPanelShape(cut: 9, radius: 6))
        .overlay(VeilPanelShape(cut: 9, radius: 6).stroke(Color.red.opacity(0.20), lineWidth: 0.8))
    }

    private func forecastMetric(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(value)%")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundColor(VeilTheme.text)
            Text(title)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(VeilTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func unitStat(_ title: String, _ value: Int) -> some View {
        unitTextStat(title, "\(value)")
    }

    private func unitTextStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }

    private func selectionInstruction(for unit: TacticalUnit) -> String {
        if unit.faction.player != localPlayer { return "敌方算子 · 仅查看信息" }
        if state.actedUnitIDs.contains(unit.id) { return "本阶段已行动" }
        if !enabled { return "等待本方行动阶段" }
        if legalDestinations.isEmpty { return "当前无合法行动" }
        return "移动格直接执行；攻击目标先显示胜率预估，再确认交战"
    }

    private func handleTap(_ position: Int) {
        if enabled, let selectedUnit, selectedUnit.faction.player == localPlayer,
           legalDestinations.contains(position) {
            if let target = state.unit(at: position), target.faction != selectedUnit.faction {
                pendingAttackTargetID = target.id
                return
            }
            if state.unit(at: position) == nil {
                onMove(selectedUnit.position, position)
                updateSelection(nil)
                return
            }
        }

        if let unit = state.unit(at: position) {
            updateSelection(unit.id)
        } else {
            updateSelection(nil)
        }
    }

    private func updateSelection(_ unitID: String?) {
        pendingAttackTargetID = nil
        if reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal {
            selectedUnitID = unitID
        } else {
            withAnimation(.easeOut(duration: 0.16)) { selectedUnitID = unitID }
        }
    }

    private func accessibilityLabel(for hex: TacticalHex, unit: TacticalUnit?, isLegal: Bool) -> String {
        var parts = [hex.name ?? hex.terrain.title]
        if let unit {
            parts.append("\(unit.faction.title)\(unit.name)")
            parts.append(state.isSupplied(unitID: unit.id) ? "补给正常" : "补给中断")
        }
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
    let attackTarget: Bool
    let acted: Bool
    let supplyReachable: Bool
    let supplyBroken: Bool
    let friendlyThreat: Bool
    let enemyThreat: Bool
    let commandZone: Bool
    let objectivePressure: TacticalObjectivePressure?
    let localFaction: TacticalFaction

    var body: some View {
        ZStack {
            TacticalCachedHexShape()
                .fill(fillColor)

            if supplyReachable {
                TacticalCachedHexShape()
                    .fill(Color.green.opacity(0.075))
                    .padding(1.5)
            }
            if friendlyThreat {
                TacticalCachedHexShape()
                    .fill(VeilTheme.gold.opacity(0.055))
                    .padding(1.5)
            }
            if enemyThreat {
                TacticalCachedHexShape()
                    .fill(Color.red.opacity(friendlyThreat ? 0.10 : 0.075))
                    .padding(1.5)
            }
            if let objectivePressure {
                TacticalCachedHexShape()
                    .fill(objectivePressureColor(objectivePressure).opacity(0.10))
                    .padding(1.5)
            }

            TacticalCachedHexShape()
                .stroke(strokeColor, lineWidth: selected ? 2.2 : (attackTarget ? 2.0 : (legal ? 1.6 : 0.7)))

            if commandZone {
                TacticalCachedHexShape()
                    .stroke(VeilTheme.gold.opacity(0.45), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                    .padding(2.5)
            }

            if legal {
                TacticalCachedHexShape()
                    .fill((attack ? Color.red : VeilTheme.gold).opacity(attack ? 0.09 : 0.055))
                    .padding(2)
            }

            TacticalTerrainCodeMark(terrain: hex.terrain)
                .padding(7)

            if let name = hex.name, unit == nil {
                VStack(spacing: 0) {
                    Text(name)
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(VeilTheme.text.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let objectivePressure {
                        Text("\(objectivePressure.caoStrength):\(objectivePressure.yuanStrength)")
                            .font(.system(size: 5.3, weight: .bold).monospacedDigit())
                            .foregroundColor(objectivePressureColor(objectivePressure).opacity(0.88))
                    }
                }
            } else if hex.isObjective, unit != nil {
                Circle()
                    .fill(objectivePressure.map(objectivePressureColor) ?? VeilTheme.gold.opacity(0.72))
                    .frame(width: 4.5, height: 4.5)
                    .offset(y: 8.5)
            }

            if let unit {
                TacticalUnitCounterView(unit: unit, acted: acted)
                    .overlay(alignment: .topTrailing) {
                        if supplyBroken {
                            Text("!")
                                .font(.system(size: 7, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 10, height: 10)
                                .background(Color.red.opacity(0.86))
                                .clipShape(Circle())
                                .offset(x: 3, y: -3)
                        }
                    }
            }

            if legal && unit == nil {
                Circle()
                    .fill(VeilTheme.gold.opacity(0.74))
                    .frame(width: 7, height: 7)
            }
            if attack {
                Circle()
                    .stroke(Color.red.opacity(attackTarget ? 1.0 : 0.86), lineWidth: attackTarget ? 2.2 : 1.8)
                    .frame(width: attackTarget ? 24 : 23, height: attackTarget ? 24 : 23)
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
        if attackTarget { return Color.red.opacity(0.96) }
        if attack { return Color.red.opacity(0.8) }
        if legal { return VeilTheme.gold.opacity(0.75) }
        if hex.isObjective { return VeilTheme.mutedGold.opacity(0.65) }
        return Color.white.opacity(0.11)
    }

    private func objectivePressureColor(_ pressure: TacticalObjectivePressure) -> Color {
        guard let leader = pressure.leader else { return VeilTheme.mutedGold }
        return leader == localFaction ? VeilTheme.gold : Color.red
    }
}
