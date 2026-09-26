#!/usr/bin/env python3
from pathlib import Path
import re, sys
ROOT=Path.cwd()
checks={
 'VeilLink/Voice/VoiceMessageCodec.swift':['VLVOICE1:','maximumDurationSeconds'],
 'VeilLink/Voice/VoiceMessageAudioController.swift':['AVAudioRecorder','kAudioFormatMPEG4AAC'],
 'VeilLink/Voice/PTTWire.swift':['VeilMuLaw','encodeAudio','decodeAudio'],
 'VeilLink/Voice/WalkieTalkieAudioController.swift':['frameBytes = 320','8_000','beginTransmit'],
 'VeilLink/UI/ToolCenterView.swift':['LIVE AUDIO','VeilWalkieTalkieView','开放给附近已信任设备'],
 'VeilLink/Security/SessionCoordinator.swift':['case .pttControl','sendVoice(','sendPTTAudioFrame','case .voice:'],
 'VeilLink/UI/ConversationViews.swift':['VeilHoldToTalkComposer','sendVoice(_ recording:','VeilVoiceMessageBubble'],
 'VeilLink/Core/WireCodec.swift':['case pttControl = 6','case pttAudio = 7'],
}
for rel, needles in checks.items():
 p=ROOT/rel
 if not p.is_file(): raise SystemExit(f'FAIL missing {rel}')
 s=p.read_text(encoding='utf-8')
 for n in needles:
  if n not in s: raise SystemExit(f'FAIL {rel}: {n}')
info=(ROOT/'VeilLink/Resources/Info.plist').read_text(encoding='utf-8')
for key,value in [('CFBundleShortVersionString','$(MARKETING_VERSION)'),('CFBundleVersion','$(CURRENT_PROJECT_VERSION)')]:
 if not re.search(rf'<key>{key}</key>\s*<string>{re.escape(value)}</string>',info): raise SystemExit(f'FAIL plist {key}')
project=(ROOT/'project.yml').read_text(encoding='utf-8')
if 'MARKETING_VERSION: "26.9"' not in project or 'CURRENT_PROJECT_VERSION: "53"' not in project:
    raise SystemExit('FAIL VeilLink 26.9 / Build 53 project identity')
if 'NSMicrophoneUsageDescription' not in info: raise SystemExit('FAIL microphone usage description')
# The live PTT path must remain trust-gated in SessionCoordinator.
s=(ROOT/'VeilLink/Security/SessionCoordinator.swift').read_text(encoding='utf-8')
if 'database.trustedContact' not in s or 'ptt-audio' not in s: raise SystemExit('FAIL PTT trust/encryption gate')
print('VEILLINK_R10_VOICE_PTT_PASS')
