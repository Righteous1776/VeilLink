#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pass() { printf 'PASS  %s\n' "$1"; }
info() { printf 'INFO  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; exit 1; }

command -v swiftc >/dev/null || fail "swiftc not found"
command -v python3 >/dev/null || fail "python3 not found"

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
    VeilLink/Transport/ConnectionEventGate.swift \
    VeilLink/Transport/BLEConnectionIntentStore.swift \
    VeilLink/Transport/BLELinkReliabilityPolicy.swift \
    VeilLink/Security/PacketAbuseLimiter.swift \
    VeilLink/Transport/BLEFramer.swift
pass "Linux-compatible core typecheck"

HARNESS_DIR="$(mktemp -d)"
trap 'rm -rf "$HARNESS_DIR"' EXIT
cat > "$HARNESS_DIR/main.swift" <<'SWIFT'
import Foundation

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
let fragments = BLEFragment.split(payload, maximumPacketSize: 31)
precondition(!fragments.isEmpty)
let assembler = BLEFragmentAssembler(maxAssembledBytes: 1024, maxPacketBytes: 31, maxTotalBufferedBytes: 2048)
var rebuilt: Data?
for fragment in fragments.reversed() {
    rebuilt = assembler.ingest(source: transport, packet: fragment.encoded) ?? rebuilt
}
precondition(rebuilt == payload)
print("core-harness-ok")
SWIFT
swiftc     VeilLink/Core/Models.swift     VeilLink/Core/MessageTextFeatures.swift     VeilLink/Core/MiniGames.swift     VeilLink/Core/TacticalGame.swift     VeilLink/Core/RenderCompatibilityPolicy.swift     VeilLink/Core/PerformanceOverrides.swift     VeilLink/Core/DevicePerformanceProfile.swift     VeilLink/Core/ImageViewerPolicy.swift     VeilLink/Transport/ConnectionEventGate.swift     VeilLink/Transport/BLELinkReliabilityPolicy.swift     VeilLink/Security/PacketAbuseLimiter.swift     VeilLink/Transport/BLEFramer.swift     "$HARNESS_DIR/main.swift"     -o "$HARNESS_DIR/core-harness"
"$HARNESS_DIR/core-harness" >/dev/null
pass "core executable behavior harness"

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
for forbidden in ['AsyncImage', 'UIImage', 'Image(']:
    assert forbidden not in tactical_ui, forbidden
    assert forbidden not in tactical_render, forbidden
assert 'TacticalLocalRenderCache.cells' in tactical_ui
assert 'TacticalUnitCounterView' in tactical_ui
assert 'TacticalTerrainCodeMark' in tactical_ui
assert 'static let cells' in tactical_render and 'static let terrainSegments' in tactical_render
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
    info "xcodebuild/xcodegen unavailable here: true Simulator/device compilation remains a macOS/GitHub CI gate"
fi

printf 'LOCAL CI SIMULATION: PASS\n'

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
assert 23.0 <= compact_hex_height
assert '.frame(width: 23, height: 23)' in views
assert 'if let name = hex.name, unit == nil' in views
assert '.frame(width: max(0, width - margin * 2 - stepX * 1.1))' in xiangqi
print(f'game-layout-ok ratio={expected_ratio:.4f} compactHexH={compact_hex_height:.2f}')
PY
pass "mini-game normalized layout geometry"
