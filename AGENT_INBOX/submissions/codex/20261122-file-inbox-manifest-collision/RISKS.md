# Compatibility and overlap

- Existing records continue to use their persisted storedName. The record schema and read path are unchanged. The fix prevents future loss. A previously overwritten inbox copy needs re-import from the provider original.
- For a reserved name, a consumer that shares the physical URL can see the safe basename content.json. The inbox continues to display the original provider name.
- PR #227 introduced these files. Both proposed target files matched Build 68 at the inspected heads of #227, #238, #240, #241, #243, #245 and #246. Apply after the original inbox implementation and recheck newer heads at integration. PR #247 covers other local tools.
- The Xcode Files provider, APFS behavior and full Apple test suite require integration verification. Preserve the final pending-directory rename. Combining exclusive creation with an atomic single-file replacement would defeat the purpose of exclusive creation.
