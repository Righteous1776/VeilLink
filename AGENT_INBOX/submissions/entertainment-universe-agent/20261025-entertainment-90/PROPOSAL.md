# PROPOSAL — VeilLink Entertainment Universe 90

This document records the roadmap and a real, externally delivered code candidate. The GitHub branch itself only contains the contract, not Swift sources. A merge cannot enable the features.

## Scope

90 separately identified experience directions, grouped in nine categories (see CATALOG_INDEX.md):
A interactive stories; B single-player worlds; C local group events; D audio/video; E creators' tools; F exploration/simulation; G AI-style game directors (rule based at first); H exhibitions/collectibles; I shared entertainment universe.

## Existing local candidate source bundle (not staged here)

E01: Original three-story branching narrative engine (conditions, items, endings, deterministic replay) with independent iOS15 SwiftUI view.
E04: Offline book editor: add/update/remove scenes, branch edits, bounded undo/redo, JSON export/import and graph validation; independent draft UI.
E06: Read-only timeline reconstruction and side-by-side divergence/ending/item comparisons.
E11: Offline seeded 12x12 roguelite engine: seeded topology, guaranteed safe path, monsters, relics, adjacent combat, three-floor progression and replay; standalone SwiftUI view.

Local ZIP SHA-256: e456713ff5efb39d94033c21a48df4bb3b0145412733a889a841e64a57a46499

## Integration gates

1. Governor acquires and hashes the full ZIP in the ChatGPT conversation; never claim that this PR contains code.
2. Isolate add-only source patch on a Governor-managed branch. This proposal never edits existing GameLobbyView, ToolCenterView or existing games.
3. Resolve P0 #64/#65/#66 touch/stability, then select an opt-in entertainment entry point.
4. Run macOS iOS build, XCTest, simulator UI tests and physical iPhone7 iOS 15.8.3 touch/legal/dark/light checks.
5. Preserve existing Wire v4, SQLite v10, identities and A9/A10 boundaries. No IPA Action until authorized.
6. Promote only after passing gates, separately from this draft PR.

The remaining 86 directions are designs only; no claim that they are implemented.
