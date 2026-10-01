#!/usr/bin/env python3
"""Fail closed if a future update drops the 26.9 base or the I12/A10 overlay."""

import hashlib
import json
import plistlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
EXPECTED_VERSION = "26.9"
EXPECTED_BUILD = "55"
MIN_TRACKED_FILES = 500
MIN_SWIFT_FILES = 180
MIN_TEST_FILES = 65

REQUIRED_FORMAL_BASE = [
    "VeilLink/Voice/WalkieTalkieAudioController.swift",
    "VeilLink/Transport/LANTransport.swift",
    "VeilLink/Pairing/RemotePairingCore.swift",
    "VeilLink/UI/ToolCenterView.swift",
    "VeilLink/Background/VeilBackgroundActivityAttributes.swift",
    "VeilBackgroundWidget/Info.plist",
    "VeilLink/Legal/VeilLegalConsentController.swift",
    "VeilLink/Onboarding/VeilFirstRunOnboardingController.swift",
    "VeilLink/Relay/VeilRelayCore.swift",
    "VeilLink/Community/VeilMeshOverlay.swift",
]

REQUIRED_I12_OVERLAY = [
    "VeilLink/Agent/Compute/A10UltraComputeCore.swift",
    "VeilLink/Agent/Compute/A10UltraM5Runtime.swift",
    "VeilLink/Agent/Integration/A10UltraM5GovernanceAdvisor.swift",
    "VeilLink/Agent/Integration/A10UltraM5ShadowCognition.swift",
    "VeilLink/Diagnostics/CollaborativeStressCoordinator.swift",
    "VeilLink/Diagnostics/CollaborativeStressProtocol.swift",
    "VeilLink/Health/VeilKernelRuntimeSelector.swift",
    "VeilLink/Health/VeilLatticeKernelBridge.swift",
    "VeilLink/Native/A10UltraM5Native.c",
    "VeilLink/Native/A10UltraM5Native.h",
    "VeilLinkTests/A10UltraM5IntegrationTests.swift",
    "VeilLinkTests/ThreeCoreIntegrationTests.swift",
]

A10_M5_HASHES = {
    "ios_integration_manifest.json": "b48c86cf4fc8df3a78ed88f6afc69ee6ecf622663bbb361bace3ead9206cc6f5",
    "language_weights.bin": "3228384ef72a809e5725a54f4288ba0457288cb695338966eb679b82221e3e26",
    "model.json": "54a779895b09a74e5996dec0dad5d47dee4750b596754bb440cb01801f05cdb2",
    "runtime_predictor_model.json": "3b43cf41855831b2c4c059542a319907a2bd3ccd7300364cb567b85010f55b0c",
    "runtime_predictor_weights.bin": "74b1f91cb90c95823c882c284f4c369f3f815f90e8d6e87e06d5038a84684204",
    "sqlite_predictor_model.json": "cec8ab11b175151318b4bffcd2ded29aa3b70bacefdd68417e80d0bdb3b0170d",
    "sqlite_predictor_weights.bin": "549026ee043e99d11cc4e8110ac6167a084a166978761e98f6c6047929e4afb4",
    "vocab.json": "fbf7edf8ffe3e1ed5d7e79baa5b118b8fc38ed646dbb684f0615349d611dec50",
}


def fail(message):
    raise SystemExit("RECOVERY LINEAGE FAIL: " + message)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_inventory():
    for relative in REQUIRED_FORMAL_BASE + REQUIRED_I12_OVERLAY:
        if not (ROOT / relative).is_file():
            fail(f"required cumulative source missing: {relative}")

    tracked = [p for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts]
    swift = list((ROOT / "VeilLink").rglob("*.swift"))
    tests = list((ROOT / "VeilLinkTests").rglob("*.swift"))
    if len(tracked) < MIN_TRACKED_FILES:
        fail(f"source tree unexpectedly small: {len(tracked)} files")
    if len(swift) < MIN_SWIFT_FILES:
        fail(f"Swift source tree unexpectedly small: {len(swift)} files")
    if len(tests) < MIN_TEST_FILES:
        fail(f"test tree unexpectedly small: {len(tests)} files")


def check_identity():
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    if f'MARKETING_VERSION: "{EXPECTED_VERSION}"' not in project:
        fail("project.yml no longer declares VeilLink 26.9")
    if f'CURRENT_PROJECT_VERSION: "{EXPECTED_BUILD}"' not in project:
        fail(f"project.yml no longer declares recovery build {EXPECTED_BUILD}")

    with (ROOT / "VeilLink/Resources/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    if info.get("CFBundleShortVersionString") != "$(MARKETING_VERSION)":
        fail("Info.plist hardcodes a marketing version")
    if info.get("CFBundleVersion") != "$(CURRENT_PROJECT_VERSION)":
        fail("Info.plist hardcodes a build number")


def check_a10_m5():
    resources = ROOT / "VeilLink/Resources/A10UltraM5"
    for name, expected in A10_M5_HASHES.items():
        path = resources / name
        if not path.is_file():
            fail(f"A10 Ultra M5 resource missing: {name}")
        if sha256(path) != expected:
            fail(f"A10 Ultra M5 resource SHA mismatch: {name}")

    manifest = json.loads((resources / "ios_integration_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("source_model_hash") != "c5ba826dab1ebe1db02e90e8b4bfd2c060e99586413970fa3bd4d848e378a8b4":
        fail("A10 Ultra M5 source model provenance mismatch")
    if manifest.get("state") != "TRAINED_COGNITION_SHADOW":
        fail("A10 Ultra M5 must remain in trained shadow state")
    if manifest.get("production_cutover") != "DENY":
        fail("A10 Ultra M5 production cutover guard changed")

    for forbidden in ("weights.npz", "brain.npz", "MaleCNSReference.vfly"):
        if list((ROOT / "VeilLink").rglob(forbidden)):
            fail(f"raw/heavy training resource entered app source: {forbidden}")


def main():
    check_inventory()
    check_identity()
    check_a10_m5()
    print("VEILLINK_RECOVERY_LINEAGE_PASS")
    print(f"RECOVERY_IDENTITY={EXPECTED_VERSION}({EXPECTED_BUILD})")
    print(f"SWIFT_SOURCE_COUNT={len(list((ROOT / 'VeilLink').rglob('*.swift')))}")
    print(f"TEST_SOURCE_COUNT={len(list((ROOT / 'VeilLinkTests').rglob('*.swift')))}")


if __name__ == "__main__":
    main()
