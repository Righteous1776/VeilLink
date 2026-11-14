# R6 UI risks
- High interface overlap with draft #187 Thinking Studio, and proposed R5 controller modifications (#193/#196). Governor arbitrates; do not apply overlapping patches automatically.
- All current main Gomoku tracking is result-based; no live PVS node stream in deployed app. Never show fabricated depth, probability or candidate ranking.
- A mistaken reuse of `VeilOpponentAvatarView` would load Grok-branded video/assets and Grok-specific VoiceOver speech; use distinct branding or refactor with proper media selection.
- Modal sheet can hide board on compact devices. Prefer compact pinned status when not expanded; test actual gestures.
- Browser prototype uses post-hoc real training evidence and is NOT a live chess engine, screenshot is not deployed functionality.
- Source citations/provenance and any applicable upstream license must be reviewed before removing legacy code; naming authorization is not permission to erase legally required notices.
- No raw private user training archive, model weights or binaries in GitHub Inbox.
- Only R6 layout/docs staged; no production product tree/CI/IPA/merge authority.
