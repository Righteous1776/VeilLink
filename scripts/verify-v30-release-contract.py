#!/usr/bin/env python3
"""V30 **fail-closed** source preflight (not a substitute for iOS/device tests).

Usage: python3 scripts/verify-v30-release-contract.py [--app PATH] [--enforce] [--json PATH]
Without --enforce: collect blockers for early review. With --enforce: blockers exit nonzero.
Keep this gate outside product CI until the full V30 integration batch is ready.
"""
import argparse
import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEATURES = {
    "release_identity": {"project.yml": ['MARKETING_VERSION: "30.0"', 'CURRENT_PROJECT_VERSION: "70"']},
    "gomoku_thinking": {
        "VeilLink/UI/GameLobbyView.swift": ["gomoku.thinking.strength.slider", "gomoku.thinking.no-time-limit.toggle"],
        "VeilLink/Agent/Games/LocalAIGameController.swift": ["gomokuThinkingStrength", "gomokuUnlimitedThinking", "withTaskCancellationHandler"],
        "VeilLink/Agent/Games/VeilGomokuUnifiedBridge.swift": ["func searchLimits", "maxMilliseconds = 0"],
    },
    "forge_soft": {
        "VeilLink/UI/VeilForgeVisualSystem.swift": ["struct VeilForgePlate", "VeilInstrumentBackground", "struct VeilForgeRotor"],
        "VeilLink/Core/AppearanceTheme.swift": ["static let forgeNight", "static let forgeDay"],
        "VeilLinkTests/VeilForgeSoftThemeTests.swift": ["testSoftCardGeometryAndThemeIdentity"],
    },
    "chat_and_files": {
        "VeilLink/UI/ConversationViews.swift": ["chatBottomAnchorID"],
        "VeilLink/Storage/DatabaseStore.swift": ["ORDER BY m.rowid DESC"],
        "VeilLink/Core/VeilFileInbox.swift": ["enum VeilFileInbox"],
        "VeilLink/Media/ImageTranscoder.swift": ["enum ImageTranscoder"],
    },
    "blackbox": {
        "VeilLink/Diagnostics/DeepTelemetry.swift": ["rawTouchCaptureEnabled"],
        "VeilLink/Diagnostics/RuntimeDiagnosticsBridge.swift": ["bubbleWindowSignatures"],
    },
    # MUST be integrated product files, never AGENT_INBOX/FILES.
    "screen_share": {
        "VeilLink/ScreenShare/VeilScreenShareWire.swift": ["VeilScreenShareChunk", "maximumFrameBytes"],
        "VeilLink/ScreenShare/VeilScreenSessionWorkflow.swift": ["VeilScreenSessionWorkflow"],
        "VeilLink/ScreenShare/VeilScreenBridgeController.swift": ["class VeilScreenBridgeController", "captureRevoked", "supportsAuthenticatedBLEScreenShare", "prepareCapture", "snapshot != current"],
        "VeilLink/UI/VeilScreenChatAttachment.swift": ["VeilScreenInviteCard", "VeilScreenViewerView", "VeilScreenReplayKitConsentView"],
        "VeilLink/ScreenShare/VeilScreenLegacyBroadcastHost.swift": ["VeilScreen"],
        "VeilLink/ScreenShare/VeilScreenLegacyMailboxPump.swift": ["VeilScreen"],
        "VeilLink/ScreenShare/VeilScreenBroadcastSecurity.swift": ["VeilScreen"],
        "VeilLink/ScreenShare/VeilScreenEncryptedMailbox.swift": ["VeilScreen"],
        "VeilLink/ScreenShare/VeilScreenReplayKitEncoder.swift": ["VeilScreen"],
        "VeilLink/ScreenShare/VeilScreenReplayKitConsentView.swift": ["VeilScreen"],
        "VeilLink/ScreenShare/Broadcast/VeilScreenBroadcastUploadHandler.swift": ["RPBroadcastSampleHandler"],
        "VeilLink/Resources/VeilScreenBroadcastUpload-Info.plist": ["com.apple.broadcast-services-upload"],
        "VeilLink/UI/VeilScreenShareViews.swift": ["VeilScreenViewerView"],
        "VeilLink/UI/ConversationViews.swift": ["邀请屏幕共享"],
        "VeilLink/Core/WireCodec.swift": ["screenControl", "screenMedia"],
        "VeilLink/Security/SessionCoordinator.swift": ["screen-control", "screen-media"],
        "VeilLink/App/AppModel.swift": ["screenShare", "onScreenShareControl", "onScreenShareChunk"],
        "VeilLinkTests/VeilScreenTransportIntegrationTests.swift": ["testSignedScreenShareCapabilityAndLegacyPeer", "testManipulationFailsClosed", "testTypedScreenChannelsRemainDistinctFromChat"],
        "VeilLink/Resources/VeilScreen.entitlements": ["com.apple.security.application-groups", "keychain-access-groups"],
        "project.yml": ["VeilScreenBroadcastUpload", "VeilScreenBroadcastUploadHandler.swift", "CODE_SIGN_ENTITLEMENTS", "embed: true"],
    },
}
def run(app=None):
    results = {}
    for key, sources in FEATURES.items():
        missing = []
        for path, needles in sources.items():
            file = ROOT / path
            if not file.is_file():
                missing.append(f"{path}: absent")
                continue
            content = file.read_text(encoding="utf-8", errors="replace")
            for needle in needles:
                if needle not in content:
                    missing.append(f"{path}: missing {needle}")
        results[key] = {"status": "BLOCKED" if missing else "SOURCE_MARKERS_PRESENT", "missing": missing}
    result = {"schema": "VEILLINK_V30_ACCEPTANCE_V1", "source_only": True,
              "false_positive_warning": "source markers are insufficient to claim functionality",
              "features": results, "compiled_app_checked": False,
              "compiled_ipa_checked": False, "signed_device_tested": False}
    if app is not None:
        path = Path(app)
        info = path / "Info.plist"
        ext = path / "PlugIns" / "VeilScreenBroadcastUpload.appex"
        failures = []
        if not info.is_file():
            failures.append("Host Info.plist absent")
        else:
            data = plistlib.loads(info.read_bytes())
            if (str(data.get("CFBundleShortVersionString")), str(data.get("CFBundleVersion"))) != ("30.0", "70"):
                failures.append("Wrong V30.0 Build70 compiled identity")
        if not ext.is_dir():
            failures.append("ReplayKit Broadcast Upload .appex missing from built .app")
        else:
            extension_binary = ext / "VeilScreenBroadcastUpload"
            extension_info = ext / "Info.plist"
            if not extension_binary.is_file() or extension_binary.stat().st_size <= 0:
                failures.append("ReplayKit upload extension executable missing or empty")
            if not extension_info.is_file():
                failures.append("ReplayKit extension Info.plist missing")
            else:
                data = plistlib.loads(extension_info.read_bytes())
                if data.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.broadcast-services-upload":
                    failures.append("Wrong broadcast upload extension point")
                if data.get("CFBundleIdentifier") != "studio.zeo.veillink.screenshare":
                    failures.append("Wrong ReplayKit extension bundle ID")
                if (str(data.get("CFBundleShortVersionString")), str(data.get("CFBundleVersion"))) != ("30.0", "70"):
                    failures.append("Wrong ReplayKit extension release identity")
        result["compiled_app_checked"] = True
        result["compiled_app"] = {"status": "BLOCKED" if failures else "EXTENSION_PRESENT_NOT_DEVICE_VERIFIED",
                                  "failures": failures}
    return result

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", type=Path)
    ap.add_argument("--json", type=Path)
    ap.add_argument("--enforce", action="store_true")
    args = ap.parse_args()
    result = run(args.app)
    blockers = [k for k, v in result["features"].items() if v["status"] == "BLOCKED"]
    if args.app is not None and result["compiled_app"]["status"] == "BLOCKED":
        blockers.append("compiled_app")
    result["blockers"] = blockers
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if args.enforce and blockers:
        raise SystemExit(f"V30 STOP SHIP: {len(blockers)} static blockers")
if __name__ == "__main__":
    main()
