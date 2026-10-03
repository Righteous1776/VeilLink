#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path.cwd()

def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        raise SystemExit(f"FAIL missing {rel}")
    return path.read_text(encoding="utf-8")

workbench = read("VeilLink/Core/SkeuomorphicWorkbench.swift")
tools = read("VeilLink/UI/ToolCenterView.swift")
arcade = read("VeilLink/UI/ArcadeGameViews.swift")
lobby = read("VeilLink/UI/GameLobbyView.swift")
tactical = read("VeilLink/UI/TacticalV2/TacticalLandscapeShellV2.swift")

for needle in [
    "VeilInstrumentDeck",
    "VeilRecessedWell",
    "VeilHardwareSlider",
    "VeilToggleLever",
    "VeilInstrumentRackSection",
    "VeilInstrumentBay",
    "VeilStatusStrip",
    "VeilCompactKeyStyle",
    "veilInstrumentField",
]:
    if needle not in workbench:
        raise SystemExit(f"FAIL workbench primitive missing {needle}")

for needle in [
    "VeilInstrumentRackSection",
    "VeilPhysicalButtonStyle",
    "VeilHardwareSlider",
    "VeilToggleLever",
    "VeilInstrumentBackground",
    "VeilInstrumentBay",
    "VeilStatusStrip",
    "base64URLSafe",
    "jsonStructure",
    "VeilLocalToolEngine.hsl",
    "LIVE AUDIO",
]:
    if needle not in tools:
        raise SystemExit(f"FAIL Tool Center skeuomorphic invariant missing {needle}")

if re.search(r"(?<![A-Za-z0-9_])Slider\\s*\\(", tools):
    raise SystemExit("FAIL Tool Center regressed to system Slider")
if re.search(r"(?<![A-Za-z0-9_])Toggle\\s*\\(", tools):
    raise SystemExit("FAIL Tool Center regressed to system Toggle")
if "VeilAmbientBackground()" in tools:
    raise SystemExit("FAIL Tool Center regressed to generic ambient background")
if tools.count("VeilInstrumentBay(") < 10:
    raise SystemExit("FAIL Tool Center instrument-bay coverage regressed")
for needle in [
    "VeilLocalToolEngine.jsonStructure(input)",
    "VeilLocalToolEngine.base64URLEncodeUTF8",
    "VeilLocalToolEngine.base64URLDecodeUTF8",
    "VeilLocalToolEngine.hsl(rgb: preview)",
]:
    if needle not in tools:
        raise SystemExit(f"FAIL advanced Tool Center analysis missing {needle}")

for needle in [
    "VeilHardwareSlider",
    "VeilInstrumentPlate",
    "VeilInstrumentBay",
    "FIRE SOLUTION",
    "ROUTE ADVISORY",
    "SHOT MODEL",
    "W+\\(offset)",
    "S+\\(offset)",
    "FIELD +1",
    "FIELD +2",
]:
    if needle not in arcade:
        raise SystemExit(f"FAIL arcade instrument invariant missing {needle}")

if re.search(r"(?<![A-Za-z0-9_])Slider\\s*\\(", arcade):
    raise SystemExit("FAIL arcade controls regressed to system Slider")

if "VeilCompactKeyStyle(selected:" not in lobby:
    raise SystemExit("FAIL arcade difficulty selector regressed from hardware keys")

if "E2EE" not in lobby or "VeilInstrumentDeck" not in lobby:
    raise SystemExit("FAIL nearby game hub regressed from skeuomorphic E2EE console")

for needle in [
    "CONFIRMED",
    "VISIBLE AREA",
    "EXPLORED AREA",
    "VeilCompactKeyStyle(selected:",
]:
    if needle not in tactical:
        raise SystemExit(f"FAIL Tactical V2 instrumentation missing {needle}")

for rel, text in [
    ("VeilLink/UI/GameLobbyView.swift", lobby),
    ("VeilLink/UI/TacticalV2/TacticalLandscapeShellV2.swift", tactical),
]:
    if "VeilInstrumentPlate" not in text:
        raise SystemExit(f"FAIL {rel} missing physical instrument surface")

print("VEILLINK_SKEUOMORPHIC_WORKBENCH_PASS")
print("TOOL_SYSTEM_CONTROLS=forbidden")
print("ARCADE_SYSTEM_SLIDERS=forbidden")
print("LEGACY_DEVICE_DEGRADE=VeilMotionPolicy")
