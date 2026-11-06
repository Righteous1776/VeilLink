# Kimi visual-lane handoff · banking expansion HUD (P4 proposal only)

Owner supplied two new financial/tabletop reference images on 2026-11-06. This is a **visual delta**, not a request for Kimi to edit Swift rule code. The original photos are not placed into public source. See `OWNER_FINANCE_AND_TABLETOP_RULES_20261106.md` for source-derived facts, conflicts, and undecided terms.

## Required visual variants

1. Landscape iPhone / iPad **bank dashboard** with virtual in-game wallet, separate simulated deposit balance, loan summary, maturity timeline and collateral count. Bank product yields remain placeholders until Owner ruling; do not show invented return rates.
2. Compact **loan quotation** overlay: loan ordinal (first/second/third/fourth), 20/30/40/45% tier, collateral caps ¥500 / ¥1,000 / ¥4,000 / ¥7,000, duration, total due; display a visible conflict/rules-draft indicator. Example ¥1,000 × 20% × 3 periods = ¥1,600 total, but only with at least one eligible lot.
3. **Financial simulation product cards**: three separate visual categories (managed 5 periods, venture 4 periods, stocks 3 periods). Use original data-driven art; illustrations should not imply assured income. Exact six-outcome payout tables are awaiting Owner approval.
4. Optional **collectible star indicator** (eight tokens at the banker) for the printed reference variant, showing held stars and a reset/round-complete animation; this is NOT active in classic mode.
5. Optional **no-stake dice challenge**: purely a score event with no wager, currency payout, real-world funding or conversion.
6. Provide empty, disabled and loading states for unapproved terms. UI must not display a live button for unfinished financial actions.

## Design constraints

- All screens belong to the existing **true landscape full-screen** Veilopoly UI, not a portrait-only menu.
- Keep the current mini-program style More/Exit capsule and non-scrolling main board; finance panels scroll independently.
- Every touch target >= 44 pt; preserve legibility for compact phone screens.
- Provide `SPRITE_MAP` aliases and optional effect atlas metadata only. No graphics or terms copied from the printed commercial game's brand, cover art, mascot or illustrations.
- Owner's photographed notes are for deriving gameplay mechanics, not for adding financial instruction or suggesting real-money lending/investing.
- No changes to `VeilopolyEngine`, network, main repo or release actions are granted to Kimi.

## Handoff format

Submit a **K3 financial HUD delta** after the K2 landscape assets, or integrate UI mocks into the K2 delta if those mock screens are already finished. Include `MANIFEST.md`, landscape previews for iPhone/iPad, asset hashes, exact source URLs and permissions, and a concise `SPEC_QUESTIONS.md` with any ambiguities. Kimi should not re-export unchanged K1 textures.
