# Proposal — PR debt triage R1

## Owner-action candidates

| PR | Recommendation | Evidence |
| --- | --- | --- |
| #70 RareLab | Close as absorbed | Candidate `VeilRareLabEngine.swift` blob equals current main. |
| #74 Emotion Garden | Close as absorbed | Candidate `VeilEmotionGardenEngine.swift` blob equals current main. |
| #76 AetherLab | Close as absorbed | Candidate `VeilAetherLabEngine.swift` blob equals current main. |
| #84 Offline QR reader | Close as absorbed | Candidate `VeilOfflineQRReaderView.swift` blob equals current main. |
| #81 CodeScanner | Keep pending comparison | It is a competing scanner implementation, not byte-identical evidence. |
| #68 Mission Control | Keep pending comparison | Current main has the product engine and UI, but the staged engine blob differs. |
| #121 CI flake | Keep pending history proof | Kimi suggests #123 supersedes it; this needs exact commit/CI evidence. |
| #129 Files lifecycle | Keep | Current P0 candidate; Inbox Gate passes. |
| #130 game transport recovery | Block integration | Inbox Gate passes only; its refresh-only recovery is not sufficient. See PR #134. |
| #131–#133 | Keep | Current repair candidates; #131 needs Chinese IME device proof. |
| #60 Wire/SQLite | Keep frozen | Protected protocol/schema scope; no blind integration or closure. |

This record recommends that the owner close only #70, #74, #76 and #84 in this first verified batch. It does not close them.
