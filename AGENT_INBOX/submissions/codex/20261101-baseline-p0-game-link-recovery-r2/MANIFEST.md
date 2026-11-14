# Manifest — baseline P0 game secure-session recovery R2

- Status: `DROPPED`
- Lane: `INBOX_ONLY`
- base_main_sha: `ccafebab147e069fbabfff579dbf323b0d54f191`
- Product-tree mutation in this branch: **none**
- Protocol, schema, identity, version, signing, IPA mutation: **none**

## Purpose

This is a P0 correction for the recovery primitive used by the existing game UI. It is not an approval of the candidate represented by PR #130 / `agent-drop/codex/game-link-recovery-r1`; that candidate must remain unintegrated until its own recovery flow is redesigned and retested.

## Proposed product files

- `VeilLink/Security/SessionCoordinator.swift`

## Required integration order

This patch can be evaluated independently on `main`. Do not apply PR #130's refresh-only game-link implementation without a separate corrected proposal and two-device proof.
