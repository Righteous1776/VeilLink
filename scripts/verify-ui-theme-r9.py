#!/usr/bin/env python3
from pathlib import Path
root = Path.cwd()
checks = {
    'VeilLink/Core/AppearanceTheme.swift': ['veilOriginal', 'instrumentAuto', 'instrumentDay', 'instrumentNight'],
    'VeilLink/Core/SkeuomorphicComponents.swift': ['VeilPhysicalButtonStyle', 'VeilLCDDisplay', 'VeilSpeakerGrille', 'VeilInstrumentKnob'],
    'VeilLink/UI/ToolCenterView.swift': ['VeilToolCenterView', 'VeilWalkieTalkieView', 'PTT'],
    'VeilLink/UI/ConversationViews.swift': ['VeilToolCenterView(model: model)', '打开工具中心'],
    'VeilLink/UI/SettingsView.swift': ['appearanceCard', 'VeilAppearanceSelection.allCases'],
    'VeilLink/Core/AppTheme.swift': ['VeilThemePalette', 'VeilInstrumentBackground', 'VeilAppearanceController.shared.isInstrument'],
}
for rel, needles in checks.items():
    path = root / rel
    if not path.is_file():
        raise SystemExit(f'FAIL missing {rel}')
    text = path.read_text(encoding='utf-8')
    for needle in needles:
        if needle not in text:
            raise SystemExit(f'FAIL {rel}: missing {needle}')
info = (root / 'VeilLink/Resources/Info.plist').read_text(encoding='utf-8')
if '<string>$(MARKETING_VERSION)</string>' not in info or '<string>$(CURRENT_PROJECT_VERSION)</string>' not in info:
    raise SystemExit('FAIL release identity placeholders')
project = (root / 'project.yml').read_text(encoding='utf-8')
if 'MARKETING_VERSION: "26.9"' not in project or 'CURRENT_PROJECT_VERSION: "53"' not in project:
    raise SystemExit('FAIL formal release identity')
if not (root / 'docs/history/ui/V0106_R8_ORIGINAL_THEME/manifest.sha256').is_file():
    raise SystemExit('FAIL history manifest')
print('VEILLINK_UI_THEME_R9_PASS')
