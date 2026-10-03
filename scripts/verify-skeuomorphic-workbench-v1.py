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
    "LIVE AUDIO",
]:
    if needle not in tools:
        raise SystemExit(f"FAIL Tool Center skeuomorphic invariant missing {needle}")

tool_without_hardware_slider = tools.replace("VeilHardwareSlider(", "")
tool_without_veil_toggle = tools.replace("VeilToggleLever(", "")
if "Slider(" in tool_without_hardware_slider:
    raise SystemExit("FAIL Tool Center regressed to system Slider")
if "Toggle(" in tool_without_veil_toggle:
    raise SystemExit("FAIL Tool Center regressed to system Toggle")
if "VeilAmbientBackground()" in tools:
    raise SystemExit("FAIL Tool Center regressed to generic ambient background")

for needle in [
    "VeilHardwareSlider",
    "VeilInstrumentPlate",
    "FIRE SOLUTION",
    "ROUTE ADVISORY",
    "SHOT MODEL",
]:
    if needle not in arcade:
        raise SystemExit(f"FAIL arcade instrument invariant missing {needle}")

arcade_without_hardware_slider = arcade.replace("VeilHardwareSlider(", "")
if "Slider(" in arcade_without_hardware_slider:
    raise SystemExit("FAIL arcade controls regressed to system Slider")

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
