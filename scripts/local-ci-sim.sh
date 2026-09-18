#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pass() { printf 'PASS  %s\n' "$1"; }
info() { printf 'INFO  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; exit 1; }

command -v swiftc >/dev/null || fail "swiftc not found"
command -v python3 >/dev/null || fail "python3 not found"
command -v cc >/dev/null || fail "C compiler not found"
command -v cc >/dev/null || fail "C compiler not found"

python3 - <<'PY'
import pathlib, plistlib, yaml
root = pathlib.Path('.')
with open(root/'project.yml', 'r', encoding='utf-8') as fh:
    project = yaml.safe_load(fh)
assert project['options']['deploymentTarget']['iOS'] == '15.0'
assert project['settings']['base']['SWIFT_VERSION'] == 5.9
assert 'VeilLink' in project['targets'] and 'VeilLinkTests' in project['targets']
with open(root/'VeilLink/Resources/Info.plist', 'rb') as fh:
    plist = plistlib.load(fh)
current = (root/'docs/CHECKPOINT_CURRENT.md').read_text(encoding='utf-8')
version = plist['CFBundleShortVersionString']
assert f'V{version} ' in current
assert int(plist['CFBundleVersion']) >= 1
ci = yaml.safe_load((root/'.github/workflows/ios-ci.yml').read_text(encoding='utf-8'))
ipa = yaml.safe_load((root/'.github/workflows/unsigned-ipa.yml').read_text(encoding='utf-8'))
ci_job = ci['jobs']['build-and-test']
ipa_job = ipa['jobs']['package']
assert ci_job['runs-on'] == 'macos-15'
assert ipa_job['runs-on'] == 'macos-15'
ci_runs = '\n'.join(str(step.get('run', '')) for step in ci_job['steps'])
ipa_runs = '\n'.join(str(step.get('run', '')) for step in ipa_job['steps'])
assert 'xcodegen generate' in ci_runs and 'xcodebuild' in ci_runs and 'scripts/ci-test.sh' in ci_runs
assert '-sdk iphonesimulator' in ci_runs
assert 'xcodegen generate' in ipa_runs and '-sdk iphoneos' in ipa_runs and 'scripts/package-unsigned-ipa.sh' in ipa_runs
assert any(step.get('with', {}).get('name') == 'VeilLink-unsigned' for step in ipa_job['steps'] if isinstance(step, dict))
print('manifest-ok')
PY
pass "project.yml / Info.plist / workflow manifests"

mapfile -t SWIFT_FILES < <(find VeilLink VeilLinkTests -name '*.swift' -type f | sort)
((${#SWIFT_FILES[@]} > 0)) || fail "no Swift files"
for file in "${SWIFT_FILES[@]}"; do
    swiftc -parse "$file" >/dev/null
done
pass "swiftc -parse ${#SWIFT_FILES[@]} Swift files"

swiftc -typecheck \
    VeilLink/Core/Models.swift \
    VeilLink/Core/MessageTextFeatures.swift \
    VeilLink/Core/MiniGames.swift \
    VeilLink/Core/TacticalGame.swift \
    VeilLink/Core/RenderCompatibilityPolicy.swift \
    VeilLink/Core/PerformanceOverrides.swift \
    VeilLink/Core/DevicePerformanceProfile.swift \
    VeilLink/Core/ImageViewerPolicy.swift \
    VeilLink/Health/VeilA9Lattice.swift \
    VeilLink/Agent/Compute/A9ComputePlanner.swift \
    VeilLink/Agent/MaleCNS/MaleCNSComputeContract.swift \
    VeilLink/Agent/Vision/AgentVisualContext.swift \
    VeilLink/Agent/Core/AgentModels.swift \
    VeilLink/Agent/Core/AgentRuntime.swift \
    VeilLink/Agent/Core/AgentCapabilityProfile.swift \
    VeilLink/Agent/Core/AgentSession.swift \
    VeilLink/Agent/Core/AgentDiagnostics.swift \
    VeilLink/Agent/Language/LocalTextModelManifest.swift \
    VeilLink/Agent/Language/LocalTextModelRuntime.swift \
    VeilLink/Agent/Language/AgentPromptAssembler.swift \
    VeilLink/Agent/Language/AgentTokenStream.swift \
    VeilLink/Agent/Language/MockLocalTextModelRuntime.swift \
    VeilLink/Agent/Language/LocalTextModelCoordinator.swift \
    VeilLink/Agent/Games/AgentGameAdapter.swift \
    VeilLink/Agent/Games/GomokuAgentAdapter.swift \
    VeilLink/Agent/Games/XiangqiAgentAdapter.swift \
    VeilLink/Agent/Games/LudoAgentAdapter.swift \
    VeilLink/Agent/Games/AgentGameRegistry.swift \
    VeilLink/Agent/Games/TrainedGamePolicyRuntime.swift \
    VeilLink/Transport/ConnectionEventGate.swift \
    VeilLink/Transport/BLEConnectionIntentStore.swift \
    VeilLink/Transport/BLELinkReliabilityPolicy.swift \
    VeilLink/Transport/BLELinkSnapshot.swift \
    VeilLink/Security/PacketAbuseLimiter.swift \
    VeilLink/Transport/BLEFramer.swift
pass "Linux-compatible core typecheck"

HARNESS_DIR="$(mktemp -d)"
trap 'rm -rf "$HARNESS_DIR"' EXIT
cat > "$HARNESS_DIR/main.swift" <<'SWIFT'
import Foundation

precondition(SidebarSection.allCases == [.chats, .nearby, .agent, .settings])
precondition(SidebarSection.agent.rawValue == "灵核")
let legacyAgent = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
let highAgent = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
precondition(legacyAgent.tier == .legacyA10 && legacyAgent.unloadOnBackground)
precondition(highAgent.tier == .high && highAgent.maxNewTokens > legacyAgent.maxNewTokens)
var ephemeralAgentSession = AgentSession(id: "ci")
ephemeralAgentSession.append(AgentMessage(id: "a", role: .user, text: "hello"), limit: 2)
ephemeralAgentSession.append(AgentMessage(id: "b", role: .assistant, text: "world"), limit: 2)
ephemeralAgentSession.append(AgentMessage(id: "c", role: .user, text: "again"), limit: 2)
precondition(ephemeralAgentSession.messages.map(\.id) == ["b", "c"])
precondition(!AgentTokenStream.chunks(text: "VeilLink灵核", targetCharacters: 3).isEmpty)
precondition(AgentGameRegistry.trainingEnabledKinds == [.gomoku, .xiangqi, .ludo])
precondition(!AgentGameRegistry.isTrainingEnabled(.tactical))
let a9Green = VeilA9Packet(light: .green, p0: 0, p1: 0, p2: 0, p3: 0, riskBP: 0, persistenceRuns: 0, blocker: false, healthBP: 1_000, issues: [])
precondition(VeilA9Lattice.cells.count == 144)
precondition(VeilA9Lattice.decide(a9Green).level == .l0Observe)
let a9P0 = VeilA9Packet(light: .red, p0: 1, p1: 0, p2: 0, p3: 0, riskBP: 4_000, persistenceRuns: 0, blocker: false, healthBP: 500, issues: [])
precondition(VeilA9Lattice.decide(a9P0).level == .l5Emergency)
let a9Pressure = VeilA9Input(
    bluetoothRunning: true, connectedPeerCount: 1, trackedPeerCount: 1,
    recoveringPeerCount: 1, weakPeerCount: 1, marginalPeerCount: 0,
    minimumLinkHealth: 20, maximumReconnectAttempt: 6, pendingBytes: 3 * 1_024 * 1_024,
    controlPendingPackets: 80, maximumStallMilliseconds: 25_000,
    agentUnavailable: false, agentCooling: false, agentHasFailure: false,
    thermalLevel: .serious, lowPowerMode: true, databaseIntegrity: .ok
)
let a9PressurePacket = VeilA9Classifier.makePacket(input: a9Pressure, persistenceRuns: 3)
precondition(a9PressurePacket.light == .red && a9PressurePacket.blocker)
let highComputeProfile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
let flyComputePlan = VeilA9ComputePlanner.plan(
    decision: .initial,
    profile: highComputeProfile,
    focus: .maleCNSSandbox,
    logicalProcessorCount: 6
)
precondition(flyComputePlan.maleCNS.tier == .core)
precondition(flyComputePlan.maleCNS.workerCount >= 2)
let backlogDecision = VeilA9Decision(
    light: .yellow, level: .l2Review, reasonCode: "TEST", healthScore: 80,
    riskPoints: 12, persistenceRuns: 3,
    issues: [VeilA9Issue(code: "CONTROL_BACKLOG_HIGH", severity: .p1, source: "ble", detail: "test")],
    latticeIndex: 42
)
let backlogPlan = VeilA9ComputePlanner.plan(
    decision: backlogDecision,
    profile: highComputeProfile,
    focus: .videoChat,
    logicalProcessorCount: 6
)
precondition(backlogPlan.transportReserveUnits > 0)
precondition(backlogPlan.mode == .constrained)
let visualContext = AgentVisualContext(capturedAt: Date(timeIntervalSince1970: 1), faceCount: 1, labels: ["person"], recognizedText: ["VeilLink"], frameWidth: 640, frameHeight: 480)
precondition(visualContext.compactPromptDescription.contains("VeilLink"))
let gomokuAgent = GomokuAgentAdapter(state: GomokuState(), actor: .host)
precondition(gomokuAgent.enumerateLegalActions().count == 225)
precondition(gomokuAgent.makeObservation().features.count == 228)
let xiangqiAgent = XiangqiAgentAdapter(state: XiangqiState(), actor: .host)
precondition(!xiangqiAgent.enumerateLegalActions().isEmpty)
let ciLudoSession = "00000000-0000-0000-0000-000000000001"
let ludoAgent = LudoAgentAdapter(state: LudoState(), actor: .host, sessionID: ciLudoSession)
precondition(!ludoAgent.enumerateLegalActions().isEmpty)

let reply = ReplyTextCodec.encode(quoted: "old message", reply: "new message")
precondition(ReplyTextCodec.decode(reply)?.reply == "new message")
precondition(ReplyTextCodec.previewText(for: reply) == "↪︎ new message")
let gameInvite = MiniGamePacket(game: .gomoku, command: .invite)
let encodedGameInvite = try MiniGameCodec.encode(gameInvite)
precondition(MiniGameCodec.decode(encodedGameInvite) == gameInvite)
var gomoku = GomokuState()
for column in 0..<4 {
    precondition(gomoku.apply(index: column, actor: .host))
    precondition(gomoku.apply(index: GomokuState.size + column, actor: .guest))
}
precondition(gomoku.apply(index: 4, actor: .host) && gomoku.winner == .host)
precondition(gomoku.winningLine == [0, 1, 2, 3, 4] && !gomoku.isDraw)
var xiangqi = XiangqiState()
precondition(xiangqi.apply(from: 6 * XiangqiState.columns, to: 5 * XiangqiState.columns, actor: .host))
var repeatingXiangqi = XiangqiState()
let redHorseHome = 9 * XiangqiState.columns + 1
let redHorseOut = 7 * XiangqiState.columns + 2
let blackHorseHome = 1
let blackHorseOut = 2 * XiangqiState.columns + 2
for _ in 0..<2 {
    precondition(repeatingXiangqi.apply(from: redHorseHome, to: redHorseOut, actor: .host))
    precondition(repeatingXiangqi.apply(from: blackHorseHome, to: blackHorseOut, actor: .guest))
    precondition(repeatingXiangqi.apply(from: redHorseOut, to: redHorseHome, actor: .host))
    precondition(repeatingXiangqi.apply(from: blackHorseOut, to: blackHorseHome, actor: .guest))
}
precondition(repeatingXiangqi.isDraw && repeatingXiangqi.drawReason == .threefoldRepetition)
precondition(repeatingXiangqi.currentPositionRepetitionCount == 3)
let ludoSession = UUID().uuidString
var ludo = LudoState()
let legalLudo = ludo.legalPieces(sessionID: ludoSession)
precondition(ludo.apply(pieceIndex: legalLudo.first ?? -1, actor: .host, sessionID: ludoSession))
precondition(ludo.finishedCount(for: .host) == 0 && ludo.finishedCount(for: .guest) == 0)

let tacticalSession = UUID().uuidString
var tactical = TacticalState()
precondition(TacticalState.hexes.count == TacticalState.rows * TacticalState.columns)
precondition(tactical.currentPlayer == .host && tactical.ordersRemaining == TacticalState.ordersPerActivation)
precondition(tactical.legalDestinations(from: 55, actor: .host).contains(46))
precondition(tactical.isSupplied(unitID: "cao-command"))
precondition(tactical.supplyPath(unitID: "cao-infantry-l")?.last == 45)
precondition(tactical.supplyNetwork(for: .cao).contains(55))
precondition(tactical.threatenedHexes(by: .cao).contains(46))
precondition(tactical.commandZone(for: .cao).contains(46))
let tacticalSituation = tactical.situationSnapshot()
precondition(tacticalSituation.activeUnitsByPosition.count == 12)
precondition(tacticalSituation.supplyNetwork(for: .cao) == tactical.supplyNetwork(for: .cao))
precondition(tacticalSituation.threatenedHexes(by: .yuan) == tactical.threatenedHexes(by: .yuan))
precondition(tacticalSituation.isSupplied(tactical.unit(id: "cao-command")!))
let previewAttacker = TacticalUnit(id: "preview-a", faction: .cao, kind: .infantry, name: "A", position: 30, steps: 2)
let previewDefender = TacticalUnit(id: "preview-d", faction: .yuan, kind: .infantry, name: "D", position: 31, steps: 2)
let previewState = TacticalState(units: [previewAttacker, previewDefender])
let forecast = previewState.combatForecast(attackerID: "preview-a", defenderID: "preview-d")
precondition(forecast != nil)
precondition((forecast?.defenderLossChancePercent ?? 0) + (forecast?.attackerLossChancePercent ?? 0) + (forecast?.stalemateChancePercent ?? 0) >= 99)
precondition(previewState.turn == 0 && previewState.lastCombat == nil)
precondition(tactical.apply(from: 55, to: 46, actor: .host, sessionID: tacticalSession))
precondition(tactical.turn == 1 && tactical.currentPlayer == .host && tactical.ordersRemaining == 1)
precondition(tactical.apply(from: nil, to: nil, actor: .host, sessionID: tacticalSession))
precondition(tactical.turn == 2 && tactical.currentPlayer == .guest && tactical.ordersRemaining == TacticalState.ordersPerActivation)

let conversationID = UUID().uuidString
let invite = MiniGamePacket(game: .gomoku, command: .invite, createdAt: Date(timeIntervalSince1970: 10))
let premature = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 112), createdAt: Date(timeIntervalSince1970: 11))
let accept = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .accept, createdAt: Date(timeIntervalSince1970: 12))
let rebuildMessages = [
    ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: Date(timeIntervalSince1970: 10), isOutgoing: true, deliveryState: .delivered),
    ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(premature), sentAt: Date(timeIntervalSince1970: 11), isOutgoing: true, deliveryState: .delivered),
    ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(accept), sentAt: Date(timeIntervalSince1970: 12), isOutgoing: false, deliveryState: .delivered)
]
let rebuiltGame = MiniGameSessionBuilder.session(id: invite.sessionID, from: rebuildMessages)
precondition(rebuiltGame?.status == .active && rebuiltGame?.moveCount == 0 && rebuiltGame?.gomoku?.value(at: 112) == 0)
let legalMove = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 112), createdAt: Date(timeIntervalSince1970: 13))
let replayMessages = rebuildMessages + [
    ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(legalMove), sentAt: Date(timeIntervalSince1970: 13), isOutgoing: true, deliveryState: .delivered)
]
let replayFrames = MiniGameSessionBuilder.replay(sessionID: invite.sessionID, from: replayMessages)
precondition(replayFrames.last?.snapshot.moveCount == 1)
precondition(replayFrames.last?.snapshot.gomoku?.value(at: 112) == 1)
precondition(replayFrames.map(\.label).contains("第 1 手"))
let duplicateLateMove = ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(legalMove), sentAt: Date(timeIntervalSince1970: 999), isOutgoing: true, deliveryState: .delivered)
let duplicateRebuild = MiniGameSessionBuilder.session(id: invite.sessionID, from: replayMessages + [duplicateLateMove])
precondition(duplicateRebuild?.moveCount == 1)
precondition(duplicateRebuild?.lastActivity == Date(timeIntervalSince1970: 13))
let syntheticWin = MiniGameSessionSnapshot(id: "win", game: .gomoku, hostIsLocal: true, status: .finished(winner: .host), invitedAt: Date(timeIntervalSince1970: 1), startedAt: Date(timeIntervalSince1970: 2), lastActivity: Date(timeIntervalSince1970: 8), gomoku: GomokuState(), xiangqi: nil, ludo: nil, endedByResignation: false)
let syntheticLoss = MiniGameSessionSnapshot(id: "loss", game: .xiangqi, hostIsLocal: true, status: .finished(winner: .guest), invitedAt: Date(timeIntervalSince1970: 1), startedAt: Date(timeIntervalSince1970: 2), lastActivity: Date(timeIntervalSince1970: 7), gomoku: nil, xiangqi: XiangqiState(), ludo: nil, endedByResignation: false)
let summary = MiniGameStatistics(sessions: [syntheticWin, syntheticLoss])
precondition(summary.completed == 2 && summary.wins == 1 && summary.losses == 1 && summary.draws == 0)
precondition(syntheticWin.duration == 6)

