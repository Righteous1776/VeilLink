#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path.cwd()
checks = {
    'VeilLink/Core/RuntimeMaintenanceTuning.swift': [
        'struct VeilRuntimeMaintenanceTuning', 'outboundRetryIntervalNanoseconds',
        'bleQueuedMaintenanceNanoseconds', 'jitterStatsPublishInterval'
    ],
    'VeilLink/Security/SessionCoordinator.swift': [
        'private var retryTask: Task<Void, Never>?', 'ensureRetryLoopIfNeeded()',
        'stopRetryLoopIfIdle()', 'pendingOutboundCount(localIdentityID:'
    ],
    'VeilLink/Transport/BLETransport.swift': [
        'currentMaintenanceIntervalNanoseconds()', 'lastRSSIMaintenanceAt',
        'maintenanceTuning.rssiPollInterval'
    ],
    'VeilLink/Voice/WalkieTalkieAudioController.swift': [
        'pendingMuLawOffset', 'publishJitterSnapshot(force: Bool = false)',
        'if !playbackEngine.isRunning || !playerNode.isPlaying', 'playbackFormat'
    ],
    'VeilLink/UI/ConversationViews.swift': [
        'reload(loadAll: Bool = false, showLoading: Bool = false)',
        'if messages != loadedMessages', 'reload(showLoading: true)'
    ],
    'VeilLinkTests/RuntimeMaintenanceOptimizationR12Tests.swift': [
        'testLegacyMaintenanceUsesLowerDutyCycleThanHighTier',
        'testQueuedTransportMaintenanceRemainsMoreResponsiveThanIdle'
    ],
}
for rel, needles in checks.items():
    path = ROOT / rel
    if not path.is_file():
        raise SystemExit(f'FAIL missing {rel}')
    text = path.read_text(encoding='utf-8')
    for needle in needles:
        if needle not in text:
            raise SystemExit(f'FAIL {rel}: {needle}')

session = (ROOT/'VeilLink/Security/SessionCoordinator.swift').read_text(encoding='utf-8')
if 'Timer.publish(every: 2' in session:
    raise SystemExit('FAIL permanent 2-second retry timer still present')
if 'static let version = 4' not in session:
    raise SystemExit('FAIL protocol version drift')
for needle in ['case .voice:', 'sendVoice(', 'case .pttControl', 'case .pttAudio', 'ptt-control', 'ptt-audio']:
    if needle not in session:
        raise SystemExit(f'FAIL R11 protocol invariant: {needle}')

walkie=(ROOT/'VeilLink/Voice/WalkieTalkieAudioController.swift').read_text(encoding='utf-8')
if 'pendingMuLaw.removeFirst' in walkie:
    raise SystemExit('FAIL PTT hot path still shifts Data every frame')

wire=(ROOT/'VeilLink/Core/WireCodec.swift').read_text(encoding='utf-8')
for needle in ['case pttControl = 6', 'case pttAudio = 7']:
    if needle not in wire:
        raise SystemExit(f'FAIL wire invariant: {needle}')

info=(ROOT/'VeilLink/Resources/Info.plist').read_text(encoding='utf-8')
for key,value in [('CFBundleShortVersionString','$(MARKETING_VERSION)'),('CFBundleVersion','$(CURRENT_PROJECT_VERSION)')]:
    if not re.search(rf'<key>{key}</key>\s*<string>{re.escape(value)}</string>',info):
        raise SystemExit(f'FAIL plist {key}')
project=(ROOT/'project.yml').read_text(encoding='utf-8')
if 'MARKETING_VERSION: "26.9"' not in project or 'CURRENT_PROJECT_VERSION: "53"' not in project:
    raise SystemExit('FAIL VeilLink 26.9 / Build 53 project identity')
if 'NSMicrophoneUsageDescription' not in info:
    raise SystemExit('FAIL microphone permission description')

print('VEILLINK_R12_RUNTIME_MAINTENANCE_PASS')
