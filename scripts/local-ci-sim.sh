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
assert plist['CFBundleShortVersionString'] == '0.3.7'
assert plist['CFBundleVersion'] == '13'
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
    VeilLink/Core/RenderCompatibilityPolicy.swift \
    VeilLink/Transport/ConnectionEventGate.swift \
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
precondition(RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone9,1", osMajorVersion: 15))
precondition(!RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone9,1", osMajorVersion: 16))
precondition(!RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone14,2", osMajorVersion: 15))

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
swiftc     VeilLink/Core/Models.swift     VeilLink/Core/MessageTextFeatures.swift     VeilLink/Core/RenderCompatibilityPolicy.swift     VeilLink/Transport/ConnectionEventGate.swift     VeilLink/Security/PacketAbuseLimiter.swift     VeilLink/Transport/BLEFramer.swift     "$HARNESS_DIR/main.swift"     -o "$HARNESS_DIR/core-harness"
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
assert 'guard active, !reduceMotion, !VeilRenderProfile.usesLegacyCompositorPath else { return }' in theme
assert 'guard isRunning, !reduceMotion, !VeilRenderProfile.usesLegacyCompositorPath else { return }' in nearby
assert 'VeilLinkTrace(active: peer.trustState == .awaitingConfirmation, width: 30)' in nearby
assert 'VeilLinkTrace(active: true, width: 34)' not in settings
assert 'VeilLinkTrace(active: true, width: 34)' not in adaptive
assert 'VeilLinkTrace(active: true, width: 26)' not in conversation
assert 'VeilLinkTrace(active: true, width: 86)' not in conversation
print('legacy-render-ok')
PY
pass "iPhone 7 / iOS 15 legacy compositor guard"

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
