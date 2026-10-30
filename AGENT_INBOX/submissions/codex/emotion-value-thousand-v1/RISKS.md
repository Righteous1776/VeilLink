# Risks, safety and overlap

## Risks

- Emotional-support UX can be mistaken for health care. Keep the non-diagnostic statement and emergency escalation language; obtain specialist review before any symptom scoring, crisis routing or clinical content.
- All 1,000 entries use only in-memory completion state. Persistent journals, streaks, reminders and sharing must be separate proposals because they add storage, notification, privacy and consent concerns.
- Repetitive content can feel mechanical. Future content packs need human editorial review, localization and a user ability to hide/reduce categories.
- The app supports iOS 15. Avoid `NavigationStack`, iOS 16-only symbols and continuous expensive animation until real-device validation.
- The optimized timer uses a main-run-loop `Timer` with tolerance and deadline correction. Background/foreground behavior and timer invalidation still require Instruments and physical-device verification.

## Third-party risk

Open source does not equal unrestricted content use. Every future intake must pass the provenance rule in `THIRD_PARTY_INTAKE.md`; copyrighted quotations, lyrics, stories and scraped “therapy” data are out of scope without explicit compatible rights.

## Overlap

- `VeilLink/UI/ToolCenterView.swift` is already a Governor-owned merge point for #65, #67/#68, #70 and #72. This proposal only records an additive hunk and does not resolve ordering.
- #52 contains fixed communication templates; it does not overlap the new local micro-ritual types, but future supportive-message sharing must be reviewed together.
- P0 #64–#66 remain release blockers; no new visual feature may be treated as a substitute for their iOS 15 gesture/data validation.

