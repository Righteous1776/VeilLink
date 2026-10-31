# Galgame recovery boundary

## What is in main

- Native `VeilStoryEngine.swift` / `VeilStoryLabView.swift` with three small original stories.
- No complete Monogatari engine bundle or production WKWebView host.

## What GitHub records prove

- Owner selected Monogatari v2.8.0 as the primary runtime.
- Official source ZIP: 2,798,775 bytes, SHA-256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`.
- Latest owner-facing R5 package: `VeilLink_Monogatari_Playability_R5_20261025.zip`, 5,697,469 bytes, SHA-256 `068ba55bfa36672d61960240a684dc4d90ceb7a10868409baf73bc4e6ac6c6f1`.
- PR #85 contains only partial text staging (bridge JS, compatibility shim, byte-range helper and evidence). It explicitly states that the official binary and complete host remain only in the owner ZIP.

## Current action

The native Story Lab is moved into Game Lobby so existing story content is no longer hidden in Tool Center. It is not relabelled as the full Galgame.

As of 2026-10-31, Integration Governor Draft PR #100 (`integrate/monogatari-r6-20261031`, commit `ced1cd0e1f561dfdb702eaa08a9a03da7ec6b00f`) stages a real offline Monogatari v2.8.0 MIT runtime, a SwiftUI/WKWebView host, Game Lobby route and an original Chinese demo. Exact-head iOS CI run `41110884224` completed successfully. This is a verified build/test candidate on an isolated product branch, not a main-branch release and not a byte-for-byte recovery of the missing owner-authored R5 story package.

## Required recovery input

For exact R5 content recovery, reattach the exact R5 ZIP (preferred) or R4/R3 package. Governor must verify its recorded SHA-256 and inspect licenses/assets before replacing or combining content. PR #100 can satisfy the runtime/host gap, but cannot prove restoration of the unavailable owner-authored R5 story archive.
