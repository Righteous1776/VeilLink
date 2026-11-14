# VeilLink Mechanical Motion R1 — ECLIPSE Instrument Language

## Objective
Replace juvenile ambient particles, ripples and decorative loop animations with **visible, functional, restrained, machine-inspired animation** based on the existing ECLIPSE compute console and board search visualization. No new third-party framework or binary assets.

## Exact reference study
- `VeilLink/UI/VeilEclipseComputeConsole.swift` uses dark instrumentation, monospaced labels, active/idle gating and a TimelineView tied to actual compute start.
- `VeilLink/UI/VeilEclipseBoardThoughtField.swift` displays genuine short-lived trace events during search and stops when the engine is idle.
- `VeilLink/Core/VeilMotionKit.swift` already has reduced-motion, low-power, compositor and performance policy; this proposal reuses the existing VeilMotionPolicy instead of inventing another global animation system.

## Implemented (proposed patch)
1. **RF stepping actuator:** Nearby's legacy `RadarStatusView` pulse and continuous sweep are deleted. A cut-corner machined plate, calibrated 24-notch stator, two opposed segmented rotors, central RF core and lock lamp appear. Rotor moves only while `bluetooth.isRunning`, app is active, motion allowed, and power conditions permit. Nearby peer count and RF scan/standby are real observed state.
2. **CPU / AI actuator:** AgentStatusView uses the same visual language; engaged is bound to `ready/loading/generating`, but mechanical motion runs only on `loading/generating`. It never implies an actual load percentage.
3. **Eight-detent link health:** Real BLE `healthScore` maps to 0–8 metal bars beside the existing H-score numeric label; the bars animate only when a new score is observed.
4. **Stable motion core:** 12 Hz stepper simulation, 48 angular detents per 4-second revolution, fully deterministic, CPU-bounded; pauses in background, low power, system Reduce Motion, or whenever VeilMotionPolicy suppresses persistent motion.
5. **Accessibility and safety:** no global Canvas overlay, no touch gestures, no intercepted taps, no message/payload access, and a readable non-animated state. All original gradients/glass and local ECLIPSE effects remain.

## Review boundary
This is an Inbox **proposal**, not a merged release. It complements owner-requested global particle removal Draft PR #229 and must not be promoted independently as proof that particles have been deleted. Xcode/iOS build and real BLE test have NOT_RUN.
