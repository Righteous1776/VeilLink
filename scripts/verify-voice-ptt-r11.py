#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path.cwd()
checks = {
    'VeilLink/Voice/PTTJitterBuffer.swift': [
        'struct VeilPTTJitterBuffer', 'case conceal', 'VeilRealtimeAudioTuning', 'missingFramePatienceTicks'
    ],
    'VeilLink/Voice/WalkieTalkieAudioController.swift': [
        'startPlayoutTimer', 'playoutTick()', 'transmitDroppedFrames', 'jitterDepth', 'Data(repeating: 0xFF'
    ],
    'VeilLink/Voice/VoiceMessageAudioController.swift': [
        'onAutomaticFinish', 'VeilVoicePlaybackArbiter', 'playbackProgressInterval'
    ],
    'VeilLink/Voice/VoiceMessageViews.swift': [
        'recorder.onAutomaticFinish', 'if recorder.isRecording { recorder.cancel() }'
    ],
    'VeilLink/Voice/PTTWire.swift': [
        'struct VeilPTTSendReport', 'var dropped: Int', 'VeilMuLaw'
    ],
    'VeilLink/Transport/BLELinkReliabilityPolicy.swift': [
        'case realtime = 1', 'case control = 2'
    ],
    'VeilLink/Transport/BLETransport.swift': [
        'private var realtime = OutboundPacketQueue()',
        'control.removeFirst()', 'realtime.removeFirst()', 'packetReserve', 'byteReserve'
    ],
    'VeilLink/Security/SessionCoordinator.swift': [
        '-> VeilPTTSendReport', '.realtime', 'database.trustedContact', 'context: "ptt-audio"'
    ],
    'VeilLink/UI/ToolCenterView.swift': [
        'LIVE AUDIO', 'JITTER BUFFER', 'RX LOSS', 'TX DROP', 'radio.jitterDepth'
    ],
    'VeilLinkTests/VoicePTTResilienceR11Tests.swift': [
        'testJitterBufferReordersFramesBeforePlayout', 'testRealtimePrioritySitsBetweenControlAndBulk'
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

info = (ROOT / 'VeilLink/Resources/Info.plist').read_text(encoding='utf-8')
for key, value in [('CFBundleShortVersionString','0.10.9'), ('CFBundleVersion','51')]:
    if not re.search(rf'<key>{key}</key>\s*<string>{re.escape(value)}</string>', info):
        raise SystemExit(f'FAIL plist {key}')
if 'NSMicrophoneUsageDescription' not in info:
    raise SystemExit('FAIL microphone usage description')

# R10 invariants that R11 must preserve.
session = (ROOT / 'VeilLink/Security/SessionCoordinator.swift').read_text(encoding='utf-8')
for needle in ['case .voice:', 'sendVoice(', 'case .pttControl', 'case .pttAudio', 'ptt-control', 'ptt-audio']:
    if needle not in session:
        raise SystemExit(f'FAIL R10 invariant: {needle}')
wire = (ROOT / 'VeilLink/Core/WireCodec.swift').read_text(encoding='utf-8')
for needle in ['case pttControl = 6', 'case pttAudio = 7']:
    if needle not in wire:
        raise SystemExit(f'FAIL R10 wire invariant: {needle}')

# Keep protocol v4; R11 changes queue scheduling, not envelope compatibility.
if 'static let version = 4' not in session:
    raise SystemExit('FAIL protocol version drift')

print('VEILLINK_R11_VOICE_PTT_RESILIENCE_PASS')
