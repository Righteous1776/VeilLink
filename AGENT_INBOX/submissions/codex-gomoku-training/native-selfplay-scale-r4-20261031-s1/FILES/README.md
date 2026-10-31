# External runner source index

The executable and large game data remain outside Inbox by policy. The reviewed text source paths and SHA-256 values are in `RUN_SHA256SUMS.txt`:

- `runner/Compat.swift` — Foundation-only state/learning compatibility slice.
- `runner/main.swift` — native Bot execution, atomic shard output and coverage modes.
- `audit/replay.py` — independent legal-move/terminal/checksum auditor.
- `analysis/bagua_report.py` — exportable Bagua signature, use/break/discovery evidence.
- `analysis/paired_tournament.py` — colour-swapped promotion calculation.

No code in this directory has been applied to the VeilLink product tree.
