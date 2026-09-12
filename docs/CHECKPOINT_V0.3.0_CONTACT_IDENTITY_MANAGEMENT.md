# VeilLink V0.3.0 Contact & Identity Management

Feature-phase checkpoint based on V0.2.3 build 5. Protocol 4 and Schema V6 remain unchanged.

## Added
- Local contact details sheet from a conversation.
- Per-local-identity contact alias editing; aliases are never transmitted to the peer.
- Alias updates contact display name and all matching local conversation titles atomically.
- Non-active local identities can be deleted after password verification.
- Identity deletion removes the local private key/password verifier, scoped contacts, conversations, messages, attachment rows and attachment files, then normalizes the remaining primary identity.
- Active identity cannot be deleted directly; switch first.

## Version
- Marketing version: 0.3.0-dev
- Build: 6
- Protocol: 4
- Schema: V6
