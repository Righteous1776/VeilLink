# TrollStore Readiness R1: cross-distribution capability authorization and fallback

## Motivation and verified overlap
PR #53 already proposes official marker/receipt/environment detection and a Settings UI. **Do not duplicate or override PR #53.** This proposal adds the missing pure policy boundary as an independent file, with no SettingsView, Info.plist, app entitlement, wire protocol, database or governance edits.

Official upstream reference: https://github.com/opa334/TrollStore (review actual device/version support at integration time). Installation source alone is **not** a capability grant.

## Architecture
Three layers:
1. **Evidence** — PR #53 maps recognized, app-owned installation evidence to `VeilInstallationClass`: ordinary / trollStore / trollStoreLite / simulator / unknown.
2. **Claim + direct runtime proof** — the signed application must actually declare the narrow required capability and the backend must perform a safe, permitted operational probe; a marker, Info.plist string, presence of a helper app or OS version is insufficient. Probe results expire after 10 minutes; inactive/unknown/future results are denied.
3. **Explicit user opt-in + safety** — enhanced candidate only after deliberate setting, protected data available, and compatible foreground/thermal/low-power/device tier. Otherwise route to ordinary, fully sandboxed VeilLink behavior.

Features with reserved gates: high-memory local inference, background link continuity, expanded file workspace, extended local diagnostics. These gates **do not implement any elevated operation**. Each actual backend must enforce its OS permissions and per-action user authorization again.

## Device policy
- iPhone 7 / legacy hardware: normal BLE/chat/DB unaffected; high-memory special mode automatically declined.
- Modern iPhones with ordinary/TestFlight/App Store distribution: standard fallback is mandatory even if feature toggles are true.
- Genuine TrollStore or Lite signal: only potential candidates, never automatic grant.
- Unsupported or updated iOS, absent probe, unsigned or invalid entitlement: standard fallback. No attempt at a private API or exploit.

## Not included
No TrollStore installation guidance or exploit, no bypass of signing, no private entitlements, no sandbox escape, no JIT/background persistence implementation, no access to other apps' data, and no changes to user identity/trust/keys or database.
