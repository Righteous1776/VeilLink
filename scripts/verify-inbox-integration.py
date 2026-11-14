#!/usr/bin/env python3
"""Fail the release if an accepted Inbox feature is missing from the exact Xcode source tree.

This is a source/packaging acceptance gate, NOT proof of two-device runtime behavior.
Proposals that have not been integrated must not be advertised as shipped.
"""
import argparse
import hashlib
import json
import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEATURES = {
    "chat-keyboard-and-local-bubble-order": {
        "VeilLink/UI/ConversationViews.swift": ["chatBottomAnchorID", "scrollToBottomRequest", "composerFocused"],
        "VeilLink/Storage/DatabaseStore.swift": ["ORDER BY m.rowid DESC"],
    },
    "unified-apple-files-inbox": {
        "VeilLink/Core/VeilFileInbox.swift": ["enum VeilFileInbox", "importStaged", "maximumFileBytes"],
        "VeilLink/Core/VeilUnifiedImportRouter.swift": ["enum VeilUnifiedImportRouter", "boardLearningGame"],
        "VeilLink/UI/VeilFileInboxView.swift": ["VeilFileInbox"],
    },
    "ble-adaptive-image-compression": {
        "VeilLink/Media/ImageTranscoder.swift": ["enum ImageTranscoder", "var smallest: PreparedImage?"],
        "VeilLink/Core/MediaTransferPolicy.swift": ["compressedLongestEdge"],
    },
    "ble-and-veilopoly-game-link-stability": {
        "VeilLink/Transport/BLETransport.swift": ["struct BLEQueueAdmissionPolicy", "struct BLEQueueProgressState"],
        "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyNet/RoomLinkPolicy.swift": ["shouldPauseGame", "shouldProbeGameSync"],
    },
    "game-lobby-gesture-and-scroll-repair": {
        "VeilLink/UI/GameLobbyView.swift": ["LazyVStack", "VeilStableScrollView"],
    },
    "forge-industrial-theme": {
        "VeilLink/Core/AppearanceTheme.swift": ["case forge", "static var switchableCases"],
        "VeilLink/UI/VeilForgeVisualSystem.swift": ["struct VeilForgeBackground", "struct VeilForgePlate"],
    },
    "flight-recorder-r5-structural-diagnostics": {
        "VeilLink/Diagnostics/DeepTelemetry.swift": ["rawTouchCaptureEnabled", "enum DeepTelemetryTouchPolicy"],
        "VeilLink/Diagnostics/RuntimeDiagnosticsBridge.swift": ["bubbleWindowSignatures", "nextBubbleToken"],
    },
    "ble-physical-vs-gatt-state-and-recovery": {
        "VeilLink/Transport/BLELinkSnapshot.swift": ["var hasPhysicalLink: Bool", "isWanted && !isConnected && !hasPhysicalLink"],
        "VeilLink/UI/NearbyView.swift": ["linkSnapshot.hasPhysicalLink"],
        "VeilLink/Transport/BLETransport.swift": ["蓝牙数据通道握手暂未就绪，原地重试发现与订阅", "peripheral.setNotifyValue(true, for: characteristic)"],
    },
    "veilopoly-advisory-status-probe": {
        "VeilLink/App/VeilopolyMultiplayerBridge.swift": ["nonCriticalProbeFailure", "remainingAreProbes"],
    },
    "particle-overlay-removal": {
        "VeilLink/App/VeilLinkApp.swift": [],
    },
}
NOT_SHIPPED = [
    "VeilScreen R1/R2.1 system-level BLE screen sharing",
    "ECLIPSE R17.2 mechanical cockpit",
]
NOT_PRESENT = [
    "VeilLink/UI/VeilAdaptiveParticleLayer.swift",
    "VeilLink/Core/VeilParticlePerformancePolicy.swift",
]


def error(message):
    raise SystemExit("INBOX INTEGRATION GATE FAIL: " + message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, help="Compiled Release-iphoneos/VeilLink.app")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    if 'MARKETING_VERSION: "29.2"' not in project or 'CURRENT_PROJECT_VERSION: "69"' not in project:
        error("Build 69 release source identity not present")
    if "path: VeilLink" not in project or "VeilLinkTests" not in project:
        error("expected iOS application/test targets are absent")
    for excluded in NOT_PRESENT:
        if (ROOT / excluded).exists():
            error("removed overlay unexpectedly present: " + excluded)
    hashes = {}
    for feature_id, source_map in FEATURES.items():
        hashes[feature_id] = {}
        for rel, needles in source_map.items():
            path = ROOT / rel
            if not path.is_file():
                error(f"{feature_id}: missing source file {rel}")
            data = path.read_bytes()
            txt = data.decode("utf-8")
            for needle in needles:
                if needle not in txt:
                    error(f"{feature_id}: missing integration marker {needle!r} in {rel}")
            hashes[feature_id][rel] = hashlib.sha256(data).hexdigest()
    receipt = {
        "schema": "VEILLINK_INBOX_SOURCE_GATE_V1",
        "release": "29.2",
        "build": "69",
        "source_gate": "PASS",
        "accepted_features": hashes,
        "excluded_unfinished_features": NOT_SHIPPED,
        "build_app_verified": False,
    }
    if args.app is not None:
        app = args.app
        if not app.is_dir():
            error("compiled iPhoneOS .app missing")
        info_path = app / "Info.plist"
        binary_path = app / "VeilLink"
        if not binary_path.is_file() or not info_path.is_file():
            error("compiled application executable/Info.plist missing")
        info = plistlib.loads(info_path.read_bytes())
        if (info.get("CFBundleShortVersionString"), str(info.get("CFBundleVersion"))) != ("29.2", "69"):
            error("built application identity does not match source")
        receipt["build_app_verified"] = True
        receipt["device_executable_sha256"] = hashlib.sha256(binary_path.read_bytes()).hexdigest()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("VEILLINK_INBOX_INTEGRATION_SOURCE_GATE_PASS", len(FEATURES), "accepted features")
    print("COMPILED_APP_CHECK", receipt["build_app_verified"])
    print("UNSHIPPED_FEATURES", ", ".join(NOT_SHIPPED))


if __name__ == "__main__":
    main()
