# Manifest — UI navigation density R1

- Status: `VALIDATED_LOCAL_STATIC`; Apple SDK and physical-device visual gates pending Governor application.
- Lane: `INBOX_ONLY`
- base_main_sha: `403b3dc474746d3925ad52fa4169225905bac7fc`
- Candidate payload: `PATCH.diff`
- Product tree mutation in this branch: **none**
- Protocol / database / version / IPA mutation: **none**

## Candidate scope

1. Stop full-screen particle bursts on bottom-tab changes while retaining ambient particles and God Mode quality budgets.
2. Use compact native navigation titles for the phone chat, nearby, game and settings roots so the title occupies the top bar instead of a second large-title tier.
3. Move conversation row insets/background/separator control to the actual `List` row container and reduce the inter-card gap.

## Proposed product files

- `VeilLink/App/VeilLinkApp.swift`
- `VeilLink/UI/AdaptiveRootView.swift`
- `VeilLink/UI/ConversationViews.swift`

No third-party source or binary asset is included.
