# Proposal — strict staged-copy ownership & crash recovery

Audit finding: Codex #94's VeilImportedFileAccess.removeStagedCopy currently uses a substring test on url.path before deleting a parent directory, not an anchored ownership check; the proposal also does not reclaim temporary snapshots after force-quit/crash, which matters for large backups.

Supply a pure Foundation add-only lease policy, reusable by the eventual Governor-selected Files ingress helper. It anchors cleanup to the app's temporary staging directory, requires an immediate UUID lease directory, rejects nested paths and symlinks, and sweeps only expired leases with a 64-item per-pass limit. It never deletes provider source URLs and does not reinstate size caps.

**Governor integration (not done by this Lane):** select exactly ONE of overlapping #92/#93/#94 Files importer designs; apply this add-only PATCH.diff on an isolated branch; replace #94's removeStagedCopy substring check with try? VeilImportStagingLeasePolicy.removeOwnedCopy(url); schedule sweepExpired off-main at a lifecycle-safe moment, excluding active leases. Verify iOS 15 and 200 MiB Files Provider import/cancel before any merge. This patch intentionally does NOT edit another agent's source or run a release.

R2 safety revision: callers must pass a set of active lease UUIDs to the expiration sweeper. It never sweeps entries listed as active, regardless of their age. Ownership also requires a regular staged file rather than a directory or file symlink.
