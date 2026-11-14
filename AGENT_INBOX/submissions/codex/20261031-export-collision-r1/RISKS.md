# Risks

- Filename uniqueness must not change export payload formats, checksums or encryption.
- Prefixes and suffixes are compatibility contracts with the storage cleanup allow-list and must remain stable.
- The UUID suffix is random metadata only; it is not used as a cryptographic key or identity.
- User-created Documents backup exports remain persistent until the user deletes them.
- No pre-existing file may be removed merely to prepare a new export destination.
