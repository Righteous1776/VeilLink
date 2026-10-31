# Manifest — route recovery stability R1

- Status: `VALIDATED_LOCAL_STATIC`; Apple SDK and physical-network gates pending Governor application.
- Lane: `INBOX_ONLY`
- base_main_sha: `403b3dc474746d3925ad52fa4169225905bac7fc`
- Candidate payload: `PATCH.diff`
- Product tree mutation in this branch: **none**
- Protocol / database / version / IPA mutation: **none**

## Candidate scope

1. Recover an unexpectedly cancelled active LAN listener without reviving it after a deliberate stop.
2. Recover an unexpectedly cancelled active Bonjour browser so LAN discovery does not remain falsely alive after a network transition.
3. Count each relay HTTP request failure once, preserving the intended two-consecutive-failure threshold.
4. Add unit coverage for relay provider health threshold behavior.

## Proposed product files

- `VeilLink/Transport/LANTransport.swift`
- `VeilLink/Relay/InternetRelayTransport.swift`
- `VeilLinkTests/InternetRelayTests.swift`

No third-party source or binary asset is included.
