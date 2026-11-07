# Risks

## Protected surfaces

The proposal is limited to one UI implementation file: `VeilLink/UI/ConversationViews.swift`.

It does not propose edits to DatabaseStore, database schema, transport, protocol, identity/key management, A9/A10 governance, workflows, release/signing, or version/build values.

The product file is not modified by this agent; `PATCH.diff` is advisory only.

## Cross-agent overlap

At preparation time:
- current staged Inbox patches do not mention `ConversationViews.swift`;
- open Inbox PRs do not modify the product file directly;
- legacy PR #9 does not modify `ConversationViews.swift`;
- legacy PR #10 does not modify `ConversationViews.swift`.

The Integration Governor should still re-check any later Inbox submissions before batching. This agent will not resolve future overlap independently.

## Behavioral risks

Low.

The main behavioral risk would be taking the immutable snapshot before pagination has finished. The proposed patch explicitly places `resolvedLimit` after the entire `loadAll` / paginated branch, so it records the final background-computed value.

Because `Int` has value semantics, subsequent main-queue use cannot observe further mutation of `effectiveLimit`.

## Migration / compatibility risks

None expected. No API, persistence, or data-format migration exists.

## Performance / battery risks

Negligible. One integer copy is added per reload.

The proposal preserves all existing background work and does not move database or mini-game reconstruction work onto the main thread.

## Security / privacy risks

None expected. No content, metadata, logging, encryption, or permission behavior changes.

## Known remaining warnings

This proposal intentionally leaves three `DatabaseStore` non-Sendable capture warnings in `ConversationViews.swift` untouched.

They require a separate concurrency-boundary analysis because `DatabaseStore` owns storage behavior. Their existence after this patch must not be misinterpreted as failure of this narrower task.

## Rollback strategy

Revert the two-line snapshot substitution if integration detects a regression. No data repair or migration is required.
