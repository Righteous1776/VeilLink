# R4 Risk Register — protected communications and encrypted storage

P0: Four sequential patches stage core source changes only inside Agent Inbox; no product sources may be changed by this Lane Agent. Governor arbitration required before applying.
P0: Peer feature bit2 is needed to decode Wire kind11. A prior event-only v4 peer (bit1) cannot receive controlReceipt; receiver sends kind11 only when the authenticated event requests it. Durable outbound requires fresh session bit2.
P1: Protocol capability metadata currently piggybacks real chat ACKs. A newly trusted, chat-silent peer may not receive durable control events until a current-session chat ACK advertises bit2. Do not fake ACKs or send new frame types to older peers to force negotiation.
P1: ACK signifies saved encrypted event, not successful execution of business action or group consensus. Per-feature authorization, stable recipient identity and execution idempotence are separate responsibilities.
P1: Inbound event inbox keeps 256 entries/peer; after eviction, duplicate event UUID processing can recur. Future consumer needs stronger sequence/clock/tombstone model before enabling group membership or irreversible task commands.
P1: Acknowledged target rows retained only until all recipients ACK, or the event expires. After event GC, deliberately reusing UUID is a NEW send; UI/action layer should never reuse generated IDs.
P1: v10 512-event cap is transaction-enforced (and intentionally bounded), and 16 recipients maximum per event. Overflow/unknown target errors rollback target inserts.
P1: Received receipts must be parsed only within trusted authenticated session, bound to matching peer public key, UUID and AEAD context. Wire v4 replay window rejects repeated sequence.
P1: Existing chat/attachments/keys preserved by additive migrations, but physical restore, lost Keychain and rollback Xcode/XCTest validation are still mandatory.
P2: 2 KiB BLE per-control event cap and 24 KiB codec payload cap differ intentionally. Large payloads need segmented transfer later.
P2: Ordinary IPA/iOS15 and TrollStore environments must keep identical trust and message security. PR #53 provides installation evidence; PR #57 readiness policy is an independent optional feature gate, never a security authority.
OVERLAP: PR #53 design suggests its own DB v9. Governor must choose one single migration chain, not concurrently apply two v9 definitions.
STATUS: REVIEW_REQUIRED, iOS integration tests NOT_RUN, cannot claim production or IPA.
