#!/usr/bin/env python3
"""Fail-closed source checks for the owner's V30 ECLIPSE conflict resolution.
Run locally before allowing the consolidated Xcode CI. Static markers do NOT
replace SwiftUI typechecking or two-device release acceptance.
"""
from pathlib import Path
root=Path(__file__).resolve().parent.parent
files={name:(root/name).read_text(encoding="utf-8") for name in (
    "VeilLink/UI/GameLobbyView.swift",
    "VeilLink/UI/MiniGameViews.swift",
    "VeilLink/UI/VeilEclipseComputeConsole.swift",
    "VeilLink/Agent/Games/LocalAIGameController.swift",
    "VeilLink/Agent/Games/VeilGomokuUnifiedBridge.swift",
)}
def require(ok, why):
    if not ok: raise SystemExit("V30 ECLIPSE OWNER REGRESSION FAIL: "+why)
g=files["VeilLink/UI/GameLobbyView.swift"]
b=files["VeilLink/UI/MiniGameViews.swift"]
c=files["VeilLink/UI/VeilEclipseComputeConsole.swift"]
engine=files["VeilLink/Agent/Games/LocalAIGameController.swift"]
bridge=files["VeilLink/Agent/Games/VeilGomokuUnifiedBridge.swift"]
native=(root/"VeilLink/Agent/Games/GomokuBot.swift").read_text(encoding="utf-8")
require("gomoku.thinking.strength.slider" in g, "real strength slider missing")
require("gomoku.thinking.no-time-limit.toggle" in g, "no-time-cutoff toggle missing")
require("VeilEclipseRuntimeInstruments(" not in g, "rejected lower measured instruments card returned")
for token in ("impactIndex", "impactScale", "impactExpanded"):
    require(token not in b, "rejected board impact ripple returned: "+token)
require("REAL CLOCK  T+" in c and "actualSearchStartedAt" in c,
        "elapsed clock is not bound to genuine search start")
require("TimelineView(.animation" not in c and "VeilEclipseConsoleStream.scrollPosition" not in c,
        "old 24Hz cosmetic code scrolling returned")
require("gomokuThinkingStrength" in engine and "gomokuUnlimitedThinking" in engine,
        "V29.2 Build69 real search budget settings regressed")
require("if budget.unlimitedThinking { limits.maxMilliseconds = 0 }" in bridge,
        "fixed search-time cap is back")
require("GomokuBotBudget.nativeContinuationBudget(" in native
        and "searchStrength: selected.searchStrength" in native
        and "unlimitedThinking: selected.unlimitedThinking" in native,
        "AI search budget silently discarded user's thinking slider or untimed option")
print("V30 ECLIPSE OWNER SOURCE REGRESSION PASS")
