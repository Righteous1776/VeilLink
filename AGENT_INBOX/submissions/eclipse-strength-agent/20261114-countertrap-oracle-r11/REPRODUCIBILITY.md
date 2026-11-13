# Local reproducibility

Archive: VeilLink_ECLIPSE_R11_CounterTrap_20261114.zip; sha256 5e5548e272b484d8739556b8fca75849a61998c04f39e011010b82f76a18a2a4 (not stored in Git because binary archives forbidden). The current Github Inbox contains the two exact new Swift sources and the four native XCTest fixtures; owner ZIP adds pinned R10 source, budget contract, full self-contained test runners and the integrated advisory add-file patch.

Command from extracted package root:

```sh
swiftc -O -swift-version 6 -warnings-as-errors FILES/VeilEclipseStrategicPlannerR10.swift FILES/VeilEclipseTacticalOracleR11.swift FILES/VeilEclipseR11DecisionBridge.swift FILES/TESTS/main.swift -o /tmp/ecl-r11-check
/tmp/ecl-r11-check
swiftc -O -swift-version 6 -warnings-as-errors FILES/VeilEclipseStrategicPlannerR10.swift FILES/VeilEclipseTacticalOracleR11.swift FILES/TESTS/arena/main.swift -o /tmp/ecl-r11-compare
/tmp/ecl-r11-compare
```

Observed output: `R11 PASS assertions=209 seededAuditPositions=80 scannedFiveCellWindows=979981`; `R11_FIXED_TACTICAL_CORPUS positions=24 baselineUnsafe=24 auditedUnsafe=0 corrected=24` (one synthetic board family, dependent transformations). Local run took approximately 0.08s and ~10.6MB max RSS for stand-alone probe on Linux host; not a phone performance claim. No iOS/XCTest/device tests run.
