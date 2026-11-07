# MANUAL DELIVERY V5 — source review receipt

**Date:** 2026-11-08  
**Repository:** Righteous1776/VeilLink  
**Branch:** dev/veilopoly-manual-v5-20261108  
**Base:** 0ef5b71d1027470e40867040c4c98432d7c841f2

## User delivery

1. `Veilopoly/docs/PLAYER_MANUAL_V5.md`: ~20k Chinese characters across 27 chapters, 40-board and 32-card indices; precise versioned V4/V5 cash supply, loan terms, trading, game turns, survival, macro banking, bankruptcy, IOS deployment boundary and developer QA.
2. Exact same UTF-8 Markdown under `Veilopoly/Sources/VeilopolyUI/Resources/VeilopolyCompleteManual.md`, supported by existing SwiftPM `VeilopolyUI` resources specification.
3. `VeilopolyCompleteManualResource.swift`: resource reading, chapter parsing and localized keyword filtering. No save, game state or networking mutation.
4. `VeilopolyGuideSheet.swift`: read-only segmented selector between the new complete manual and the unchanged 23-topic legacy glossary; mobile UI uses lazy vertical loading and attributed text.
5. `VeilopolyCompleteManualResourceTests.swift`: tests for correct edition, 28 parsed sections, 40 slots, 32 card entries, keyword search.
6. 32-page Chinese-font A4 PDF delivered outside GitHub, generated from the canonical Markdown.

## Exact content parity

Both GitHub Markdown blobs and the PDF source Markdown share Git blob SHA-1 `b86fa641273fae48824c7251603cfeed3821ecbb` (newline included), SHA-256 `abae12367bc58bd89e44727ed81a531f9da4cf39cdbc03a949d7c5774c8383f6`. PDF final SHA-256: `b0cf30d07178678a85bd31a37ddce7510ada4f0af48d017ba60de7269556b00c`. PDF rendered and checked in image/text extraction on representative pages including Chinese TOC, card table and last glossary page.

## Actual validation

- GitHub branch, scoped change paths and exact text hashes: **PASS**.
- PDF generated with searchable Chinese and 32 numbered pages: **PASS**.
- Swift helper and SwiftUI source authored, UIKit interaction and iOS 15 support intended: **SOURCE-ONLY**.
- Full current SHA SwiftPM, Xcode, Apple SDK, real iPhone/iPad and accessibility checks: **NOT_RUN**.
- Only reviewer/Owner can authorize Governor promotion; no main merge, IPA or release.

## Known limitations

- V5 economic engine remains unvalidated under full tests. The manual accurately labels incomplete features as experimental rather than shipping-ready.
- Existing 23-topic brief glossary includes old classic numbers. Toggle label explicitly distinguishes it from the V5 complete manual, and the full text names its applicable rules.
- SwiftUI rendering of long Markdown tables should be tested in compact iPhone width. Future reader enhancement can render board/card tables as native accessible cards without altering canonical Markdown.
- PDF is not bundled within the IPA; delivered separately by user chat. The in-app manual is the Markdown resource, not a PDF viewer.
