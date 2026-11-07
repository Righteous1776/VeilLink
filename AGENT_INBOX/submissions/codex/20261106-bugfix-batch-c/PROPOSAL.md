# Batch C · Chat behavior repair

## Scope and evidence
This is an inert code patch, **not** a product deployment. Verified main ccafebab147e069fbabfff579dbf323b0d54f191 has a normal SQLite `messages` rowid table. The iOS15-compatible ChatView uses ScrollViewReader but only scrolls in `.onChange(of: messages.last?.id)`; its asynchronous initial reload has no initial positioning guarantee. Worse, `messages.last` may be an invisible MiniGame move/protocol packet and have no View ID. The invite card is a large Button; the actual Gomoku/Xiangqi board input uses `VeilBoardTapSurface`, a UITapGestureRecognizer allowing simultaneous recognition, so the owner's game-gesture hypothesis should not be mechanically applied.

## C1
Introduce stable `chat-bottom-<conversation.id>` marker after ForEach, always present even if game packets are filtered. On first non-empty display, scroll to it without animation after the current render turn. Observe the visible latest message ID (not the raw hidden tail). A named scroll coordinate space plus footer marker preference measures bottom-to-viewport separation. After initial anchoring, only follow new visible messages if the previous bottom gap is <=200pt. Reset anchoring on chat disappear. This preserves history reading, search jump semantics, and explicit workspace jump.

## C2
Remove the full-width navigation Button around the invite-card header/body. Keep an explicit `进入棋局/查看` action Button and existing accept/decline/retry controls. Non-interactive card regions now yield vertical drag to the surrounding ScrollView. Do **not** add an empty highPriorityGesture DragGesture; such an interception would prevent the ScrollView from owning the gesture. Do not change the already tap-only board input in the independent full game sheet.

## C3
Normal `messages` table is `rowid`-backed (no WITHOUT ROWID). Replace UUID-string tie-breaking with `rowid` in bounded recent, full-history, and ID-list read paths. Primary sorting remains `sent_at`; this changes only same-timestamp tie behavior. Add XCTest with exact equal timestamps, intentionally reversed lexical IDs, and idempotent save replay. No schema/migration/wire/transport mutation.

## Limits
A local rowid is **not** a cross-device consensus sequence. Two handsets can insert simultaneous messages in different orders; clock skew and late-arriving earlier-timestamp packets also remain. Therefore the stronger source-package target “both devices match one global send order” is NOT PROVEN and may require an owner-approved deterministic global ordering contract in a future batch. We specifically do not relabel this local fix as a two-device total-order guarantee.

## Deferred
Batch D (game suggestions, full file import, self-play export) and conditional Batch E are outside this submission. User's current handoff preserves their explicit owner-decision blockers.
