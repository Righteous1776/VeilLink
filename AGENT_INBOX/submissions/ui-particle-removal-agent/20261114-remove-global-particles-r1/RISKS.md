# Risks and Overlap

- **High-value shared file:** `VeilLink/App/VeilLinkApp.swift` also hosts legal consent, identity, diagnostics HUD, and transitions. Governor must rebase and review exact-root diff against any pending UI/lifecycle agents before applying.
- **Historical overlaps:** adaptive particle feature originally integrated from Inbox #54; incident/touch proposal #64 addresses the same global particle layer. Removing it supersedes that particle-specific part, not the incident's unrelated diagnostics and signing work. Do not apply both root-particle strategies blindly.
- **Staged concurrent work:** inspect pending draft Inbox #222 diagnostics and #226 VeilScreen for root/lifecycle changes (they are not included here), plus current active integration branches, before batch promotion.
- **Dead-code removal:** the standalone particle policy, seed utility, and unit test are deleted because they belong exclusively to the removed global system. If a new branch adds valid consumers, re-audit prior to integration.
- **Product UX:** scoped game particles, local interaction animation, and background gradients intentionally remain. Disabling every animation would be over-broad.
- **No Apple evidence:** no iOS simulator or device validation has occurred in this proposal. A static check is not a finished build or deployed fix.
- **No authority escalation:** Inbox-only patch; no product/main/IPA/signing/release modifications.
