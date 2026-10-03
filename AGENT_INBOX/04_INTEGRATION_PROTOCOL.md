# Unified Integration Protocol

## Freeze

The Integration Governor announces an Inbox cutoff and records the current `main` SHA.

## Triage

For each submission, validate required files, verify its base SHA, classify subsystem/protected surfaces, detect file/API/behavior overlap, and assign ACCEPTED, DEFERRED or REJECTED.

## Batch plan

Accepted submissions are ordered by dependency and conflict risk. The governor publishes a batch manifest before product-tree mutation begins.

## Apply

Accepted proposals are applied to one dedicated integration branch. The governor may rewrite patches to preserve consistency.

## Verify

Required gates include static preflight, XcodeGen/project generation, iOS Simulator build, XCTest, protected-surface review, regression guards, version/build/release drift check, and cross-submission semantic review.

## Promote

Only the Integration Governor or Repository Owner authorizes promotion to `main`. Accepted submissions are then marked VERIFIED/ARCHIVED with the integration commit recorded.
