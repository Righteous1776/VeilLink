#!/usr/bin/env python3
import hashlib
import json
import os
import plistlib
from pathlib import Path
import py_compile
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "VeilLink" / "Resources"
APPICON = RES / "Assets.xcassets" / "AppIcon.appiconset"

EXPECTED_VFLY = {
    "VeilFlyCore.vfly": {
        "sha256": "cc8b71d824ecb7f20c821412b316262ecb4dd1faee148077c94825b5889d60de",
        "bytes": 45360268,
    },
    "VeilFlyLite.vfly": {
        "sha256": "25b4947ec6c2a33502879d92269299120b708e86110157a538f792e327b7abee",
        "bytes": 9517364,
    },
}

def fail(message):
    print("PREFLIGHT FAIL:", message, file=sys.stderr)
    raise SystemExit(1)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def run(args, *, cwd=ROOT):
    print("+", " ".join(map(str, args)))
    subprocess.run(args, cwd=cwd, check=True)

def png_info(path):
    data = path.read_bytes()[:33]
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path} is not a PNG")
    if data[12:16] != b"IHDR":
        fail(f"{path} missing IHDR")
    width, height = struct.unpack(">II", data[16:24])
    bit_depth = data[24]
    color_type = data[25]
    return width, height, bit_depth, color_type

def expected_pixels(size_text, scale_text):
    size = float(size_text.split("x")[0])
    scale = int(scale_text[:-1])
    return int(round(size * scale))

def check_plist():
    info = RES / "Info.plist"
    with info.open("rb") as f:
        plist = plistlib.load(f)
    if plist.get("CFBundleShortVersionString") != "$(MARKETING_VERSION)":
        fail("app Info.plist must inherit MARKETING_VERSION from project.yml")
    if plist.get("CFBundleVersion") != "$(CURRENT_PROJECT_VERSION)":
        fail("app Info.plist must inherit CURRENT_PROJECT_VERSION from project.yml")
    widget_info = ROOT / "VeilBackgroundWidget" / "Info.plist"
    with widget_info.open("rb") as f:
        widget = plistlib.load(f)
    if widget.get("CFBundleShortVersionString") != "$(MARKETING_VERSION)" or widget.get("CFBundleVersion") != "$(CURRENT_PROJECT_VERSION)":
        fail("widget release identity must inherit the app build settings")
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    if 'MARKETING_VERSION: "26.9"' not in project or 'CURRENT_PROJECT_VERSION: "53"' not in project:
        fail("VeilLink 26.9 / Build 53 release identity missing from project.yml")
    modes = set(plist.get("UIBackgroundModes", []))
    if not {"bluetooth-central", "bluetooth-peripheral"} <= modes:
        fail("Bluetooth background modes missing")
    print("Info.plist: PASS")

def check_appicon():
    contents = json.loads((APPICON / "Contents.json").read_text(encoding="utf-8"))
    images = contents.get("images", [])
    if len(images) != 18:
        fail(f"expected 18 AppIcon entries, got {len(images)}")
    seen = set()
    for item in images:
        filename = item.get("filename")
        if not filename:
            fail("AppIcon entry missing filename")
        path = APPICON / filename
        if not path.is_file():
            fail(f"missing AppIcon file: {filename}")
        px = expected_pixels(item["size"], item["scale"])
        width, height, bit_depth, color_type = png_info(path)
        if (width, height) != (px, px):
            fail(f"{filename}: expected {px}x{px}, got {width}x{height}")
        if bit_depth != 8:
            fail(f"{filename}: expected 8-bit PNG")
        if color_type not in (0, 2, 3):
            fail(f"{filename}: alpha channel is not allowed for AppIcon (color type {color_type})")
        seen.add(filename)
    if len(seen) != 18:
        fail("duplicate AppIcon filenames")
    print("AppIcon: PASS")

def check_vfly():
    for filename, expected in EXPECTED_VFLY.items():
        path = RES / filename
        if not path.is_file():
            fail(f"missing {filename}")
        if path.stat().st_size != expected["bytes"]:
            fail(f"{filename}: byte count mismatch")
        actual = sha256(path)
        if actual != expected["sha256"]:
            fail(f"{filename}: SHA256 mismatch")
    verify = json.loads((RES / "VFLYInstallationVerification.json").read_text(encoding="utf-8"))
    if verify.get("result") != "PASS":
        fail("VFLYInstallationVerification result is not PASS")
    if (RES / "MaleCNSReference.vfly").exists():
        fail("MaleCNSReference.vfly must not be bundled in app resources")
    print("VFLY assets: PASS")

def check_malecns_manifests():
    lite = json.loads((RES / "MaleCNSGameRankerLiteV1.manifest.json").read_text(encoding="utf-8"))
    core = json.loads((RES / "MaleCNSGameRankerCoreV1.manifest.json").read_text(encoding="utf-8"))
    if lite.get("deployment_eligible") is not True:
        fail("Lite ranker must be deployment_eligible")
    if core.get("deployment_eligible") is not False:
        fail("Core ranker must remain guarded/experimental")
    if lite.get("graph_sha256") != EXPECTED_VFLY["VeilFlyLite.vfly"]["sha256"]:
        fail("Lite ranker graph SHA mismatch")
    if core.get("graph_sha256") != EXPECTED_VFLY["VeilFlyCore.vfly"]["sha256"]:
        fail("Core ranker graph SHA mismatch")
    run([
        sys.executable,
        str(ROOT / "scripts" / "verify-malecns-ranker-assets.py"),
        "--resources",
        str(RES),
    ])
    print("MaleCNS manifests: PASS")

