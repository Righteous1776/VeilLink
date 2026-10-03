import SwiftUI

struct TacticalSoloV2View: View {
    @ObservedObject var model: AppModel

    @State private var map: TacticalV2.Map?
    @State private var truth: TacticalV2.TruthStateV2?
    @State private var redacted: TacticalV2.RedactedTacticalViewV2?
    @State private var supplyField: TacticalV2.SupplyFieldV1?
    @State private var intelMemory = TacticalV2.IntelMemoryV2()
    @State private var visibilityCache = TacticalV2.VisibilityCacheV2()
    @State private var sessionID = UUID().uuidString
    @State private var lastResolution = "等待下达第一道军令"
    @State private var errorText: String?

    var body: some View {
        Group {
            if let map, let truth, let redacted {
                GeometryReader { proxy in
                    ZStack(alignment: .topTrailing) {
                        TacticalLandscapeShellV2(
                            map: map,
                            redacted: redacted,
                            supplyField: supplyField,
                            simulationTurn: truth.simulationTurn,
                            onSubmitOrder: submit(order:)
                        )

                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("V2 SOLO")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                Text("第 \(truth.simulationTurn + 1) 回合")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(VeilTheme.goldBright)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.52))
                            .clipShape(Capsule())

                            Text(lastResolution)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.white.opacity(0.82))
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.46))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            if proxy.size.width < 650 {
                                Label("建议横屏体验 48×27 战役地图", systemImage: "rotate.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(VeilTheme.gold)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.52))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(10)
                    }
                }
            } else if let errorText {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(VeilTheme.gold)
                    Text("官渡战役 V2 无法载入")
                        .font(.headline)
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("重新载入") { startNewCampaign() }
                        .buttonStyle(VeilGamePrimaryButtonStyle())
                }
                .padding(24)
                .veilCard(emphasized: true)
                .padding(16)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在展开 48×27 官渡战役地图…")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("官渡决战 · 战役 V2")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("重开") {
                    startNewCampaign()
                    model.haptics.selection()
                }
                .foregroundColor(VeilTheme.gold)
            }
        }
        .onAppear {
            model.agent.setComputeFocus(.gameDecision)
            if map == nil { startNewCampaign() }
        }
        .onDisappear {
            model.agent.setComputeFocus(.idle)
        }
    }

    private func startNewCampaign() {
        do {
            let loadedMap = try TacticalV2.ScenarioBundleV2.loadGuanduMap()
            let nextSessionID = UUID().uuidString
            let initial = TacticalV2.GuanduScenarioV2.initialTruthState(
                map: loadedMap,
                seed: TacticalV2.GuanduScenarioV2.deterministicSeed(
                    sessionID: nextSessionID
                )
            )

            sessionID = nextSessionID
            map = loadedMap
            truth = initial
            intelMemory = TacticalV2.IntelMemoryV2()
            visibilityCache = TacticalV2.VisibilityCacheV2()
            errorText = nil
            lastResolution = "曹军先行 · 选择部队并在地图上拖出行军路线"
            rebuildPlayerProjection(state: initial, map: loadedMap)
        } catch {
            map = nil
            truth = nil
            redacted = nil
            supplyField = nil
            errorText = error.localizedDescription
        }
    }

    private func submit(order: TacticalV2.OrderV2) {
        guard let map, let truth else { return }

        do {
            let result = try TacticalV2.SoloRuntimeV2.resolveTurn(
                state: truth,
                map: map,
                humanOrder: order
            )
            self.truth = result.state
            rebuildPlayerProjection(state: result.state, map: map)

            let advances = result.frame.events.filter { $0.kind == .unitAdvanced }.count
            let contacts = result.frame.events.filter { $0.kind == .contact }.count
            lastResolution = "第 \(result.frame.resolvedTurn + 1) 回合结算 · 推进 \(advances) · 接敌 \(contacts)"
            model.haptics.impact()
        } catch {
            errorText = "军令未能结算：\(error.localizedDescription)"
        }
    }

    private func rebuildPlayerProjection(
        state: TacticalV2.TruthStateV2,
        map: TacticalV2.Map
    ) {
        var memory = intelMemory
        var cache = visibilityCache
        let intel = memory.project(
            truthUnits: state.units,
            map: map,
            viewer: .cao,
            simulationTurn: state.simulationTurn,
            visibilityCache: &cache,
            revision: state.revision
        )

        intelMemory = memory
        visibilityCache = cache

        let nextRedacted = TacticalV2.RedactedTacticalViewV2(intel: intel)
        redacted = nextRedacted
        supplyField = TacticalV2.OperationalFieldBuilderV2.playerVisibleSupplyField(
            map: map,
            redacted: nextRedacted,
            revision: state.revision.supply
        )
    }
}
