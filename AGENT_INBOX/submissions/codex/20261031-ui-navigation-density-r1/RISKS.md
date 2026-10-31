# Risks — UI navigation density R1

- Apple compilation and physical-device visual verification are unavailable in this Linux image.
- Inline titles are intentionally smaller than the previous large-title style; this is the mechanism that removes the unwanted second vertical tier.
- PR #54 is the still-open historical adaptive-particle Inbox proposal whose behavior was already integrated into main. This candidate narrows one integrated trigger and should supersede that trigger during arbitration.
- PR #100 adds a Game Lobby entry. This candidate does not edit `GameLobbyView.swift`, but it changes the phone root's title mode around that screen; the combined visual check remains required.
- Conversation row spacing may respond differently at extreme Dynamic Type sizes, so accessibility device testing is mandatory.

Rollback is a clean reversal of the three-file patch; no data or protocol rollback is required.
