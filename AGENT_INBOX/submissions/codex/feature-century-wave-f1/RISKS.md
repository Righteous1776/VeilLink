# Risks and overlap

## Functional risks

- The LCS diff is quadratic; hard 400-line/64-KB limits cap time and memory. The Governor should retain those limits unless profiling proves a safer replacement.
- Three-way merge is intentionally conservative at whole-document level. Conflicts require human resolution; this is not a semantic merge engine.
- Time-zone recommendations are advisory and depend on manually entered working hours. They do not read or write Calendar.
- Import preflight evaluates a typed manifest only. Real file-provider URLs, security-scoped bookmarks, MIME sniffing and decompression-bomb defenses require a later separately reviewed file-intake layer.
- Clipboard copies use the system pasteboard and are user-triggered; the UI must not describe them as protected or expiring.

## Overlap declarations

- PR #52 `VeilMessageForgeTemplate` supplies fixed starter templates. FC-053 is related but materially different: variable extraction, required-value validation and rendering. Governor may compose the fixed templates with this renderer instead of presenting two template entry points.
- PR #67 and #68 are mutually exclusive Mission Control implementations. No product filenames/types overlap, but both add a Tool Center entry.
- PR #70 RareLab uses unique types/files but also adds a Tool Center entry.
- PR #65 audits per-screen/global touch behavior and may touch navigation surfaces. Keep its P0 acceptance gate ahead of this feature.
- `VeilLink/UI/ToolCenterView.swift` is therefore a Governor-owned merge point. This submission records the overlap and does not resolve or overwrite any other lane.

## Protected surfaces

No wire protocol, SQLite/schema, keychain/identity, BLE/LAN transport, A9/A10 governance, black-box recorder, global particle/gesture, version/build, workflow, signing or release surface is changed.