def check_core_project_exclusions():
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    required = [
        "Resources/VeilFlyCore.vfly",
        "Resources/VeilFlyLite.vfly",
        "Resources/AgentModels/game_policy_ranker_v4.vlpol",
        "Resources/MaleCNSGameRankerCoreV1.json",
        "Resources/MaleCNSGameRankerLiteV1.json",
    ]
    missing = [item for item in required if item not in project]
    if missing:
        fail("Core project does not exclude heavy resources: " + ", ".join(missing))
    print("Core project exclusions: PASS")

def check_repo_hygiene():
    tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
    bad = [p for p in tracked if "/__pycache__/" in p or p.endswith(".pyc")]
    if bad:
        fail("tracked Python cache files: " + ", ".join(bad))
    if (RES / "Qwen3-0.6B-Q4_0.gguf").exists():
        fail("Qwen GGUF must not be tracked/bundled in standard source tree")
    if (ROOT / "project.local-ai.yml").exists():
        fail("project.local-ai.yml must be generated by the heavy preparation step")
    print("Repository hygiene: PASS")

def check_json():
    for path in sorted(RES.glob("*.json")):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            fail(f"invalid JSON {path}: {exc}")
    print("Resource JSON: PASS")
    run([
        sys.executable,
        str(ROOT / "scripts" / "verify-tactical-v2-assets.py"),
        "--repo-root",
        str(ROOT),
    ])

def check_script_syntax():
    required = [
        ROOT / "scripts" / "verify-core-release.py",
        ROOT / "scripts" / "verify-core-source-isolation.py",
        ROOT / "scripts" / "verify-local-control-plane.py",
        ROOT / "scripts" / "verify-control-plane-v2.py",
        ROOT / "scripts" / "verify-autoregulation-r7.py",
        ROOT / "scripts" / "verify-maintenance-r8.py",
        ROOT / "scripts" / "verify-ui-theme-r9.py",
        ROOT / "scripts" / "maintenance-health-report.py",
        ROOT / "scripts" / "upgrade-transaction.py",
        ROOT / "scripts" / "package-unsigned-ipa.sh",
    ]
    for required_path in required:
        if not required_path.is_file():
            fail(f"missing release tooling: {required_path}")
    for path in sorted((ROOT / "scripts").glob("*.py")):
        py_compile.compile(str(path), doraise=True)
    for path in sorted((ROOT / "scripts").glob("*.sh")):
        run(["bash", "-n", str(path)])
    print("Python/Shell syntax: PASS")

def check_swift_syntax():
    swift_files = sorted((ROOT / "VeilLink").rglob("*.swift")) + sorted((ROOT / "VeilLinkTests").rglob("*.swift"))
    if len(swift_files) < 80:
        fail(f"unexpectedly small Swift file set: {len(swift_files)}")
    for path in swift_files:
        run(["xcrun", "swiftc", "-frontend", "-parse", str(path)])
    print(f"Swift parse: PASS ({len(swift_files)} files)")

def check_tests():
    tests = sorted((ROOT / "VeilLinkTests").glob("*.swift"))
    if len(tests) < 40:
        fail(f"expected at least 40 test source files, got {len(tests)}")
    required = {
        "AgentNavigationTests.swift",
        "AgentIntegrationTests.swift",
        "MiniGameTests.swift",
        "DatabaseStoreTests.swift",
        "CryptoEngineTests.swift",
        "RealLocalInferenceSmokeTests.swift",
        "AgentControlAndLocalGameTests.swift",
        "AgentGameExecutionValidationTests.swift",
        "A9RuntimeConstraintTests.swift",
        "TacticalV2Tests.swift",
        "XiangqiBotTests.swift",
        "GomokuBotTests.swift",
        "LudoBotTests.swift",
        "VeilTalkLiteRuntimeTests.swift",
        "NativeGameBrokerTests.swift",
        "CoreSourceIsolationTests.swift",
        "VeilAppControlPlaneTests.swift",
        "VeilAppControlPlaneV2Tests.swift",
        "VeilAppControlPlaneV3Tests.swift",
        "VeilAutoRegulationTests.swift",
        "VeilMaintenanceInvariantTests.swift",
        "VeilAppearanceThemeTests.swift",
        "VoiceAndPTTTests.swift",
    }
    missing = sorted(required - {p.name for p in tests})
    if missing:
        fail("missing required tests: " + ", ".join(missing))
    print(f"Test inventory: PASS ({len(tests)} files)")

def main():
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-core-source-isolation.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-local-control-plane.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-control-plane-v2.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-autoregulation-r7.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-maintenance-r8.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-ui-theme-r9.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-voice-ptt-r10.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts" / "verify-runtime-maintenance-r12.py")], cwd=ROOT)
    check_repo_hygiene()
    check_plist()
    check_appicon()
    check_core_project_exclusions()
    check_json()
    check_tests()
    check_script_syntax()
    check_swift_syntax()
    print("VEILLINK_STANDARD_PREFLIGHT_PASS")

if __name__ == "__main__":
    main()