let pendingInvite = MiniGamePacket(game: .xiangqi, command: .invite, createdAt: Date(timeIntervalSince1970: 20))
let cancelInvite = MiniGamePacket(sessionID: pendingInvite.sessionID, game: .xiangqi, command: .resign, turn: 0, createdAt: Date(timeIntervalSince1970: 21))
let cancelMessages = [
    ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(pendingInvite), sentAt: Date(timeIntervalSince1970: 20), isOutgoing: true, deliveryState: .delivered),
    ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(cancelInvite), sentAt: Date(timeIntervalSince1970: 21), isOutgoing: true, deliveryState: .delivered)
]
precondition(MiniGameSessionBuilder.session(id: pendingInvite.sessionID, from: cancelMessages)?.status == .cancelled)
precondition(RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone8,4", osMajorVersion: 15))
precondition(RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone9,1", osMajorVersion: 15))
precondition(!RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone9,1", osMajorVersion: 16))
precondition(!RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone14,2", osMajorVersion: 15))
precondition(RenderCompatibilityPolicy.shouldUseStableScrollLayout(osMajorVersion: 15))
precondition(!RenderCompatibilityPolicy.shouldUseStableScrollLayout(osMajorVersion: 16))
let se1Profile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone8,4", osMajorVersion: 15)
precondition(se1Profile.label == "SE1-LOW" && se1Profile.messageWindowInitial == 48)
let iPhone7Profile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone9,1", osMajorVersion: 15)
precondition(iPhone7Profile.label == "LEGACY-COMPACT")
let se2Profile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone12,8", osMajorVersion: 15)
precondition(se2Profile.label == "SE2-BALANCED")
let proProfile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone14,2", osMajorVersion: 18)
precondition(proProfile.label == "13PRO-HIGH")
precondition(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone8,4", previewMaxPixelSize: 640, highDefinitionOverride: false) == 1_536)
precondition(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone9,1", previewMaxPixelSize: 768, highDefinitionOverride: false) == 2_048)
precondition(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone12,8", previewMaxPixelSize: 1_024, highDefinitionOverride: false) == 2_560)
precondition(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone14,2", previewMaxPixelSize: 1_280, highDefinitionOverride: false) == 3_072)
precondition(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone8,4", previewMaxPixelSize: 2_048, highDefinitionOverride: true) == 4_096)
let godSnapshot = PerformanceOverrideSnapshot(
    isEnabled: true,
    highDefinitionPreview: true,
    expandedAttachmentCache: true,
    disableRefreshCoalescing: true,
    forceFullVisualEffects: true,
    allowPersistentAnimations: true
)
let godProfile = PerformanceOverridePolicy.effectiveProfile(base: iPhone7Profile, snapshot: godSnapshot)
precondition(godProfile.imagePreviewMaxPixelSize == 2_048)
precondition(godProfile.outboundAttachmentCacheBytes == 16 * 1_024 * 1_024)
precondition(godProfile.messageRefreshDebounceNanoseconds == 0)
precondition(godProfile.transferVisualComplexity == .full)
precondition(godProfile.bleQueueByteLimit == iPhone7Profile.bleQueueByteLimit)
let weakLegacyLink = BLELinkReliabilityPolicy.tuning(rssi: -88, machineIdentifier: "iPhone9,1")
let weakModernLink = BLELinkReliabilityPolicy.tuning(rssi: -88, machineIdentifier: "iPhone14,2")
precondition(weakLegacyLink.quality == .weak)
precondition(weakLegacyLink.packetBurstLimit <= weakModernLink.packetBurstLimit)
let queueBudget = BLELinkReliabilityPolicy.queueBudget(packetLimit: 8_192, byteLimit: 640_000)
precondition(BLELinkReliabilityPolicy.canEnqueue(priority: .bulk, pendingPackets: 0, pendingBytes: 0, additionalPackets: 8_192, additionalBytes: 640_000, packetLimit: 8_192, byteLimit: 640_000))
precondition(BLELinkReliabilityPolicy.canEnqueue(priority: .control, pendingPackets: 8_192, pendingBytes: 640_000, additionalPackets: min(32, queueBudget.controlOverflowPackets), additionalBytes: min(8_192, queueBudget.controlOverflowBytes), packetLimit: 8_192, byteLimit: 640_000))
precondition(!BLELinkReliabilityPolicy.canEnqueue(priority: .bulk, pendingPackets: 8_192, pendingBytes: 640_000, additionalPackets: 1, additionalBytes: 1, packetLimit: 8_192, byteLimit: 640_000))
precondition(BLELinkReliabilityPolicy.stallTimeout(quality: .good, hasControlTraffic: true) < BLELinkReliabilityPolicy.stallTimeout(quality: .good, hasControlTraffic: false))
precondition(BLELinkReliabilityPolicy.reconnectDelay(attempt: 100) == 30)
precondition(BLELinkReliabilityPolicy.smoothedRSSI(previous: -70, sample: 127) == -70)

var gate = ConnectionEventGate()
let transport = UUID()
precondition(gate.markConnected(transport))
precondition(!gate.markConnected(transport))
precondition(gate.markDisconnected(transport))
precondition(!gate.markDisconnected(transport))

var limiter = PacketAbuseLimiter(windowDuration: 10, maximumPacketsPerWindow: 3)
precondition(!limiter.recordInvalidPacket(for: transport).shouldDisconnect)
precondition(!limiter.recordInvalidPacket(for: transport).shouldDisconnect)
precondition(limiter.recordInvalidPacket(for: transport).shouldDisconnect)
limiter.reset(transport)
precondition(limiter.recordInvalidPacket(for: transport).count == 1)

let payload = Data(repeating: 0x5A, count: 257)
var directPackets = [Data([0xAA])]
let directPlan = BLEFragment.appendEncodedPackets(payload, maximumPacketSize: 31, to: &directPackets)
precondition(directPackets.first == Data([0xAA]))
precondition(directPackets.count - 1 == directPlan?.fragmentCount)
precondition(directPackets.dropFirst().reduce(0) { $0 + $1.count } == directPlan?.encodedByteCount)
let fragments = BLEFragment.split(payload, maximumPacketSize: 31)
precondition(!fragments.isEmpty)
let assembler = BLEFragmentAssembler(maxAssembledBytes: 1024, maxPacketBytes: 31, maxTotalBufferedBytes: 2048)
var rebuilt: Data?
for fragment in fragments.reversed() {
    rebuilt = assembler.ingest(source: transport, packet: fragment.encoded) ?? rebuilt
}
precondition(rebuilt == payload)
let healthyLink = BLEPeerLinkSnapshot(
    id: UUID(), isConnected: true, isWanted: true, reconnectAttempt: 0,
    rssi: -58, quality: .strong, pendingPackets: 0, pendingBytes: 0,
    controlPendingPackets: 0, maximumPacketSize: 185, role: .central, stalledFor: nil
)
let recoveringLink = BLEPeerLinkSnapshot(
    id: UUID(), isConnected: false, isWanted: true, reconnectAttempt: 3,
    rssi: -90, quality: .weak, pendingPackets: 20, pendingBytes: 64 * 1_024,
    controlPendingPackets: 2, maximumPacketSize: 20, role: .unavailable, stalledFor: 8
)
precondition(healthyLink.healthScore > recoveringLink.healthScore)
precondition(recoveringLink.statusTitle == "自动重连中")
let linkReport = BLELinkDiagnosticsFormatter.report(
    generatedAt: Date(timeIntervalSince1970: 0), isRunning: true, statusText: "ready",
    connectedPeerCount: 1, snapshots: [healthyLink]
)
precondition(linkReport.contains("Privacy:"))
print("core-harness-ok")
SWIFT
swiftc \
    VeilLink/Core/Models.swift \
    VeilLink/Core/MessageTextFeatures.swift \
    VeilLink/Core/MiniGames.swift \
    VeilLink/Core/TacticalGame.swift \
    VeilLink/Core/RenderCompatibilityPolicy.swift \
    VeilLink/Core/PerformanceOverrides.swift \
    VeilLink/Core/DevicePerformanceProfile.swift \
    VeilLink/Core/ImageViewerPolicy.swift \
    VeilLink/Health/VeilA9Lattice.swift \
    VeilLink/Agent/Compute/A9ComputePlanner.swift \
    VeilLink/Agent/MaleCNS/MaleCNSComputeContract.swift \
    VeilLink/Agent/Vision/AgentVisualContext.swift \
    VeilLink/Agent/Core/AgentModels.swift \
    VeilLink/Agent/Core/AgentRuntime.swift \
    VeilLink/Agent/Core/AgentCapabilityProfile.swift \
    VeilLink/Agent/Core/AgentSession.swift \
    VeilLink/Agent/Core/AgentDiagnostics.swift \
    VeilLink/Agent/Language/LocalTextModelManifest.swift \
    VeilLink/Agent/Language/LocalTextModelRuntime.swift \
    VeilLink/Agent/Language/AgentPromptAssembler.swift \
    VeilLink/Agent/Language/AgentTokenStream.swift \
    VeilLink/Agent/Language/MockLocalTextModelRuntime.swift \
    VeilLink/Agent/Language/LocalTextModelCoordinator.swift \
    VeilLink/Agent/Games/AgentGameAdapter.swift \
    VeilLink/Agent/Games/GomokuAgentAdapter.swift \
    VeilLink/Agent/Games/XiangqiAgentAdapter.swift \
    VeilLink/Agent/Games/LudoAgentAdapter.swift \
    VeilLink/Agent/Games/AgentGameRegistry.swift \
    VeilLink/Transport/ConnectionEventGate.swift \
    VeilLink/Transport/BLELinkReliabilityPolicy.swift \
    VeilLink/Transport/BLELinkSnapshot.swift \
    VeilLink/Security/PacketAbuseLimiter.swift \
    VeilLink/Transport/BLEFramer.swift \
    "$HARNESS_DIR/main.swift" -o "$HARNESS_DIR/core-harness"
"$HARNESS_DIR/core-harness" >/dev/null
pass "core executable behavior harness"

cat > "$HARNESS_DIR/NativeBudgetStub.swift" <<'SWIFT'
import Foundation

enum MaleCNSComputeTier: String, Codable, CaseIterable, Sendable { case suspended, lite, core, reference }
struct MaleCNSComputeBudget: Equatable, Sendable {
    let tier: MaleCNSComputeTier
    let workerCount: Int
    let neuralStepBudget: Int
    let episodeMilliseconds: Int
    let rolloutCount: Int
    let stateSampleStride: Int
    static let suspended = MaleCNSComputeBudget(tier: .suspended, workerCount: 0, neuralStepBudget: 0, episodeMilliseconds: 0, rolloutCount: 0, stateSampleStride: 8)
}
protocol MaleCNSComputeConsumer: AnyObject {
    func applyComputeBudget(_ budget: MaleCNSComputeBudget)
    func trimComputeState()
}
SWIFT
cat > "$HARNESS_DIR/native-main.swift" <<'SWIFT'
import Foundation

@main
struct NativeKernelHarness {
    static func main() throws {
        let graph = try MaleCNSNativeGraph(
            neuronCount: 3,
            offsets: [0, 1, 2, 2],
            targets: [1, 2],
            weights: [1, 1]
        )
        let runtime = MaleCNSNativeKernelRuntime(graph: graph)
        runtime.applyComputeBudget(MaleCNSComputeBudget(
            tier: .lite, workerCount: 1, neuralStepBudget: 3,
            episodeMilliseconds: 100, rolloutCount: 1, stateSampleStride: 1
        ))
        try runtime.setExternalDrive([1.1, 0, 0])
        let firstStepCount = try runtime.stepInPlace(decay: 0, gain: 1, tonic: 0)
        precondition(firstStepCount == 1)
        precondition(runtime.firedSnapshot() == [0])
        runtime.clearExternalDrive()
        let episode = try runtime.runEpisode(requestedSteps: 99, decay: 0, gain: 1, tonic: 0)
        precondition(episode.executedSteps == 3)
        precondition(episode.totalSpikeCount == 2)
        precondition(runtime.spikeCountSnapshot() == [0, 1, 1])
        let readoutMap = try MaleCNSNativeReadoutMap(groups: [
            MaleCNSNativeReadoutGroup(name: "motor", neuronIndices: [1, 2]),
            MaleCNSNativeReadoutGroup(name: "terminal", neuronIndices: [2]),
            MaleCNSNativeReadoutGroup(name: "overlap", neuronIndices: [1, 2, 2])
        ], neuronCount: 3)
        let readout = try runtime.readoutSnapshot(using: readoutMap)
        precondition(readout.spikeCounts == [2, 1, 3])
        precondition(runtime.hasPerNeuronSpikeCounts)

        let compact = MaleCNSNativeKernelRuntime(graph: graph)
        precondition(!compact.hasPerNeuronSpikeCounts)
        compact.applyComputeBudget(MaleCNSComputeBudget(
            tier: .lite, workerCount: 1, neuralStepBudget: 3,
            episodeMilliseconds: 100, rolloutCount: 1, stateSampleStride: 1
        ))
        try compact.setExternalDrive([1.1, 0, 0])
        let compactFirstStep = try compact.stepInPlace(decay: 0, gain: 1, tonic: 0)
        precondition(compactFirstStep == 1)
        compact.clearExternalDrive()
        let compactEpisode = try compact.runEpisodeWithReadouts(
            using: readoutMap, requestedSteps: 3, decay: 0, gain: 1, tonic: 0
        )
        precondition(compactEpisode.summary == episode)
        precondition(compactEpisode.readout.spikeCounts == readout.spikeCounts)
        precondition(!compact.hasPerNeuronSpikeCounts)
        runtime.trimComputeState()
        precondition(!runtime.hasPerNeuronSpikeCounts)

        let pool = MaleCNSNativeRolloutPool(graph: graph, readoutMap: readoutMap)
        pool.applyComputeBudget(MaleCNSComputeBudget(
            tier: .core, workerCount: 2, neuralStepBudget: 3,
            episodeMilliseconds: 100, rolloutCount: 2, stateSampleStride: 1
        ))
        let requests = (0..<3).map { index in
            MaleCNSNativeRolloutRequest(
                id: index, externalDrive: [1.1, 0, 0], requestedSteps: 3,
                decay: 0, gain: 1, tonic: 0
            )
        }
        let pooled = try pool.run(requests)
        precondition(pooled.map(\.id) == [0, 1])
        precondition(pooled.allSatisfy { $0.episode.readout.spikeCounts == [3, 1, 4] })
        precondition(pooled.allSatisfy { $0.episode.summary.totalSpikeCount == 6 })
        precondition(pool.residentWorkerCount == 2)
        pool.applyComputeBudget(.suspended)
        precondition(pool.residentWorkerCount == 0)
        let suspendedResults = try pool.run(requests)
        precondition(suspendedResults.isEmpty)
        print("vlfly-native-wrapper-ok")
    }
}
SWIFT
cc -std=c11 -O2 -Wall -Wextra -Werror -c VeilLink/Native/VeilFlyKernel.c -o "$HARNESS_DIR/VeilFlyKernel.o"
swiftc -swift-version 5 -O \
    -import-objc-header VeilLink/Native/VeilLink-Bridging-Header.h \
    "$HARNESS_DIR/NativeBudgetStub.swift" \
    VeilLink/Agent/MaleCNS/MaleCNSNativeKernel.swift \
    VeilLink/Agent/MaleCNS/MaleCNSNativeRolloutPool.swift \
    "$HARNESS_DIR/native-main.swift" \
    "$HARNESS_DIR/VeilFlyKernel.o" \
    -o "$HARNESS_DIR/native-kernel-harness"
"$HARNESS_DIR/native-kernel-harness" >/dev/null
swiftc -swift-version 5 -strict-concurrency=complete -typecheck \
    -import-objc-header VeilLink/Native/VeilLink-Bridging-Header.h \
    "$HARNESS_DIR/NativeBudgetStub.swift" \
    VeilLink/Agent/MaleCNS/MaleCNSNativeKernel.swift \
    VeilLink/Agent/MaleCNS/MaleCNSNativeRolloutPool.swift
pass "VeilFly native C kernel + compact readout + deterministic rollout pool"

python3 - <<'PYVFLY'
from pathlib import Path
import hashlib, json, struct
p=Path('VeilLinkTests/Fixtures/MaleCNSFixture.vfly')
raw=p.read_bytes()
fmt=struct.Struct('<8sIIIIIIIIQQQQQQQQ32s')
assert fmt.size == 136 and len(raw) >= fmt.size
h=fmt.unpack_from(raw)
assert h[0] == b'VFLY1\0\0\0' and h[1] == 1 and h[2] == 136 and h[3] == 0x01020304
assert h[5] == 12 and h[6] == 13
payload=raw[136:]
assert len(payload) == h[16]
assert hashlib.sha256(payload).digest() == h[17]
md_off, md_len = h[14], h[15]
meta=json.loads(raw[md_off:md_off+md_len])
assert meta['dataset_id'] == 'male-cns:v1.0'
assert meta['group_names'][0].startswith('sensory.')
print('vfly1-fixture-hash-ok')
PYVFLY

cat > "$HARNESS_DIR/VFLYLoaderHarness.swift" <<'SWIFT'
import Foundation
@main
struct VFLYLoaderHarness {
    static func main() throws {
        let url = URL(fileURLWithPath: "VeilLinkTests/Fixtures/MaleCNSFixture.vfly")
        let artifact = try VFLY1Loader.load(url: url, verifyPayloadHash: false)
        precondition(artifact.graph.neuronCount == 12)
        precondition(artifact.metadata.datasetID == "male-cns:v1.0")
        precondition(artifact.group(named: "sensory.LC4.L")?.neuronIndices == [0])
        let runtime = try MaleCNSGraphRuntime(artifact: artifact, preferredReadouts: ["readout.escape_L"])
        runtime.applyComputeBudget(MaleCNSComputeBudget(
            tier: .lite, workerCount: 1, neuralStepBudget: 8,
            episodeMilliseconds: 100, rolloutCount: 1, stateSampleStride: 1
        ))
        let result = try runtime.run(stimulus: .looming(side: .left, strength: 1.1), requestedSteps: 8)
        precondition(result.summary.executedSteps == 8)
        precondition(result.readout.spikeCounts.first ?? 0 > 0)
        print("vfly1-native-runtime-ok")
    }
}
SWIFT
swiftc -swift-version 5 -Onone -parse-as-library \
    -import-objc-header VeilLink/Native/VeilLink-Bridging-Header.h \
    "$HARNESS_DIR/NativeBudgetStub.swift" \
    VeilLink/Agent/MaleCNS/MaleCNSNativeKernel.swift \
    VeilLink/Agent/MaleCNS/VFLY1Format.swift \
    VeilLink/Agent/MaleCNS/VFLY1Loader.swift \
    VeilLink/Agent/MaleCNS/MaleCNSStimulusEncoder.swift \
    VeilLink/Agent/MaleCNS/MaleCNSGraphRuntime.swift \
    "$HARNESS_DIR/VFLYLoaderHarness.swift" \
    "$HARNESS_DIR/VeilFlyKernel.o" \
    -o "$HARNESS_DIR/vfly-loader-harness"
"$HARNESS_DIR/vfly-loader-harness" >/dev/null
pass "VFLY1 payload/hash fixture -> Swift loader -> native runtime"

cat > "$HARNESS_DIR/Combine.swift" <<'SWIFT'
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
SWIFT
swiftc -emit-module -module-name Combine "$HARNESS_DIR/Combine.swift" -emit-module-path "$HARNESS_DIR/Combine.swiftmodule"


swiftc -typecheck -swift-version 5 -strict-concurrency=complete -I "$HARNESS_DIR" \
    -import-objc-header VeilLink/Native/VeilLink-Bridging-Header.h \
    VeilLink/Core/PerformanceOverrides.swift \
    VeilLink/Core/DevicePerformanceProfile.swift \
    VeilLink/Health/VeilA9Lattice.swift \
    VeilLink/Agent/Core/AgentCapabilityProfile.swift \
    VeilLink/Agent/Compute/A9ComputePlanner.swift \
    VeilLink/Agent/Compute/A9ComputeGovernor.swift \
    VeilLink/Agent/MaleCNS/MaleCNSComputeContract.swift \
    VeilLink/Agent/MaleCNS/MaleCNSNativeKernel.swift \
    VeilLink/Agent/MaleCNS/VFLY1Format.swift \
    VeilLink/Agent/MaleCNS/VFLY1Loader.swift \
    VeilLink/Agent/MaleCNS/MaleCNSStimulusEncoder.swift \
    VeilLink/Agent/MaleCNS/MaleCNSGraphRuntime.swift \
    VeilLink/Agent/MaleCNS/MaleCNSGraphManager.swift
pass "VFLY1 graph manager tier/threading strict-concurrency typecheck"

python3 -m py_compile \
    Tools/VeilFlyBuilder/vfly_format.py \
    Tools/VeilFlyBuilder/fetch_malecns.py \
    Tools/VeilFlyBuilder/build_graph.py \
    Tools/VeilFlyBuilder/export_vfly.py \
    Tools/VeilFlyBuilder/build_subgraph.py \
    Tools/VeilFlyBuilder/verify_vfly.py \
    Tools/VeilFlyBuilder/provenance.py
python3 - <<'PYVFLYCONTRACT'
import json, pathlib
root = pathlib.Path('.')
lock = json.loads((root/'Tools/VeilFlyBuilder/manifests/malecns_source_lock.json').read_text())
assert lock['schema'] == 'VeilFlySourceLock/1'
assert lock['dataset_id'] == 'male-cns:v1.0'
assert lock['dataset_license'] == 'CC BY 4.0'
assert lock['primary_reference'] == 'https://github.com/alextitonis/fly.ai'
assert lock['primary_reference_revision'] == '1dc982f62da58a29f920fdd4d645fcab4da23624'
assert lock['reference_neurons'] == 166700
assert lock['reference_edges'] == 25582938
assert lock['prebuilt']['brain.npz'] == 'cc9bd1ecd00bd703a6fa648bc6ad145c93c7c1ee53debdcc9ce0d1f4305e6aca'
assert lock['prebuilt']['weights.npz'] == 'c29919aa44069a271b1ee978abe05fa9bf6e45e4ba3e436e92b624ef1b5be40c'
workflow=(root/'.github/workflows/malecns-heavy-validation.yml').read_text()
for required in ['workflow_dispatch:', 'fetch_malecns.py', 'export_vfly.py', 'build_subgraph.py', 'verify_vfly.py', 'package-real-brain-ipa', 'inject-vfly-assets.sh', 'VeilLink-unsigned-MaleCNS-v1.0']:
    assert required in workflow, required
inject=(root/'scripts/inject-vfly-assets.sh').read_text()
for required in ['VeilFlyCore.vfly', 'VeilFlyLite.vfly', 'male-cns:v1.0', 'payload sha256 mismatch']:
    assert required in inject, required
assert 'MaleCNSReference.vfly' in inject
manager=(root/'VeilLink/Agent/MaleCNS/MaleCNSGraphManager.swift').read_text()
runtime=(root/'VeilLink/Agent/MaleCNS/MaleCNSGraphRuntime.swift').read_text()
assert 'allowedGraphTiers' in manager and '.reference' not in manager.split('allowedGraphTiers',1)[1].split('}',1)[0]
assert 'Task.detached(priority: .userInitiated)' in manager and 'async throws' in manager
assert 'executionLock' in runtime and 'desiredBudget' in runtime and 'trimRequested' in runtime
export=(root/'Tools/VeilFlyBuilder/export_vfly.py').read_text()
assert '--allow-unpinned' in export
assert '166_700' in export and '25_582_938' in export
subgraph=(root/'Tools/VeilFlyBuilder/build_subgraph.py').read_text()
assert 'forward' in subgraph.lower() and 'reverse' in subgraph.lower()
print('vfly-builder-source-lock-ok')
PYVFLYCONTRACT
pass "VFLY1 builder / MaleCNS source lock / heavy-validation workflow contract"

cat > "$HARNESS_DIR/Combine.swift" <<'SWIFT'
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
SWIFT
swiftc -emit-module -module-name Combine "$HARNESS_DIR/Combine.swift" -emit-module-path "$HARNESS_DIR/Combine.swiftmodule"
swiftc -typecheck -I "$HARNESS_DIR" \
    VeilLink/Core/PerformanceOverrides.swift \
    VeilLink/Core/DevicePerformanceProfile.swift \
    VeilLink/Core/PerformanceOverrideController.swift
pass "performance override controller API-shape typecheck (Linux Combine stub)"

swiftc -typecheck -swift-version 5 -strict-concurrency=complete -I "$HARNESS_DIR" \
    VeilLink/Core/PerformanceOverrides.swift \
    VeilLink/Core/DevicePerformanceProfile.swift \
    VeilLink/Health/VeilA9Lattice.swift \
    VeilLink/Agent/Compute/A9ComputePlanner.swift \
    VeilLink/Agent/Compute/A9ComputeGovernor.swift \
    VeilLink/Agent/MaleCNS/MaleCNSComputeContract.swift \
    VeilLink/Agent/Vision/AgentVisualContext.swift \
    VeilLink/Agent/Core/AgentModels.swift \
    VeilLink/Agent/Core/AgentRuntime.swift \
    VeilLink/Agent/Core/AgentCapabilityProfile.swift \
    VeilLink/Agent/Core/AgentSession.swift \
    VeilLink/Agent/Core/AgentDiagnostics.swift \
    VeilLink/Agent/Language/LocalTextModelManifest.swift \
    VeilLink/Agent/Language/LocalTextModelRuntime.swift \
    VeilLink/Agent/Language/AgentPromptAssembler.swift \
    VeilLink/Agent/Language/AgentTokenStream.swift \
    VeilLink/Agent/Language/MockLocalTextModelRuntime.swift \
    VeilLink/Agent/Language/LocalTextModelCoordinator.swift \
    VeilLink/Agent/Core/AgentCoordinator.swift
pass "Agent Foundation strict-concurrency API-shape typecheck"

cat > "$HARNESS_DIR/agent-main.swift" <<'SWIFT'
import Foundation

@main
struct AgentHarness {
    @MainActor
    static func main() async throws {
        let runtime = MockLocalTextModelRuntime()
        precondition(runtime.state == .unloaded)
        try await runtime.prepare()
        precondition(runtime.state == .ready)
        var text = ""
        let request = AgentTextRequest(sessionID: "ci", messages: [], userText: "你好", maxNewTokens: 32, visualContext: nil)
        let result = try await runtime.generate(request: request) { chunk in text += chunk }
        precondition(text == result.text)
        precondition(text.contains("Foundation Mock"))
        runtime.unload()
        precondition(runtime.state == .unloaded)
        print("agent-runtime-ok")
    }
}
SWIFT
swiftc -parse-as-library -swift-version 5 \
    VeilLink/Core/PerformanceOverrides.swift \
    VeilLink/Core/DevicePerformanceProfile.swift \
    VeilLink/Health/VeilA9Lattice.swift \
    VeilLink/Agent/Compute/A9ComputePlanner.swift \
    VeilLink/Agent/Vision/AgentVisualContext.swift \
    VeilLink/Agent/Core/AgentModels.swift \
    VeilLink/Agent/Core/AgentRuntime.swift \
    VeilLink/Agent/Core/AgentCapabilityProfile.swift \
    VeilLink/Agent/Core/AgentSession.swift \
    VeilLink/Agent/Core/AgentDiagnostics.swift \
    VeilLink/Agent/Language/LocalTextModelManifest.swift \
    VeilLink/Agent/Language/LocalTextModelRuntime.swift \
    VeilLink/Agent/Language/AgentPromptAssembler.swift \
    VeilLink/Agent/Language/AgentTokenStream.swift \
    VeilLink/Agent/Language/MockLocalTextModelRuntime.swift \
    VeilLink/Agent/Language/LocalTextModelCoordinator.swift \
    "$HARNESS_DIR/agent-main.swift" -o "$HARNESS_DIR/agent-harness"
"$HARNESS_DIR/agent-harness" >/dev/null
pass "Agent Foundation offline streaming/cancelable runtime harness"

cat > "$HARNESS_DIR/CoreBluetooth.swift" <<'SWIFT'
import Foundation

public let CBCentralManagerOptionRestoreIdentifierKey = "CBCentralManagerOptionRestoreIdentifierKey"
public let CBPeripheralManagerOptionRestoreIdentifierKey = "CBPeripheralManagerOptionRestoreIdentifierKey"
public let CBCentralManagerScanOptionAllowDuplicatesKey = "CBCentralManagerScanOptionAllowDuplicatesKey"
public let CBConnectPeripheralOptionNotifyOnDisconnectionKey = "CBConnectPeripheralOptionNotifyOnDisconnectionKey"
public let CBAdvertisementDataServiceUUIDsKey = "CBAdvertisementDataServiceUUIDsKey"
public let CBCentralManagerRestoredStatePeripheralsKey = "CBCentralManagerRestoredStatePeripheralsKey"
public let CBPeripheralManagerRestoredStateServicesKey = "CBPeripheralManagerRestoredStateServicesKey"

public final class CBUUID: Hashable {
    public let uuidString: String
    public init(string: String) { self.uuidString = string }
    public static func == (lhs: CBUUID, rhs: CBUUID) -> Bool { lhs.uuidString == rhs.uuidString }
    public func hash(into hasher: inout Hasher) { hasher.combine(uuidString) }
}

public enum CBManagerState { case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn }
public enum CBPeripheralState { case disconnected, connecting, connected, disconnecting }
public enum CBCharacteristicWriteType { case withResponse, withoutResponse }
public struct CBCharacteristicProperties: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let write = CBCharacteristicProperties(rawValue: 1 << 0)
    public static let writeWithoutResponse = CBCharacteristicProperties(rawValue: 1 << 1)
    public static let notify = CBCharacteristicProperties(rawValue: 1 << 2)
}
public struct CBAttributePermissions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let writeable = CBAttributePermissions(rawValue: 1 << 0)
}
public enum CBATTError {
    public enum Code { case success, invalidPdu, requestNotSupported }
}

public protocol CBCentralManagerDelegate: AnyObject {}
public protocol CBPeripheralDelegate: AnyObject {}
public protocol CBPeripheralManagerDelegate: AnyObject {}

open class CBCharacteristic: NSObject {
    public var uuid: CBUUID
    public var value: Data?
    public var isNotifying: Bool
    public var properties: CBCharacteristicProperties
    public init(uuid: CBUUID, value: Data? = nil, isNotifying: Bool = false, properties: CBCharacteristicProperties = []) {
        self.uuid = uuid; self.value = value; self.isNotifying = isNotifying; self.properties = properties
    }
}
public final class CBMutableCharacteristic: CBCharacteristic {
    public init(type: CBUUID, properties: CBCharacteristicProperties, value: Data?, permissions: CBAttributePermissions) {
        super.init(uuid: type, value: value, properties: properties)
    }
}
open class CBService: NSObject {
    public var uuid: CBUUID
    public var characteristics: [CBCharacteristic]?
    public init(uuid: CBUUID) { self.uuid = uuid }
}
public final class CBMutableService: CBService {
    public init(type: CBUUID, primary: Bool) { super.init(uuid: type) }
}
public final class CBCentral: NSObject {
    public let identifier: UUID
    public var maximumUpdateValueLength: Int
    public init(identifier: UUID = UUID(), maximumUpdateValueLength: Int = 185) {
        self.identifier = identifier; self.maximumUpdateValueLength = maximumUpdateValueLength
    }
}
public final class CBPeripheral: NSObject {
    public let identifier: UUID
    public var state: CBPeripheralState
    public weak var delegate: CBPeripheralDelegate?
    public var services: [CBService]?
    public var canSendWriteWithoutResponse: Bool = true
    public init(identifier: UUID = UUID(), state: CBPeripheralState = .disconnected) {
        self.identifier = identifier; self.state = state
    }
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int { 185 }
    public func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {}
    public func discoverServices(_ serviceUUIDs: [CBUUID]?) {}
    public func readRSSI() {}
    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {}
    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {}
}
public final class CBCentralManager: NSObject {
    public weak var delegate: CBCentralManagerDelegate?
    public var state: CBManagerState = .poweredOn
    public init(delegate: CBCentralManagerDelegate?, queue: DispatchQueue?, options: [String: Any]? = nil) { self.delegate = delegate }
    public func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]? = nil) {}
    public func stopScan() {}
    public func connect(_ peripheral: CBPeripheral, options: [String: Any]? = nil) {}
    public func cancelPeripheralConnection(_ peripheral: CBPeripheral) {}
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] { [] }
}
public final class CBATTRequest: NSObject {
    public var characteristic: CBCharacteristic
    public var value: Data?
    public var central: CBCentral
    public init(characteristic: CBCharacteristic, value: Data? = nil, central: CBCentral = CBCentral()) {
        self.characteristic = characteristic; self.value = value; self.central = central
    }
}
public final class CBPeripheralManager: NSObject {
    public weak var delegate: CBPeripheralManagerDelegate?
    public var state: CBManagerState = .poweredOn
    public var isAdvertising: Bool = false
    public init(delegate: CBPeripheralManagerDelegate?, queue: DispatchQueue?, options: [String: Any]? = nil) { self.delegate = delegate }
    public func stopAdvertising() {}
    public func removeAllServices() {}
    public func add(_ service: CBMutableService) {}
    public func startAdvertising(_ advertisementData: [String: Any]?) {}
    public func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool { true }
    public func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {}
}
SWIFT
swiftc -emit-module -module-name CoreBluetooth "$HARNESS_DIR/CoreBluetooth.swift" -emit-module-path "$HARNESS_DIR/CoreBluetooth.swiftmodule"
swiftc -typecheck -swift-version 5 -I "$HARNESS_DIR" \
    VeilLink/Core/Models.swift \
    VeilLink/Core/PerformanceOverrides.swift \
    VeilLink/Core/DevicePerformanceProfile.swift \
    VeilLink/Transport/ConnectionEventGate.swift \
    VeilLink/Transport/BLEConnectionIntentStore.swift \
    VeilLink/Transport/BLELinkReliabilityPolicy.swift \
    VeilLink/Transport/BLELinkSnapshot.swift \
    VeilLink/Transport/BLEFramer.swift \
    VeilLink/Transport/BLETransport.swift
pass "BLE transport API-shape typecheck (Linux CoreBluetooth/Combine stubs)"

cat > "$HARNESS_DIR/UIKit.swift" <<'SWIFT'
@_exported import Foundation
public typealias CGFloat = Double
public class UIApplication {
    public enum State { case active, inactive, background }
    public static let shared = UIApplication()
    public var applicationState: State = .active
}
public class UISelectionFeedbackGenerator {
    public init() {}
    public func prepare() {}
    public func selectionChanged() {}
}
public class UIImpactFeedbackGenerator {
    public enum FeedbackStyle { case soft, light, medium, rigid }
    public init(style: FeedbackStyle) {}
    public func prepare() {}
    public func impactOccurred(intensity: CGFloat) {}
}
public class UINotificationFeedbackGenerator {
    public enum FeedbackType { case success, warning, error }
    public init() {}
    public func prepare() {}
    public func notificationOccurred(_ type: FeedbackType) {}
}
SWIFT
swiftc -emit-module -module-name UIKit "$HARNESS_DIR/UIKit.swift" -emit-module-path "$HARNESS_DIR/UIKit.swiftmodule"
swiftc -typecheck -I "$HARNESS_DIR" VeilLink/Core/HapticEngine.swift
pass "haptic engine API-shape typecheck (Linux stubs)"

bash -n scripts/ci-test.sh
bash -n scripts/package-unsigned-ipa.sh
bash -n scripts/inject-vfly-assets.sh
bash -n scripts/local-ci-sim.sh
pass "CI/package shell syntax"

python3 - <<'PY'
from pathlib import Path
bad=[]
for path in list(Path('VeilLink').rglob('*.swift'))+list(Path('VeilLinkTests').rglob('*.swift')):
    text=path.read_text(encoding='utf-8')
    for token in ['NavigationStack(', '.presentationDetents(', '.scrollContentBackground(', 'PhotosPicker(']:
        if token in text:
            bad.append((str(path), token))
if bad:
    raise SystemExit('iOS 15 compatibility guard failed: '+repr(bad))
print('ios15-ok')
PY
pass "iOS 15 compatibility guard"

python3 - <<'PY'
from pathlib import Path
models=Path('VeilLink/Core/Models.swift').read_text(encoding='utf-8')
adaptive=Path('VeilLink/UI/AdaptiveRootView.swift').read_text(encoding='utf-8')
app_model=Path('VeilLink/App/AppModel.swift').read_text(encoding='utf-8')
agent_swift='\n'.join(p.read_text(encoding='utf-8') for p in Path('VeilLink/Agent').rglob('*.swift'))
assert 'case agent = "灵核"' in models
assert models.index('case nearby') < models.index('case agent') < models.index('case settings')
assert '.tabItem { Label("灵核"' in adaptive
assert 'case .agent:' in adaptive and 'AgentHomeView(coordinator: model.agent, maleCNS: model.maleCNS)' in adaptive
assert 'let agent: AgentCoordinator' in app_model
assert 'let maleCNS: MaleCNSGraphManager' in app_model
assert 'agent.handleMemoryPressure()' in app_model
assert 'agent.handleBackground()' in app_model
for forbidden in ['URLSession', 'KeychainStore', 'DatabaseStore', 'BLETransport', 'TacticalState']:
    assert forbidden not in agent_swift, forbidden
print('agent-foundation-boundaries-ok')
PY
pass "Agent root navigation / offline privacy boundaries"

python3 - <<'PYA9'
from pathlib import Path
a9='\n'.join(p.read_text(encoding='utf-8') for p in Path('VeilLink/Health').rglob('*.swift'))
settings=Path('VeilLink/UI/SettingsView.swift').read_text(encoding='utf-8')
app=Path('VeilLink/App/AppModel.swift').read_text(encoding='utf-8')
assert 'static let cells: [Cell]' in a9 and 'count: 144' in a9
for forbidden in ['CryptoKit', 'SHA256', 'packet_sha', 'decision_sha', 'runtime_attestation', 'contract_sha256']:
    assert forbidden not in a9, forbidden
assert 'advisory-only' in a9.lower() or 'advisory only' in a9.lower()
assert 'model.database.integrityCheck()' not in settings
assert 'model.runA9StorageCheck()' in settings
assert 'let a9Health: VeilA9HealthMonitor' in app
compute='\n'.join(p.read_text(encoding='utf-8') for p in Path('VeilLink/Agent/Compute').rglob('*.swift'))
native=(Path('VeilLink/Native/VeilFlyKernel.c').read_text(encoding='utf-8') + '\n' + Path('VeilLink/Agent/MaleCNS/MaleCNSNativeKernel.swift').read_text(encoding='utf-8'))
assert 'MaleCNSComputeBudget' in compute
assert 'transportReserveUnits' in compute
assert 'A9 does not create physical compute' in compute
assert 'TacticalState' not in compute
assert 'vlfly_lif_run_f32' in native and 'vlfly_reduce_readouts_u32' in native
assert 'stepInPlace' in native and 'runEpisode' in native and 'readoutSnapshot' in native
c_kernel=Path('VeilLink/Native/VeilFlyKernel.c').read_text(encoding='utf-8')
for forbidden in ['malloc(', 'calloc(', 'realloc(', 'free(']: assert forbidden not in c_kernel, forbidden
governor=Path('VeilLink/Agent/Compute/A9ComputeGovernor.swift').read_text(encoding='utf-8')
assert 'bindMaleCNSConsumer' in governor and 'applyComputeBudget(plan.maleCNS)' in governor
print('a9-health-boundaries-ok')
PYA9
pass "A9 digest-free advisory health lattice boundaries"

python3 - <<'PY'
from pathlib import Path
theme=Path('VeilLink/Core/AppTheme.swift').read_text(encoding='utf-8')
nearby=Path('VeilLink/UI/NearbyView.swift').read_text(encoding='utf-8')
settings=Path('VeilLink/UI/SettingsView.swift').read_text(encoding='utf-8')
adaptive=Path('VeilLink/UI/AdaptiveRootView.swift').read_text(encoding='utf-8')
conversation=Path('VeilLink/UI/ConversationViews.swift').read_text(encoding='utf-8')
assert 'RenderCompatibilityPolicy.shouldUseLegacyCompositor' in theme
assert 'guard active, !reduceMotion, VeilRenderProfile.allowsPersistentAnimations else { return }' in theme
assert 'guard isRunning, !reduceMotion, VeilRenderProfile.allowsPersistentAnimations else { return }' in nearby
assert 'VeilLinkTrace(active: peer.trustState == .awaitingConfirmation, width: 30)' in nearby
assert 'VeilLinkTrace(active: true, width: 34)' not in settings
assert 'VeilLinkTrace(active: true, width: 34)' not in adaptive
assert 'VeilLinkTrace(active: true, width: 26)' not in conversation
assert 'VeilLinkTrace(active: true, width: 86)' not in conversation
print('legacy-render-and-stable-scroll-ok')
PY
pass "SE1 / iPhone 7 / iOS 15 legacy compositor guard"

python3 - <<'PY'
import sqlite3, tempfile, os
fd, path = tempfile.mkstemp(suffix='.sqlite'); os.close(fd)
try:
    db=sqlite3.connect(path)
    db.executescript('''
    CREATE TABLE conversations(
      id TEXT PRIMARY KEY,
      local_identity_id TEXT NOT NULL,
      peer_identity_id TEXT NOT NULL,
      title TEXT NOT NULL,
      last_message_preview TEXT,
      updated_at REAL NOT NULL,
      unread_count INTEGER NOT NULL DEFAULT 0
    );
    INSERT INTO conversations VALUES('old','local','p1','Old',NULL,100,2);
    INSERT INTO conversations VALUES('new','local','p2','New',NULL,200,0);
    ALTER TABLE conversations ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0;
    CREATE INDEX IF NOT EXISTS idx_conversations_pinned_v8 ON conversations(local_identity_id, is_pinned, updated_at DESC);
    UPDATE conversations SET is_pinned=1 WHERE id='old';
    ''')
    rows=db.execute("SELECT id FROM conversations WHERE local_identity_id='local' ORDER BY is_pinned DESC, updated_at DESC").fetchall()
    assert rows == [('old',), ('new',)]
    db.execute("UPDATE conversations SET unread_count=0 WHERE id='old'")
    assert db.execute("SELECT unread_count FROM conversations WHERE id='old'").fetchone()[0] == 0
    db.execute("UPDATE conversations SET unread_count=CASE WHEN unread_count<1 THEN 1 ELSE unread_count END WHERE id='new'")
    assert db.execute("SELECT unread_count FROM conversations WHERE id='new'").fetchone()[0] == 1
finally:
    db.close(); os.remove(path)
print('schema-v8-ok')
PY
pass "Schema V7 -> V8 pin/unread migration smoke"

python3 - <<'PY'
import sqlite3
db=sqlite3.connect(':memory:')
db.executescript('''
CREATE TABLE conversations(id TEXT PRIMARY KEY, local_identity_id TEXT NOT NULL, peer_identity_id TEXT NOT NULL, updated_at REAL NOT NULL, is_pinned INTEGER NOT NULL DEFAULT 0);
CREATE TABLE messages(id TEXT PRIMARY KEY);
CREATE TABLE attachments(id TEXT PRIMARY KEY, message_id TEXT NOT NULL);
CREATE TABLE outbound_queue(message_id TEXT PRIMARY KEY, local_identity_id TEXT NOT NULL, target_identity_id TEXT NOT NULL, retry_count INTEGER NOT NULL DEFAULT 0, next_attempt_at REAL NOT NULL);
CREATE INDEX idx_conversations_peer_v8 ON conversations(local_identity_id, peer_identity_id, updated_at DESC);
CREATE INDEX idx_attachments_message_v8 ON attachments(message_id);
INSERT INTO outbound_queue VALUES('m','l','p',0,0);
''')
indexes={row[1] for row in db.execute("PRAGMA index_list('conversations')")}
assert 'idx_conversations_peer_v8' in indexes
indexes={row[1] for row in db.execute("PRAGMA index_list('attachments')")}
assert 'idx_attachments_message_v8' in indexes
expected=[(1,4),(2,8),(3,16),(4,32),(5,60),(6,60)]
for retry,delay in expected:
    now=1000.0
    db.execute('''
    UPDATE outbound_queue
    SET retry_count = MIN(retry_count + 1, 30),
        next_attempt_at = ? + CASE
            WHEN retry_count <= 0 THEN 4
            WHEN retry_count = 1 THEN 8
            WHEN retry_count = 2 THEN 16
            WHEN retry_count = 3 THEN 32
            ELSE 60
        END
    WHERE message_id='m' AND local_identity_id='l' AND target_identity_id='p';
    ''',(now,))
    got=db.execute("SELECT retry_count,next_attempt_at FROM outbound_queue WHERE message_id='m'").fetchone()
    assert got[0] == retry, got
    assert abs(got[1] - (now+delay)) < 1e-9, got
print('runtime-sql-opt-ok')
PY
pass "runtime optimization SQLite/index smoke"

python3 - <<'PY2'
from pathlib import Path
root = Path('.')
db = (root/'VeilLink/Storage/DatabaseStore.swift').read_text(encoding='utf-8')
chat = (root/'VeilLink/UI/ConversationViews.swift').read_text(encoding='utf-8')
preview = (root/'VeilLink/Media/ImagePreviewCache.swift').read_text(encoding='utf-8')
shards = (root/'VeilLink/UI/TransferShardView.swift').read_text(encoding='utf-8')
profile = (root/'VeilLink/Core/DevicePerformanceProfile.swift').read_text(encoding='utf-8')
app = (root/'VeilLink/App/AppModel.swift').read_text(encoding='utf-8')
ble = (root/'VeilLink/Transport/BLETransport.swift').read_text(encoding='utf-8')
session = (root/'VeilLink/Security/SessionCoordinator.swift').read_text(encoding='utf-8')
overrides = (root/'VeilLink/Core/PerformanceOverrides.swift').read_text(encoding='utf-8')
owner = (root/'VeilLink/UI/OwnerConsoleView.swift').read_text(encoding='utf-8')
viewer = (root/'VeilLink/UI/FullScreenImageViewer.swift').read_text(encoding='utf-8')
viewer_policy = (root/'VeilLink/Core/ImageViewerPolicy.swift').read_text(encoding='utf-8')
reliability = (root/'VeilLink/Transport/BLELinkReliabilityPolicy.swift').read_text(encoding='utf-8')
assert 'fetchRecentMessages' in db and 'VeilDevicePerformance.current.decryptedBodyCacheEntries' in db
assert 'decryptedBodyCacheOrderHead' in db and 'fetchMessageIDs' in db
assert 'SELECT chunk_index, ciphertext FROM inbound_attachment_chunks' in db
assert 'ImagePreviewCache.downsample' in chat and 'kCGImageSourceThumbnailMaxPixelSize' in preview
assert 'VeilDevicePerformance.current.messageWindowInitial' in chat and 'DispatchQueue.global(qos: .userInitiated).async' in chat
assert 'usesMinimalRendering' in shards and 'ShardGridShape' in shards
for token in ['iPhone8,4','iPhone9,1','iPhone12,8','iPhone14,2','iPad13,1']:
    assert token in profile
assert 'messageRefreshDebounceNanoseconds' in app and 'handleMemoryPressure' in app
assert 'bleQueueByteLimit' in ble and 'bleReassemblyByteLimit' in ble
assert 'outboundAttachmentCacheBytes' in session
assert 'PerformanceOverridePolicy' in overrides and '2_048' in overrides and '16 * 1_024 * 1_024' in overrides
assert 'THERMAL HERESY' in owner and '把散热交给命运' in owner and '恢复理智' in owner
assert 'allowPersistentAnimations' in owner and 'disableRefreshCoalescing' in owner
assert 'FullScreenImageViewer' in chat and 'showsLargeImage' in chat
assert 'MagnificationGesture()' in viewer and 'DragGesture(minimumDistance: 4)' in viewer
assert 'ImagePreviewCache.downsample' in viewer and '4_096' in viewer_policy
assert 'CBCentralManagerScanOptionAllowDuplicatesKey: true' in ble
assert 'PeerOutboundQueue' in ble and 'priority: BLESendPriority' in ble
assert 'readRSSI()' in ble and 'recoverStalledTransportQueuesIfNeeded' in ble
assert 'attempt <= 5' not in ble and 'reconnectDelay(attempt:' in ble
assert 'CBAdvertisementDataLocalNameKey' not in ble
assert 'handshakeRetryScheduleNanoseconds' in session and 'wakeOutboundForPeer' in session
assert 'maximumAcknowledgementAttempts' not in session
assert 'packetBurstLimit' in reliability and 'interBurstDelay' in reliability
games = (root/'VeilLink/Core/MiniGames.swift').read_text(encoding='utf-8')
game_ui = (root/'VeilLink/UI/MiniGameViews.swift').read_text(encoding='utf-8')
tactical_ui = (root/'VeilLink/UI/TacticalGameViews.swift').read_text(encoding='utf-8')
tactical_render = (root/'VeilLink/UI/TacticalLocalRenderCache.swift').read_text(encoding='utf-8')
app_entry = (root/'VeilLink/App/VeilLinkApp.swift').read_text(encoding='utf-8')
assert 'MiniGameStatistics' in games and 'MiniGameReplayFrame' in games and 'static func replay(sessionID:' in games
assert 'threefoldRepetition' in games and 'currentPositionRepetitionCount' in games and 'consecutiveCheckCount' in games
assert '棋局回放' in game_ui and '自动回放' in game_ui and '掷骰子' in game_ui and '当前加密会话' in game_ui
assert '待回应' in game_ui
# Tactical battlefield is install-local and programmatic: no image/network decoder path.
for forbidden in ['AsyncImage', 'UIImage', 'Image(\"', 'Image(decorative:', 'Image(uiImage:', 'URLSession', 'Data(contentsOf:']:
    assert forbidden not in tactical_ui, forbidden
    assert forbidden not in tactical_render, forbidden
assert 'TacticalLocalRenderCache.cells' in tactical_ui
assert 'TacticalUnitCounterView' in tactical_ui
assert 'TacticalTerrainCodeMark' in tactical_ui
assert 'TacticalIntelLayer' in tactical_ui and '交战预估' in tactical_ui and '确认交战' in tactical_ui
assert 'supplyNetwork(for faction:' in (root/'VeilLink/Core/TacticalGame.swift').read_text(encoding='utf-8')
assert 'threatenedHexes(by faction:' in (root/'VeilLink/Core/TacticalGame.swift').read_text(encoding='utf-8')
assert 'combatForecast(attackerID:' in (root/'VeilLink/Core/TacticalGame.swift').read_text(encoding='utf-8')
assert 'static let cells' in tactical_render and 'static let terrainSegments' in tactical_render
assert 'displayCenter(for layout:' in tactical_render
assert 'TacticalLocalRenderCache.warmUp()' in app_entry
print('targeted-perf-ok')
PY2
pass "current-version targeted-device + games + replay + God Mode + image viewer + BLE reliability guard"

python3 - <<'PY'
from pathlib import Path
import tempfile, zipfile, shutil
root=Path(tempfile.mkdtemp(prefix='veillink-ipa-smoke-'))
try:
    app=root/'Payload'/'VeilLink.app'; app.mkdir(parents=True)
    (app/'VeilLink').write_bytes(b'arm64-placeholder')
    (app/'Info.plist').write_bytes(Path('VeilLink/Resources/Info.plist').read_bytes())
    ipa=root/'VeilLink-unsigned-smoke.ipa'
    with zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as z:
        for p in (root/'Payload').rglob('*'):
            if p.is_file(): z.write(p,p.relative_to(root))
    with zipfile.ZipFile(ipa) as z:
        names=set(z.namelist())
        assert 'Payload/VeilLink.app/VeilLink' in names
        assert 'Payload/VeilLink.app/Info.plist' in names
finally:
    shutil.rmtree(root)
print('ipa-layout-ok')
PY
pass "unsigned IPA Payload layout smoke"

python3 - <<'PY'
from pathlib import Path
bad=[]
for path in Path('.').rglob('*'):
    if not path.is_file() or '.git' in path.parts: continue
    if path.suffix.lower() in {'.zip','.ipa','.png','.jpg','.jpeg','.xcassets'}: continue
    try: text=path.read_text(encoding='utf-8')
    except Exception: continue
    for n,line in enumerate(text.splitlines(),1):
        if line.endswith(' ') or line.endswith('\t'):
            bad.append(f'{path}:{n}')
if bad:
    raise SystemExit('trailing whitespace: '+', '.join(bad[:20]))
print('whitespace-ok')
PY
pass "text whitespace guard"

TESTS=$(grep -RhoE 'func test[A-Za-z0-9_]+' VeilLinkTests | wc -l | tr -d ' ')
SWIFT_COUNT=${#SWIFT_FILES[@]}
SWIFT_LINES=$(cat "${SWIFT_FILES[@]}" | wc -l | tr -d ' ')
info "Swift files: $SWIFT_COUNT"
info "Swift lines: $SWIFT_LINES"
info "XCTest methods: $TESTS"

if command -v xcodebuild >/dev/null && command -v xcodegen >/dev/null; then
    info "macOS/Xcode tools detected; run GitHub-equivalent build separately"
else

swiftc -parse Tools/AgentTraining/SelfPlayExporter.swift >/dev/null
python3 - <<'PYTRAIN'
from pathlib import Path
src = Path('Tools/AgentTraining/SelfPlayExporter.swift').read_text(encoding='utf-8')
assert 'Only gomoku, xiangqi and ludo are training-enabled' in src
assert 'deterministicLudoSessionID(seed:' in src
assert 'UUID().uuidString' not in src
assert 'case "--games"' in src
assert 'case "--episode-offset"' in src
print('agent-training-source-ok')
PYTRAIN
pass "agent self-play exporter source / tactical exclusion / deterministic Ludo seed"

# Linux Swift can spend minutes compiling the full historical game engine plus the standalone
# exporter. Keep ordinary CI fast; opt into the executable/data determinism smoke explicitly.
if [[ "${VEILLINK_RUN_SLOW_TRAINING_SMOKE:-0}" == "1" ]]; then
    TRAINING_DIR="$HARNESS_DIR/training"
    mkdir -p "$TRAINING_DIR"
    swiftc \
        VeilLink/Core/Models.swift \
        VeilLink/Core/TacticalGame.swift \
        VeilLink/Core/MiniGames.swift \
        VeilLink/Agent/Games/AgentGameAdapter.swift \
        VeilLink/Agent/Games/GomokuAgentAdapter.swift \
        VeilLink/Agent/Games/XiangqiAgentAdapter.swift \
        VeilLink/Agent/Games/LudoAgentAdapter.swift \
        VeilLink/Agent/Games/AgentGameRegistry.swift \
        Tools/AgentTraining/SelfPlayExporter.swift \
        -o "$TRAINING_DIR/selfplay"
    "$TRAINING_DIR/selfplay" --output "$TRAINING_DIR/a.jsonl" --episodes 1 --seed 1776 >/dev/null
    "$TRAINING_DIR/selfplay" --output "$TRAINING_DIR/b.jsonl" --episodes 1 --seed 1776 >/dev/null
    cmp "$TRAINING_DIR/a.jsonl" "$TRAINING_DIR/b.jsonl"
    python3 - "$TRAINING_DIR/a.jsonl" <<'PYTRAINROWS'
import json, sys
rows=[json.loads(line) for line in open(sys.argv[1], encoding='utf-8') if line.strip()]
assert rows
assert {row['game'] for row in rows} <= {'gomoku','xiangqi','ludo'}
assert all(row['game'] != 'tactical' for row in rows)
assert all(len(row['state']) == 256 and len(row['action']) == 16 for row in rows)
print('agent-training-slow-smoke-ok')
PYTRAINROWS
    pass "agent self-play executable determinism smoke"
else
    info "slow self-play executable smoke skipped; set VEILLINK_RUN_SLOW_TRAINING_SMOKE=1 to run"
fi

python3 -m py_compile \
    Tools/AgentTraining/train_policy.py \
    Tools/AgentTraining/train_policy_ranker.py \
    Tools/AgentTraining/train_language_lora.py \
    Tools/AgentTraining/build_agent_sft_dataset.py \
    Tools/AgentTraining/export_policy_vlpol.py
python3 - <<'PYAGENTTRAIN'
import json, pathlib
pins=json.loads(pathlib.Path('Tools/AgentTraining/manifests/language_model_pins.json').read_text())
assert {m['repo_id'] for m in pins['models']} == {'HuggingFaceTB/SmolLM2-135M-Instruct','Qwen/Qwen2.5-0.5B-Instruct'}
assert all(len(m['primary_weight_sha256']) == 64 for m in pins['models'])
registry=pathlib.Path('VeilLink/Agent/Games/AgentGameRegistry.swift').read_text()
assert 'trainingEnabledKinds: [MiniGameKind] = [.gomoku, .xiangqi, .ludo]' in registry
assert 'case .tactical' in registry
for path in ['Tools/AgentTraining/SelfPlayExporter.swift','Tools/AgentTraining/build_agent_sft_dataset.py']:
    text=pathlib.Path(path).read_text()
    assert 'tactical' in text.lower()
manifest=json.loads(pathlib.Path('VeilLink/Resources/AgentModels/game_policy_ranker_v4.manifest.json').read_text())
blob=pathlib.Path('VeilLink/Resources/AgentModels/game_policy_ranker_v4.vlpol').read_bytes()
import hashlib
assert manifest['format'] == 'VLPOL1' and manifest['excluded_games'] == ['tactical']
assert hashlib.sha256(blob).hexdigest() == manifest['sha256']
assert len(blob) == manifest['byte_count'] and len(blob) < 1_000_000
runtime=pathlib.Path('VeilLink/Agent/Games/TrainedGamePolicyRuntime.swift').read_text()
assert 'case .tactical: return nil' in runtime
assert 'adapter.enumerateLegalActions().filter(adapter.validate)' in runtime
print('agent-training-contract-ok')
PYAGENTTRAIN
pass "agent training scripts / pinned model provenance"

info "xcodebuild/xcodegen unavailable here: true Simulator/device compilation remains a macOS/GitHub CI gate"
fi

python3 - <<'PY'
import math, pathlib, re
root = pathlib.Path('.')
cache = (root/'VeilLink/UI/TacticalLocalRenderCache.swift').read_text(encoding='utf-8')
views = (root/'VeilLink/UI/TacticalGameViews.swift').read_text(encoding='utf-8')
xiangqi = (root/'VeilLink/UI/MiniGameViews.swift').read_text(encoding='utf-8')
hex_w = 1.0 / 9.55
hex_h = hex_w * 0.88
rows, cols = 7, 9
board_h = hex_h * (1.0 + 0.75 * (rows - 1))
expected_ratio = 1.0 / board_h
# normalized footprint bounds used by TacticalLocalRenderCache.cells
min_x=min_y=1.0; max_x=max_y=0.0
for row in range(rows):
    for col in range(cols):
        cx = hex_w * 0.52 + col * hex_w + (0.0 if row % 2 == 0 else hex_w * 0.5)
        cy = hex_h * 0.5 + row * hex_h * 0.75
        min_x=min(min_x,cx-hex_w/2); max_x=max(max_x,cx+hex_w/2)
        min_y=min(min_y,cy-hex_h/2); max_y=max(max_y,cy+hex_h/2)
assert min_x >= -1e-6 and max_x <= 1.0 + 1e-6
assert min_y >= -1e-6 and abs(max_y-board_h) < 1e-9
assert 'static let boardAspectRatio: CGFloat = 1.0 / (hexHeightFactor * (1.0 + 0.75 * CGFloat(TacticalState.rows - 1)))' in cache
# Smallest supported compact battlefield: 320 pt screen minus 20 pt tactical horizontal padding.
compact_board_width = 300.0
compact_hex_height = compact_board_width * hex_h
assert 24.0 <= compact_hex_height
assert '.frame(width: attackTarget ? 24 : 23, height: attackTarget ? 24 : 23)' in views
assert 'if let name = hex.name, unit == nil' in views
assert 'displayCenter(for: layout, flipped: localPlayer == .guest)' in views
assert '.frame(width: max(0, width - margin * 2 - stepX * 1.1))' in xiangqi
print(f'game-layout-ok ratio={expected_ratio:.4f} compactHexH={compact_hex_height:.2f}')
PY
pass "mini-game normalized layout geometry"
printf 'LOCAL CI SIMULATION: PASS\n'
