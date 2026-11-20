#!/usr/bin/env python3
"""V30 offline SOURCE preflight. Never calls GitHub or publishes a release."""
import argparse
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def check_manifest():
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    def has(setting, value):
        return bool(re.search(r"^\s*" + re.escape(setting) +
            r":\s*['\"]?" + re.escape(value) + r"['\"]?\s*$", project, re.M))
    assert has("MARKETING_VERSION", "30.0"), "V30.0 version absent"
    assert has("CURRENT_PROJECT_VERSION", "70"), "Build 70 absent"
    with (ROOT / "VeilLink/Resources/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    assert info.get("CFBundleShortVersionString") == "$(MARKETING_VERSION)"
    assert info.get("CFBundleVersion") == "$(CURRENT_PROJECT_VERSION)"
    workflow = (ROOT / ".github/workflows/ios-ci.yml").read_text()
    assert "xcodebuild" in workflow and "verify-v30-release-contract.py" in workflow
    assert "VeilScreenBroadcastUpload" in project
    assert "ScreenShare/Broadcast/VeilScreenBroadcastUploadHandler.swift" in project
    with (ROOT / "VeilLink/Resources/VeilScreenBroadcastUpload-Info.plist").open("rb") as stream:
        extension = plistlib.load(stream)
    assert extension.get("CFBundleIdentifier") == "$(PRODUCT_BUNDLE_IDENTIFIER)", (
        "ReplayKit CFBundleIdentifier missing: Xcode embedded binary validation would fail"
    )
    assert extension.get("CFBundleExecutable") == "$(EXECUTABLE_NAME)"
    assert extension.get("NSExtension", {}).get("NSExtensionPointIdentifier") == "com.apple.broadcast-services-upload"
    print("PASS: V30 identity, ReplayKit bundle metadata and unified CI manifest")

def check_python():
    paths = sorted((ROOT / "scripts").glob("*.py"))
    for path in paths:
        compile(path.read_text(encoding="utf-8"), str(path), "exec")
    print("PASS: Python syntax in", len(paths), "scripts")

def check_swift():
    swiftc = shutil.which("swiftc")
    if not swiftc:
        raise RuntimeError("swiftc unavailable; cannot claim source parse passed")
    roots = ("VeilLink", "VeilLinkTests", "VeilLinkUITests", "VeilBackgroundWidget")
    paths = sorted(file for name in roots for file in (ROOT/name).rglob("*.swift"))
    assert paths, "no Swift files"
    failures = []
    for file in paths:
        process = subprocess.run([swiftc, "-frontend", "-parse", str(file)],
            capture_output=True, text=True, timeout=55)
        if process.returncode:
            failures.append((str(file.relative_to(ROOT)), process.stderr[-900:]))
    if failures:
        for file, detail in failures[:15]:
            print("FAILED SWIFT PARSE:", file, detail, file=sys.stderr)
        raise RuntimeError(str(len(failures)) + " Swift parsing failures")
    print("PASS: parsed", len(paths), "Swift source files (NOT Xcode typecheck)")

def invoke(path, *args):
    process = subprocess.run([sys.executable, str(ROOT/"scripts"/path), *args],
        cwd=ROOT, check=False)
    if process.returncode:
        raise RuntimeError(path + " failed (exit " + str(process.returncode) + ")")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-source", action="store_true",
        help="enforce all V30 source markers; still NOT a signed IPA receipt")
    args = parser.parse_args()
    check_manifest()
    check_python()
    check_swift()
    for script in (
        "verify-v30-eclipse-owner-regressions.py",
        "verify-maintenance-r8.py",
        "verify-runtime-maintenance-r12.py",
        "verify-ui-theme-r9.py",
        "verify-voice-ptt-r10.py",
        "verify-inbox-integration.py",
    ):
        invoke(script)
    enforce = ("--enforce",) if args.release_source else ()
    invoke("verify-v30-release-contract.py", *enforce)
    print("V30 SOURCE-ONLY PREFLIGHT PASS")
    print("No Xcode typecheck, signed ReplayKit, dual-device BLE or published IPA"
          " is implied. No GitHub Actions were started by this script.")

if __name__ == "__main__":
    try:
        main()
    except (AssertionError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print("V30 SOURCE PREFLIGHT BLOCKED:", error, file=sys.stderr)
        raise SystemExit(2)
