import SwiftUI

/// Offline entry for the original 48×27 Guandu campaign map. It deliberately
/// bypasses the legacy 7×9 compatibility board used by LocalAIGameView.
struct TacticalV2SoloView: View {
    @ObservedObject var model: AppModel

    @State private var map: TacticalV2.Map?
    @State private var truth: TacticalV2.TruthStateV2?
    @State private var redacted: TacticalV2.RedactedTacticalViewV2?
    @State private var supplyField: TacticalV2.SupplyFieldV1?
    @State private var intelMemory = TacticalV2.IntelMemoryV2()
    @State private var visibilityCache = TacticalV2.VisibilityCacheV2()
    @State private var sessionID = UUID().uuidString
    @State private var statusText = "正在装载 48×27 官渡战场…"
    @State private var errorText: String?

    var body: some View {
        Group {
            if let map, let truth, let redacted {
                TacticalLandscapeShellV2(
                    map: map,
                    redacted: redacted,
                    supplyField: supplyField,
                    simulationTurn: truth.simulationTurn,
                    onSubmitOrder: resolvePlayerOrder
                )
            } else if let errorText {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(VeilTheme.danger)
                    Text("大战场载入失败").font(.headline)
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    Button("重新载入") { restart() }
                        .buttonStyle(.borderedProminent)
                        .tint(VeilTheme.gold)
                }
                .padding(24)
            } else {
                ProgressView(statusText)
            }
        }
        .background(VeilTheme.background.ignoresSafeArea())
        .navigationTitle("三国兵器 · 官渡大战场")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("重开") { restart() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text(statusText)
                .font(.caption2.monospaced())
                .foregroundColor(VeilTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(VeilTheme.panel.opacity(0.94))
        }
        .onAppear {
            model.agent.setComputeFocus(.gameDecision)
            if map == nil { restart() }
        }
        .onDisappear {
            model.agent.setComputeFocus(.idle)
        }
    }

    private func restart() {
        do {
            let loaded = try TacticalV2.ScenarioBundleV2.loadGuanduMap()
            sessionID = UUID().uuidString
            map = loaded
            truth = TacticalV2.GuanduScenarioV2.initialTruthState(
                map: loaded,
                seed: TacticalV2.GuanduScenarioV2.deterministicSeed(
                    sessionID: sessionID
                )
            )
            intelMemory = TacticalV2.IntelMemoryV2()
            visibilityCache = TacticalV2.VisibilityCacheV2()
            statusText = "曹军回合 1 · 选择部队并在大战场拖出路线"
            errorText = nil
            refreshPresentation()
        } catch {
            map = nil
            truth = nil
            redacted = nil
            errorText = error.localizedDescription
        }
    }

    private func resolvePlayerOrder(_ playerOrder: TacticalV2.OrderV2) {
        guard let map, var next = truth,
              playerOrder.actor == .cao,
              playerOrder.issuedTurn == next.simulationTurn else {
            return
        }

        do {
            let enemyOrder = makeEnemyOrder(state: next, map: map)
            let playerReveal = TacticalV2.RevealV2(
                actor: .cao,
                turn: next.simulationTurn,
                batch: .init(orders: [playerOrder]),
                nonce: TacticalV2.StableHash64.fnv1a("solo-player|\(sessionID)|\(next.simulationTurn)")
            )
            let enemyReveal = TacticalV2.RevealV2(
                actor: .yuan,
                turn: next.simulationTurn,
                batch: .init(orders: [enemyOrder]),
                nonce: TacticalV2.StableHash64.fnv1a("solo-enemy|\(sessionID)|\(next.simulationTurn)")
            )

            var round = TacticalV2.WEGORoundV2(turn: next.simulationTurn)
            try round.commit(playerReveal.commitment())
            try round.commit(enemyReveal.commitment())
            try round.beginReveal()
            try round.reveal(playerReveal, map: map)
            try round.reveal(enemyReveal, map: map)
            let frame = try TacticalV2.WEGOResolverV2.resolve(
                state: &next,
                map: map,
                round: &round
            )
            try round.markObserved()
            truth = next
            let contacts = frame.events.filter { $0.kind == .contact }.count
            statusText = contacts > 0
                ? "回合 \(next.simulationTurn + 1) · 发生 \(contacts) 次接触，重新评估路线"
                : "回合 \(next.simulationTurn + 1) · 袁军已同步行动"
            refreshPresentation()
            model.haptics.impact()
        } catch {
            errorText = error.localizedDescription
            model.haptics.error()
        }
    }

    private func makeEnemyOrder(
        state: TacticalV2.TruthStateV2,
        map: TacticalV2.Map
    ) -> TacticalV2.OrderV2 {
        let enemies = state.units
            .filter { $0.faction == .yuan && $0.steps > 0 }
            .sorted { $0.id < $1.id }
        let playerUnits = state.units
            .filter { $0.faction == .cao && $0.steps > 0 }
        guard !enemies.isEmpty, !playerUnits.isEmpty else {
            return passOrder(turn: state.simulationTurn)
        }

        let unit = enemies[Int(state.simulationTurn) % enemies.count]
        guard let target = playerUnits.min(by: {
            map.distance(unit.cell, $0.cell) < map.distance(unit.cell, $1.cell)
        }) else {
            return passOrder(turn: state.simulationTurn)
        }

        let blocked = Set(state.units.filter { $0.steps > 0 }.map(\.cell))
            .subtracting([unit.cell, target.cell])
        guard let route = TacticalV2.RoutePlannerV2.plan(
            map: map,
            from: unit.cell,
            to: target.cell,
            blocked: blocked
        ), route.cells.count >= 2 else {
            return passOrder(turn: state.simulationTurn)
        }

        return TacticalV2.OrderV2(
            id: "solo-yuan-\(state.simulationTurn)-\(unit.id)",
            kind: .march,
            actor: .yuan,
            issuedTurn: state.simulationTurn,
            unitID: unit.id,
            routeCells: route.cells.prefix(2).map { UInt16($0) }
        )
    }

    private func passOrder(turn: Int32) -> TacticalV2.OrderV2 {
        TacticalV2.OrderV2(
            id: "solo-yuan-pass-\(turn)",
            kind: .pass,
            actor: .yuan,
            issuedTurn: turn,
            unitID: nil,
            routeCells: []
        )
    }

    private func refreshPresentation() {
        guard let map, let truth else { return }
        let intel = intelMemory.project(
            truthUnits: truth.units,
            map: map,
            viewer: .cao,
            simulationTurn: truth.simulationTurn,
            visibilityCache: &visibilityCache,
            revision: truth.revision
        )
        let view = TacticalV2.RedactedTacticalViewV2(intel: intel)
        redacted = view
        supplyField = TacticalV2.OperationalFieldBuilderV2.playerVisibleSupplyField(
            map: map,
            redacted: view,
            revision: truth.revision.supply
        )
    }
}
