# Risks / protected surfaces / overlap

- **Current open incidents:** Draft PR #64 (global particle touch conflict, black box, A9 stress), PR #65 (local game/chess/PTT gestures with overlapping alternate patches), and PR #66 (window-level gesture recorder). Those P0s precede any feature publication. Do not combine unresolved gesture patches blindly.
- **Main source proposal:** One navigation entry in ToolCenterView, which is a shared UI surface. Check for parallel UI agents before applying it; do not overwrite their pending changes. New source names are unique and explicitly isolated.
- **Not autonomous:** Twenty algorithms are local, deterministic decision support, NOT twenty new live network services. Only three synthetic cases are available in UI until adapter work is separately approved.
- **Safety:** Dijkstra graph cost is a heuristic, not cryptographic trust or radio distance. Transport and retransmission are advisories, not permission to send/relay or bypass iOS constraints.
- **Data:** A key-inaccessible snapshot must never lead to rekeying, resetting, overwriting or exposing the original database. No raw black-box data in this PR.
- **Resource protection:** Largest graph 1,024 edges and 256 nodes. On A9 iPhone7, benchmark memory and synchronous performance before enabling periodic analysis.
- **Tests:** XCTest text is staged but not compiled in a macOS/iOS environment. SwiftUI dynamic layouts cannot be verified here. Do not declare all features production-ready.
- **Numerical robustness:** Bound snapshots at trusted adapter layer, especially integer extremes, invalid latency and negative queue observations. Limit results to bounded strings.
- **Copyright/security:** no 3rd-party assets, no model weights, no entitlement modification, no invasive surveillance or hidden logging.
