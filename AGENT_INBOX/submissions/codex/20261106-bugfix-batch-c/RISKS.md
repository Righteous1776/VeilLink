# Batch C risks / arbitration points

1. **Cross-lane collision**: PR #138 Batch B changes ConversationViews (image send), PR #129 changes ConversationViews (file staging), PR #130 changes both ConversationViews and MiniGameViews (game/link recovery). The patch is against pristine main, not a pre-merged product tree. Governor must reconcile; no independent merge or edits to A/B.
2. **SQLite protected surface**: Only ORDER BY query changes; actual schema untouched. `rowid` reflects local insert arrival, not cross-device total order. Insertions on devices may disagree. Export/import, VACUUM behavior, and retransmissions should be tested before release.
3. **Scroll initial layout**: ScrollViewReader/GeometryReader layout timing varies across iOS15 and iOS26; simulator/device verification NOT_RUN. Card height changes may change footer position; preference measurement must be observed on device.
4. **Card action surface**: Full-card tap-to-open becomes explicit small CTA; intentional UX tradeoff to prioritize scrolling. Verify accessible tap size and VoiceOver interactions in Apple testing.
5. **Performance**: Reading `visibleMessages` in onChange recomputes filtered game messages; profile on older devices if UI stutters persist. This change intentionally avoids touching gesture recognition on chess boards.
6. **Not done**: Batch D / Batch E owner decisions pending. This proposal is not a claim that all ten real-world issues are fixed.
7. **Governance**: No main mutation, CI/workflow dispatch, Issue #6 mutation, IPA, signing or release authorization; review required prior to product integration.
