import SwiftUI

/// Restores the existing Guandu 48x27 map as a standalone offline WEGO match.
/// Uses the shipping TacticalV2 map, redacted field, route UI and resolver.
/// This does not modify the BLE game wire contract or legacy save format.
struct VeilGuanduGrandMapSoloView: View {
    @State private var map: TacticalV2.Map?
    @State private var truth: TacticalV2.TruthStateV2?
    @State private var redacted: TacticalV2.RedactedTacticalViewV2?
    @State private var supply: TacticalV2.SupplyFieldV1?
    @State private var status = "正在载入官渡 48×27 大地图…"
    @State private var issue: String?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("官渡大战场 · 48×27").font(.headline)
                Spacer()
                if let truth {
                    Text("回合 \(truth.simulationTurn + 1)")
                        .font(.caption.monospacedDigit()).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            if let map, let truth, let redacted {
                TacticalLandscapeShellV2(
                    map: map,
                    redacted: redacted,
                    supplyField: supply,
                    simulationTurn: truth.simulationTurn,
                    onSubmitOrder: submit(_:)
                )
                Text(status).font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                Button("重新开始官渡战役") { startNewCampaign() }
                    .buttonStyle(.bordered)
            } else {
                ProgressView(status)
                Button("重新加载大地图") { startNewCampaign() }
                    .buttonStyle(.bordered)
            }
        }
        .navigationTitle("三国兵棋 · 大战场")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if map == nil { startNewCampaign() } }
        .alert("大战场", isPresented: Binding(
            get: { issue != nil }, set: { if !$0 { issue = nil } }
        )) { Button("确定", role: .cancel) { issue = nil } }
        message: { Text(issue ?? "") }
    }

    private func startNewCampaign() {
        do {
            let loaded = try TacticalV2.ScenarioBundleV2.loadGuanduMap()
            guard loaded.width == 48, loaded.height == 27 else {
                status = "大地图资源尺寸错误"
                return
            }
            let state = TacticalV2.GuanduScenarioV2.initialTruthState(
                map: loaded,
                seed: TacticalV2.GuanduScenarioV2.deterministicSeed(sessionID: "offline-solo-guandu")
            )
            map = loaded
            truth = state
            status = "曹军本地单机 · 拖动军队路线下达命令，袁军按确定性策略应对。"
            refreshIntel(map: loaded, state: state)
        } catch {
            map = nil
            truth = nil
            redacted = nil
            supply = nil
            issue = "官渡大地图加载失败：\(error.localizedDescription)"
            status = "无法打开 48×27 地图资源"
        }
    }

    private func submit(_ order: TacticalV2.OrderV2) {
        guard let map, var state = truth else { return }
        guard order.actor == .cao,
              order.issuedTurn == state.simulationTurn else {
            issue = "命令不属于当前回合的曹军。"
            return
        }
        do {
            let enemyOrder = makeEnemyOrder(map: map, state: state)
            var round = TacticalV2.WEGORoundV2(turn: state.simulationTurn)
            let myReveal = TacticalV2.RevealV2(
                actor: .cao,
                turn: state.simulationTurn,
                batch: TacticalV2.OrderBatchV2(orders: [order]),
                nonce: UInt64(state.simulationTurn) &+ 11
            )
            let theirReveal = TacticalV2.RevealV2(
                actor: .yuan,
                turn: state.simulationTurn,
                batch: TacticalV2.OrderBatchV2(orders: [enemyOrder]),
                nonce: UInt64(state.simulationTurn) &+ 47
            )
            try round.commit(myReveal.commitment())
            try round.commit(theirReveal.commitment())
            try round.beginReveal()
            try round.reveal(myReveal, map: map)
            try round.reveal(theirReveal, map: map)
            let frame = try TacticalV2.WEGOResolverV2.resolve(state: &state, map: map, round: &round)
            truth = state
            refreshIntel(map: map, state: state)
            status = "已结算第 \(frame.resolvedTurn + 1) 回合 · \(frame.events.count) 个战场事件"
        } catch {
            issue = "战役命令未结算，当前战场不改变：\(error.localizedDescription)"
        }
    }

    private func makeEnemyOrder(
        map: TacticalV2.Map,
        state: TacticalV2.TruthStateV2
    ) -> TacticalV2.OrderV2 {
        let turn = state.simulationTurn
        let cao = state.units.filter { $0.faction == .cao }
        let yuan = state.units.filter { $0.faction == .yuan }
        for unit in yuan.sorted(by: { $0.id < $1.id }) {
            guard let target = cao.min(by: {
                map.distance(unit.cell, $0.cell) < map.distance(unit.cell, $1.cell)
            }) else { continue }
            let next = map.neighbors(of: unit.cell)
                .filter { candidate in
                    !state.units.contains(where: { occupied in occupied.cell == candidate })
                }
                .min(by: { map.distance($0, target.cell) < map.distance($1, target.cell) })
            if let next, map.distance(next, target.cell) < map.distance(unit.cell, target.cell),
               UInt16(exactly: unit.cell) != nil, UInt16(exactly: next) != nil {
                return TacticalV2.OrderV2(
                    id: "yuan-solo-\(turn)-\(unit.id)",
                    kind: .march, actor: .yuan, issuedTurn: turn,
                    unitID: unit.id, routeCells: [UInt16(unit.cell), UInt16(next)]
                )
            }
        }
        return TacticalV2.OrderV2(
            id: "yuan-pass-\(turn)", kind: .pass, actor: .yuan,
            issuedTurn: turn, unitID: nil, routeCells: []
        )
    }

    private func refreshIntel(map: TacticalV2.Map, state: TacticalV2.TruthStateV2) {
        let friendlies = state.units.filter { $0.faction == .cao }
        var visible = Set<Int>()
        for unit in friendlies {
            visible.formUnion(TacticalV2.VisibilityEngineV2.visibleCells(
                from: unit.cell, map: map,
                profile: TacticalV2.VisibilityProfile.standard(for: unit.kind)
            ))
        }
        let contacts: [TacticalV2.IntelContact] = state.units
            .filter { $0.faction == .yuan && visible.contains($0.cell) }
            .map { unit in
                TacticalV2.IntelContact(
                    contactID: "solo-\(unit.id)", level: .confirmed,
                    estimatedCell: unit.cell, uncertaintyRadius: 0,
                    kindEstimate: unit.kind, stepsEstimate: unit.steps,
                    lastObservedTurn: state.simulationTurn, confidencePermille: 1000
                )
            }
        let intel = TacticalV2.PlayerIntelState(
            viewer: .cao, exploredCells: visible, visibleCells: visible,
            friendlyUnits: friendlies.map {
                TacticalV2.PlayerIntelState.RedactedFriendlyUnit(
                    id: $0.id, kind: $0.kind, cell: $0.cell, steps: $0.steps
                )
            }, contacts: contacts
        )
        let projected = TacticalV2.RedactedTacticalViewV2(intel: intel)
        redacted = projected
        supply = TacticalV2.OperationalFieldBuilderV2.playerVisibleSupplyField(
            map: map, redacted: projected, revision: state.revision.supply
        )
    }
}
