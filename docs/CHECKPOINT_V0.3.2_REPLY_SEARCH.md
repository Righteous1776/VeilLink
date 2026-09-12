# V0.3.2 Reply & Search

## Scope

This checkpoint intentionally stays small: quoted text replies and local conversation search only.

## Reply compatibility

- Replies remain normal Protocol 4 text payloads; no new wire kind or handshake version is introduced.
- The readable body form is `↪︎「quote」\nreply`, so older VeilLink builds show understandable text instead of opaque metadata.
- V0.3.2 decodes that body into a compact quote card plus the new reply.
- Quote source is normalized to one line and capped at 160 characters. Replying to a prior reply quotes only the newest reply body.
- Conversation list previews store only `↪︎ <new reply>` while the encrypted message body retains the complete reply text.

## Search privacy

- Search filters the conversation messages already decrypted for display.
- No plaintext FTS table or durable search index is created.
- Closing search clears the query.

## Invariants

- Protocol: 4
- Schema: V7
- Minimum iOS: 15.0
- Version: 0.3.2 build 8
