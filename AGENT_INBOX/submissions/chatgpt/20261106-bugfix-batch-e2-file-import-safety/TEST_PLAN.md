# E2A validation
- Source anchors checked against main ccafebab147e069fbabfff579dbf323b0d54f191. Proposed tests only.
- Apple SDK, Xcode, XCTest, iPhone/iPad: NOT_RUN.
- Review new `maximumBytes` copy bound with iCloud external providers, 2MB and 2MB+1 byte and 200MB source, cancellation and cleanup.
- Validate no original outside app-owned staging path is deleted.
- Check Swift6 actor isolation of detached NSFileCoordinator.
- Confirm default nil preserves previous images/backups/ZIP inspections.
- E2B must pass old/new protocol negotiation, SHA-256 and huge/empty file tests before product merge.
