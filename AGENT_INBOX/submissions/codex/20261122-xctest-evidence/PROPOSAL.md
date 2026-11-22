# Correct the XCTest evidence gate

Build 68 can mark a zero-test log as passed. It also pairs a root completion line with a nested suite's earlier counts if the root totals are missing. Conversely, a clean run with one pass and one explicit skip can be classified as unverified. These results affect the existing strict CLI option used after simulator tests.

Read each top-level suite's counts directly after its completion marker. Recognize the optional skipped-test clause and retain the last root's counts for consumers. Accept complete evidence when all observed starts have closed and counts indicate at least one non-skipped test across the invocation. Explicit failure evidence takes precedence over an incomplete log. A missing log remains not_run.

The patch includes regression cases for a truncated second bundle, nested totals, multiple complete bundles, an empty run, skips and failures. The existing workflow calls and report status vocabulary are preserved.
