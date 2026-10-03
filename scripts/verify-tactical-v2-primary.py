#!/usr/bin/env python3
from pathlib import Path

ROOT = Path.cwd()

def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        raise SystemExit(f"FAIL missing {rel}")
    return path.read_text(encoding="utf-8")

lobby = read("VeilLink/UI/GameLobbyView.swift")
solo = read("VeilLink/UI/TacticalV2/TacticalSoloV2View.swift")
shell = read("VeilLink/UI/TacticalV2/TacticalLandscapeShellV2.swift")
nearby = read("VeilLink/UI/MiniGameViews.swift")
runtime = read("VeilLink/Core/TacticalV2/TacticalSoloRuntimeV2.swift")

required_lobby = [
    "NavigationLink(destination: TacticalSoloV2View(model: model))",
    "48×27 大地图",
]
for needle in required_lobby:
    if needle not in lobby:
        raise SystemExit(f"FAIL Tactical V2 solo entry: {needle}")

if "NavigationLink(destination: LocalAIGameView(model: model, game: .tactical))" in lobby:
    raise SystemExit("FAIL legacy 7x9 TacticalBoardView restored as primary solo entry")

for needle in [
    "TacticalV2.ScenarioBundleV2.loadGuanduMap()",
    "TacticalLandscapeShellV2(",
    "TacticalV2.SoloRuntimeV2.resolveTurn",
]:
    if needle not in solo:
        raise SystemExit(f"FAIL TacticalSoloV2View missing {needle}")

for needle in [
    "TacticalV2LaunchGateView(",
    "legacyState:",
]:
    if needle not in nearby:
        raise SystemExit(f"FAIL nearby Tactical V2 compatibility gate missing {needle}")

for needle in [
    "VeilInstrumentPlate",
    "VeilLCDDisplay",
    "TacticalV2.TacticalOverlayV2",
]:
    if needle not in shell:
        raise SystemExit(f"FAIL Tactical V2 command table invariant missing {needle}")

for needle in [
    "RoutePlannerV2.plan",
    "WEGOResolverV2.resolve",
    "enemyCommand",
    "enemySupply",
]:
    if needle not in runtime:
        raise SystemExit(f"FAIL Tactical V2 solo runtime invariant missing {needle}")

print("VEILLINK_TACTICAL_V2_PRIMARY_PASS")
print("SOLO_PRIMARY=48x27")
print("LEGACY_7X9=fallback-only")
print("NEARBY_V2_GATE=preserved")
