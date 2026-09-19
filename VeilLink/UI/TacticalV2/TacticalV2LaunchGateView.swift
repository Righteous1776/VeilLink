import SwiftUI
import Foundation

struct TacticalV2LaunchGateView: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary
    let session: MiniGameSessionSnapshot
    let messages: [ChatMessage]
    let legacyState: TacticalState
    let legacyEnabled: Bool
    let onLegacyMove: (Int, Int) -> Void
    let onLegacyPass: () -> Void

    @State private var map: TacticalV2.Map?
    @State private var snapshot: TacticalV2.ChatSessionSnapshotV2?
    @State private var redacted: TacticalV2.RedactedTacticalViewV2?
    @State private var playerSupplyField: TacticalV2.SupplyFieldV1?
    @State private var intelMemory = TacticalV2.IntelMemoryV2()
    @State private var visibilityCache = TacticalV2.VisibilityCacheV2()
    @State private var sentHelloThisAppearance = false
    @State private var errorText: String?

    private var localActor: TacticalV2.Faction {
        session.hostIsLocal ? .cao : .yuan
    }

    var body: some View {
        Group {
            if let snapshot,
               !snapshot.divergenceTurns.isEmpty {
                legacyFallback(
                    title: "战役 V2 状态校验不一致",
                    detail: "双方状态摘要出现分歧。已暂停 V2 命令发送，避免继续扩大不同步。",
                    enabled: false
                )
            } else if let map,
                      let snapshot,
                      snapshot.negotiation == .compatible,
                      let redacted {
                TacticalLandscapeShellV2(
                    map: map,
                    redacted: redacted,
                    supplyField: playerSupplyField,
                    simulationTurn: snapshot.state.simulationTurn,
                    onSubmitOrder: submit(order:)
                )
            } else if snapshot?.negotiation == .incompatible {
                legacyFallback(
                    title: "战役 V2 不兼容",
                    detail: "双方地图或规则版本不同，本局继续使用旧版兼容模式。",
                    enabled: legacyEnabled
                )
            } else {
                legacyFallback(
                    title: "正在协商战役 V2",
                    detail: "双方都支持 48×27 大地图后会自动切换；旧客户端仍可继续兼容棋局。",
                    enabled: legacyEnabled
                )
            }
        }
        .onAppear {
            loadMapIfNeeded()
            refresh()
        }
        .onChange(of: messages.count) { _ in
            refresh()
        }
        .alert("兵棋 V2", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("确定", role: .cancel) { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    @ViewBuilder
    private func legacyFallback(
        title: String,
        detail: String,
        enabled: Bool
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.gold)
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            TacticalBoardView(
                state: legacyState,
                localPlayer: session.localPlayer,
                enabled: enabled,
                onMove: onLegacyMove,
                onPass: onLegacyPass
            )
            .padding(.horizontal, 10)
        }
    }

    private func loadMapIfNeeded() {
        guard map == nil else { return }
        do {
            map = try TacticalV2.ScenarioBundleV2.loadGuanduMap()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func refresh() {
        guard let map else { return }

        let records = TacticalV2.ChatMessageAdapterV2.records(
            from: messages,
            sessionID: session.id
        )

        if !sentHelloThisAppearance,
           !TacticalV2.ChatSessionBuilderV2.hasLocalHello(
                sessionID: session.id,
                hostIsLocal: session.hostIsLocal,
                records: records
           ) {
            sentHelloThisAppearance = true
            send(
                TacticalV2.WireEnvelopeV2.makeHello(
                    sessionID: session.id,
                    actor: localActor,
                    capabilities: .guandu(map: map)
                )
            )
        }

        let initial = TacticalV2.GuanduScenarioV2.initialTruthState(
            map: map,
            seed: TacticalV2.GuanduScenarioV2.deterministicSeed(
                sessionID: session.id
            )
        )

        let rebuilt = TacticalV2.ChatSessionBuilderV2.rebuild(
            sessionID: session.id,
            hostIsLocal: session.hostIsLocal,
            records: records,
            map: map,
            initialState: initial
        )
        snapshot = rebuilt

        let intel = intelMemory.project(
            truthUnits: rebuilt.state.units,
            map: map,
            viewer: localActor,
            simulationTurn: rebuilt.state.simulationTurn,
            visibilityCache: &visibilityCache,
            revision: rebuilt.state.revision
        )
        let nextRedacted = TacticalV2.RedactedTacticalViewV2(intel: intel)
        redacted = nextRedacted
        playerSupplyField = TacticalV2.OperationalFieldBuilderV2.playerVisibleSupplyField(
            map: map,
            redacted: nextRedacted,
            revision: rebuilt.state.revision.supply
        )

        resumePendingRound(rebuilt)
        acknowledgeResolvedFrame(rebuilt)
    }

    private func submit(order: TacticalV2.OrderV2) {
        guard let snapshot,
              snapshot.negotiation == .compatible,
              snapshot.divergenceTurns.isEmpty,
              order.actor == localActor,
              order.issuedTurn == snapshot.state.simulationTurn else {
            return
        }

        var generator = SystemRandomNumberGenerator()
        let nonce = UInt64.random(
            in: UInt64.min...UInt64.max,
            using: &generator
        )
        let reveal = TacticalV2.RevealV2(
            actor: localActor,
            turn: snapshot.state.simulationTurn,
            batch: TacticalV2.OrderBatchV2(orders: [order]),
            nonce: nonce
        )

        do {
            try TacticalV2.PendingRevealSecureStoreV2.save(
                reveal,
                sessionID: session.id
            )
            send(
                TacticalV2.WireEnvelopeV2.makeCommitment(
                    sessionID: session.id,
                    value: reveal.commitment()
                )
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func resumePendingRound(
        _ rebuilt: TacticalV2.ChatSessionSnapshotV2
    ) {
        guard rebuilt.negotiation == .compatible,
              rebuilt.divergenceTurns.isEmpty,
              let reveal = TacticalV2.PendingRevealSecureStoreV2.load(
                sessionID: session.id,
                turn: rebuilt.state.simulationTurn
              ) else {
            return
        }

        if !rebuilt.currentRound.localCommitted {
            send(
                TacticalV2.WireEnvelopeV2.makeCommitment(
                    sessionID: session.id,
                    value: reveal.commitment()
                )
            )
            return
        }

        if rebuilt.currentRound.remoteCommitted,
           !rebuilt.currentRound.localRevealed {
            send(
                TacticalV2.WireEnvelopeV2.makeReveal(
                    sessionID: session.id,
                    value: reveal
                )
            )
        }
    }

    private func acknowledgeResolvedFrame(
        _ rebuilt: TacticalV2.ChatSessionSnapshotV2
    ) {
        guard let frame = rebuilt.frames.last else { return }

        TacticalV2.PendingRevealSecureStoreV2.remove(
            sessionID: session.id,
            turn: frame.resolvedTurn
        )

        let nextTurn = rebuilt.state.simulationTurn
        guard frame.resolvedTurn < nextTurn else { return }

        // Duplicate digests are harmless, but do not emit one if local history already has it.
        let records = TacticalV2.ChatMessageAdapterV2.records(
            from: messages,
            sessionID: session.id
        )
        let alreadySent = records.contains { record in
            guard record.isOutgoing,
                  let envelope = TacticalV2.WireCodecV2.decode(record.body) else {
                return false
            }
            return envelope.kind == .frameDigest
                && envelope.turn == frame.resolvedTurn
                && envelope.actor == localActor
        }

        if !alreadySent {
            send(
                TacticalV2.WireEnvelopeV2.makeDigest(
                    sessionID: session.id,
                    actor: localActor,
                    value: TacticalV2.PrivacyBoundaryV2.digest(frame)
                )
            )
        }
    }

    private func send(_ envelope: TacticalV2.WireEnvelopeV2) {
        do {
            try model.sessions.sendTacticalV2Envelope(
                envelope,
                to: conversation.peerIdentityID
            )
        } catch {
            errorText = error.localizedDescription
        }
    }
}
