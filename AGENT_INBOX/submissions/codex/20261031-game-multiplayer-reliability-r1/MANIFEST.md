# Manifest — game multiplayer reliability R1

- Status: `VALIDATED_LOCAL_STATIC`; Apple SDK and physical multi-device gates pending Governor application.
- Lane: `INBOX_ONLY`
- base_main_sha: `403b3dc474746d3925ad52fa4169225905bac7fc`
- Candidate payload: `PATCH.diff`
- Product tree mutation in this branch: **none**
- Protocol / database / version / IPA mutation: **none**

## Candidate scope

1. Stop a just-finished, declined or cancelled session from hiding a quick rematch during the cross-invite collision window.
2. Treat an authenticated secure session as the game channel readiness source of truth, including LAN/relay sessions that do not have a BLE GATT snapshot.
3. Reuse VLGM1 structural validation before an outbound game command is persisted into the reliable queue.
4. Add focused XCTest coverage for rematch visibility and malformed outbound commands.

## Proposed product/test files

- `VeilLink/Core/MiniGames.swift`
- `VeilLink/Security/SessionCoordinator.swift`
- `VeilLink/UI/MiniGameViews.swift`
- `VeilLinkTests/MiniGameTests.swift`

No third-party source or asset is included.
