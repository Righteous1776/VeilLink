# VeilLink R5 security + compatibility review

CRITICAL: Identity signing and Hello are protected protocol surfaces. Validating a detached signature is mandatory before using any capability bits. A missing/invalid *optional* extension does not invalidate a separately valid legacy v4 Hello, but must never enable new kinds.
CRITICAL: The legacy Hello signedPayload, v4 HKDF transcript, trust pinning and replay protection are unchanged. No downgrade in cryptographic identity verification.
HIGH: Optional Hello metadata can be stripped by a network attacker without breaking the original v4 signature; the result is **denial/downgrade of enhanced functionality**, not privilege escalation. Make downgrade observable in locally redacted diagnostics and consider a future authenticated consistency check after the session becomes encrypted.
HIGH: An old R2 ACK decoder rejects unknown high bits; R5's conditional ACK advertisement (3 until peer proves bit2, then 7) is mandatory for backward interoperability.
HIGH: R5 fresh capability bits must come from the verified signed Hello in the current session; a 30-day SQLite cache must not bypass current peer-version negotiation or trust.
HIGH: A legacy v4/R4 peer has no R5 signed extension and may require a real chat ACK to negotiate new capabilities. Do not fake a chat acknowledgement or write phantom messages to force bootstrap.
HIGH: New Hello bytes include a second Ed25519 signature; verify fragmented BLE packet handling, low-MTU phones, CB limits, resource/energy use and parser bounds on iPhone 7.
HIGH: R4-v10 outbox still bounds 16 recipients, 512 events, 7-day expiry and 256 inbound entries per peer. No permanent business exactly-once execution or group E2EE can be claimed.
HIGH: PR #53 has a competing proposed DB v9 migration model; only Governor may arbitrate this protected overlap. PR #57 TrollStore readiness is unrelated to encrypted peer trust.
MEDIUM: Future unknown feature bits are currently rejected rather than masked for a conservative downgrade; old clients should not fail core v4.
MEDIUM: Optional extension signature failure currently silently falls back. Governor should add a redacted security diagnostic for downgrade visibility without leaking identity or raw payloads.
STATUS: INBOX_ONLY, no production tree change, iOS native build/tests NOT RUN, no IPA.
