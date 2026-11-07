# Risks and Boundaries

- `Task.detached` cancellation remains cooperative: `VeilFileIntegrityEngine.inspect` already checks each 512 KiB chunk. A blocking provider I/O call may take time to terminate.
- `onDisappear` runs only for actual view departure; force kill and storage-pressure recovery remain owned by `VeilImportStagingLeasePolicy` sweeps.
- SwiftUI `@State` lifecycle should be compiled/tested on iOS 15. Task cancellation and view state changes require main actor correctness.
- Other import windows use the same materializer but are not modified or claimed repaired.
- Overlap review: old Inbox #147 stages generic files but no transport; V28 #161 integrated that work. This patch edits only the integrity tool and its test. #164 is a separate closed, unmerged Veilopoly branch.
- Never place user files, hashes from real devices, ZIP contents, model weights or logs into GitHub.
- No main, schema, protocol, version, release, or workflow mutation.
