# Veilopoly · 象牙白世界叙事素材 V1 / 运行时入库

**Task** `VL-VEILOPOLY-WORLD-TEXT-V1-20261107`
**Base** `93a6efc6f2fd50135d84d265bdf5f713a87f7831`; independent branch `dev/veilopoly`; iOS 15 minimum remains.

This is **code, not just story proposals**:
- `VeilopolyWorldEditorial.swift` contains 40 unique canonical board pages (stable `VL-LORE-TILE-00..39` IDs, title, on-board teaser and larger scene paragraph). All special squares, railroads and utilities have prose too. Only the actual matching tile index + name + TileKind exposes the page: future custom boards or renamed plots cannot get a misleading story.
- The real `UI.swift tileInspector` now shows the selected square's text **inside the existing inspector**, without a detached full-board overlay. Live prices, owners, taxes and tile-hit actions remain authoritative.
- `VeilopolyCivicText.deed` appends the corresponding full paragraph to the existing **one shared ivory legal-document component**, rather than spawning another panel.
- Five issuer pages for Codex's simulated stocks VTL/AUR/MNT/NOV/ORB use true symbol+name+sector matching. The existing `StockMarketPanel` quote hero shows issuer lore, plus five legitimate market-regime notices and dynamically matched halt/volume notices. The graph, P&L, buy/sell estimates and order entry keep Codex's actual Engine values.
- This writing describes a **fictional table-top city**, not asserted history or real company performance. Quotes remain local simulation; no guidance for real trading. Dynamic figures never get embedded in editorial strings.
- `WorldEditorialTests.swift` adds five engine XCTest source cases covering 40 unique names/IDs, wrong-type and renamed-tile fallback, five verified issuers, regime/halt branching and no change in GameState hash/market; `CivicTextTests.swift` validates the deed lore field.
- This does **not** change `GameState` / `Tile` / card rules / taxes / RNG / stock pricing / banking / multiplayer protocol / persisted JSON format.
- **Not yet run** Xcode full build, XCTest or iPhone7 iOS15.8.3 dynamic-size and 40-cell touch performance. No Actions, IPA or production main modification.

**Style contract**: ivory white parchment + antique gold outline + deep teal. The narrative is shown within existing board/document/stock UI, not scattered as loose images or widgets.
