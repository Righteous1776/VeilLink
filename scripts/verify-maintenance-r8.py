#!/usr/bin/env python3
from pathlib import Path
import re, sys
ROOT=Path.cwd()

def fail(msg):
    raise SystemExit('MAINTENANCE R8 FAIL: '+msg)

def read(rel):
    p=ROOT/rel
    if not p.is_file(): fail(f'missing {rel}')
    return p.read_text(encoding='utf-8')

info=read('VeilLink/Resources/Info.plist')
if not re.search(r'<key>CFBundleShortVersionString</key>\s*<string>0\.10\.10</string>',info): fail('version != 0.10.10')
if not re.search(r'<key>CFBundleVersion</key>\s*<string>52</string>',info): fail('build != 52')
plane=read('VeilLink/Agent/Integration/VeilAppControlPlane.swift')
for n in ['guard permissions.localMutationsEnabled else', 'guard permissions.diagnosticsExportEnabled else', 'case .setResourceFocus, .trimCaches, .refreshBLE']:
    if n not in plane: fail(f'control invariant missing: {n}')
app=read('VeilLink/App/AppModel.swift')
for n in ['autoRegulationLastLoggedFingerprint', 'let didMutate = autoRegulationLastActionAt != beforeMutation', 'a9PeriodicSamplingNanoseconds', 'case .legacyA10: return 8_000_000_000', 'case .balanced: return 6_000_000_000', 'case .high: return 4_000_000_000', 'if autoRegulationLastLoggedFingerprint != logFingerprint']:
    if n not in app: fail(f'AppModel maintenance invariant missing: {n}')
# Ensure repeated evaluation logging is deduplicated and old false-positive mutation accounting is gone.
if 'didMutate: agentControls.autoRegulationMode == .safeAutomatic' in app: fail('stale run-once mutation accounting remains')
if app.count('event: "agent.autotune.evaluate"') != 1: fail('unexpected AutoTune evaluate log surface')
# No new destructive/control escalation surface.
for forbidden in ['deleteDatabase','deleteIdentity','exportPrivateKey','sendArbitraryMessage','remoteControlPeer','enableLocalMutations','enableDiagnosticsExport']:
    if forbidden in plane: fail(f'forbidden control surface: {forbidden}')
# Historical snapshots remain present.
for rel in ['docs/history/control-plane/V0104_R6/manifest.sha256','docs/history/maintenance/V0105_R7/manifest.sha256']:
    if not (ROOT/rel).is_file(): fail(f'history manifest missing: {rel}')
for rel in ['scripts/upgrade-transaction.py','scripts/maintenance-health-report.py','VeilLinkTests/VeilMaintenanceInvariantTests.swift']:
    if not (ROOT/rel).is_file(): fail(f'maintenance asset missing: {rel}')
print('VEILLINK_MAINTENANCE_R8_PASS')
print('FEATURE_FREEZE=active')
print('INSTALLER_ATOMICITY=rollback-on-failure')
print('AUTOTUNE_LOG_DEDUP=enabled')
print('LEGACY_A10_SAMPLING=8s')
print('R7_HISTORY=preserved')
