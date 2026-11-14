from pathlib import Path
import re,sys
root=Path(__file__).resolve().parents[1]/'FILES/VeilLink'
ui=root/'UI'
lobby=(ui/'GameLobbyView.swift').read_text()
board=(ui/'MiniGameViews.swift').read_text()
identity=(ui/'VeilEclipseIdentityAndTrace.swift').read_text()
console=(ui/'VeilEclipseComputeConsole.swift').read_text()
ctrl=(root/'Agent/Games/LocalAIGameController.swift').read_text()
checks={
'original accent via VeilTheme.gold':'static var accent: Color { VeilTheme.gold }' in lobby,
'no new green/cyan/purple palette':all(not re.search(r'VeilEclipseChrome\.green|Color\.(?:green|cyan|purple)',s) for s in [lobby,board,identity,console]),
'dial uses actual search timestamp':'searchStartedAt: controller.eclipseSearchStartedAt' in lobby,
'dial has explicit non-progress disclosure':'不是搜索完成进度' in lobby,
'actual nodes and measured last decision time':'controller.lastDecisionNodes' in lobby and 'controller.lastDecisionMilliseconds' in lobby,
'last move node ceiling captured BEFORE await':ctrl.index('let measuredNodeCeiling: Int?') < ctrl.index('let selected = await self.selectAIMove()'),
'only measured result receives the same cap':'self.lastDecisionNodeCeiling = self.lastDecisionNodes == nil ? nil : measuredNodeCeiling' in ctrl,
'no fabricated node count during active thinking':'controller.lastDecisionNodes' in lobby and '暂无实时深度/节点数据' in console,
'board pulse opt-in, default off in multiplayer':'var eclipseMotionEnabled = false' in board and 'eclipseMotionEnabled: true' in lobby,
'board impact only when committed, no gestures':'let last = state.lastMove, state.value(at: last) != 0' in board and '.allowsHitTesting(false)' in board,
'reduced-motion stops board pulse':'guard eclipseMotionEnabled, !reduceMotion, last != nil' in board,
'avatar animates only while thinking and scene active':'if isThinking && !reduceMotion && scenePhase == .active' in identity,
'low power clock and console throttled':'isLowPowerModeEnabled' in console and 'isLowPowerModeEnabled' in lobby,
'no giant visual scroll swallows touches':'.allowsHitTesting(false)' in lobby and 'VeilBoardTapSurface(enabled: enabled)' in board,
'no new drag gesture in source':all('DragGesture' not in s for s in [lobby,identity,console]),
'R12 R13 toggles preserved':'gomoku.eclipse.r12.toggle' in lobby and 'gomoku.eclipse.r13.toggle' in lobby,
}
for name,ok in checks.items():
 print(('PASS' if ok else 'FAIL')+': '+name)
if not all(checks.values()):sys.exit(1)
print('ALL',len(checks),'MOTION/INTEGRITY CONTRACTS PASS')
