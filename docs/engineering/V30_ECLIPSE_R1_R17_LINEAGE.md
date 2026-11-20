# ECLIPSE R1–R17 — V30 feature lineage and owner exclusions

Snapshot 2026-11-20. This is a GitHub source audit, not a certified release or Elo estimate.

## Non-negotiable owner rules
- Keep upper ECLIPSE orange robot card and honest computing telemetry.
- Remove lower standalone ECLIPSE / 实测仪表 card.
- Remove Gomoku landing ripple / expanding impact ring.
- Preserve real 1–10 thinking slider, untimed search switch, finite node/depth and cancellation.
- Keep native VeilLink orange/grey theme; do not restore green R17 visual regression.

## Inheritance ledger
| Period | Evidence | V30 disposition |
| --- | --- | --- |
| R1–R3 / native baseline | PR #111/#112, #186/#187 | Root tactical safety and learned ordering exist in current GomokuBot; performance and datasets require separate benchmarks |
| R4–R5 PVS | #190/#193/#196 | VeilGomokuUnifiedBridge present; native continuation must not defeat mandatory wins/blocks |
| R6–R7 identity and no-hints | #197/#198 | Upper robot and postgame actual-move trace retained |
| R8 native appearance | #200/#203 | Native theme palette retained, not a standalone ECLIPSE skin |
| R9 seven tiers | #199/#204 | Seven BoardBotDifficulty cases present; exact tier performance still needs tests |
| R10 measured plans/history | #207–#209 | Measured retrospective search and archive source present; training claims not verified |
| R11 counter-trap | #210 | Candidate not certified by a final V30 fixture in this review |
| R12 tactical horizon | #211–#213 | Must verify exact trained data and search tests, not infer correctness from PR label |
| R13 incremental threats | #214 | Candidate optimization, requires compiled benchmark receipt |
| R14 convergence | #215–#220 | R14-style source in mainline; intermediate PR merge is not proof of compiled release inheritance |
| R15–R16 | No distinct authoritative reviewed PR identified; R17.2 claims R16 dependency | Treat as unresolved ancestry, do not invent inclusion |
| R17.1–R17.2 | #234 and R17_2_FROM_R17_1.patch | Select real elapsed clock; reject extra lower instruments, impact ripple and old-engine bulk overwrite |

## Confirmed high-priority defect
V30 GomokuBot.chooseMove rebuilt the native continuation budget with default
searchStrength=5 and unlimitedThinking=false, silently discarding the user's
visible slider and no-wall-clock selection. The isolated preflight branch
introduces GomokuBotBudget.nativeContinuationBudget(from:remainingMilliseconds:)
to preserve both values, with XCTest and owner regression script assertions.

## Offline verification
Use: python3 scripts/local-v30-preflight.py --release-source
This parses complete checked-out Swift sources, checks Python syntax and
runs maintenance, theme, Inbox and owner regression source assertions.
This is SOURCE ONLY: no Xcode app typecheck, signed ReplayKit host extension,
encrypted two-device screen acceptance, or verified IPA.
The historical local-ci-sim.sh references old multiple-workflow layout and
must not be treated as the authoritative V30 release gate.

Do not tag, publish or say screen sharing works before an exact-head compiled
and signed app plus two-device capture/transport/stop tests pass.
