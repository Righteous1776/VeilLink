# Verification

Against exact Build 68, the original parser reported passed for an empty run and nested totals followed by a truncated root. A real Swift 6.0.3 XCTest invocation with one pass and one skip was unverified.

The proposed scripts passed all nine tests under the repository's Python unittest discovery command. Exercised both the ordinary CLI (inspect the generated JSON) and the strict --require-tests-passed option on these seven inputs.

| Input | Reported tests | Status | Strict exit |
| --- | ---: | --- | ---: |
| Actual Linux XCTest success | 11 | passed | 0 |
| Actual Linux XCTest failure | 10 | failed | 1 |
| Actual Linux XCTest with one pass and one skip | 2 | passed | 0 |
| xcbeautify macOS mixed fixture | 4 | failed | 1 |
| Empty root summary | 0 | unverified | 1 |
| Child total followed by truncated root | null | unverified | 1 |
| Explicitly skipped entire run | 1 | unverified | 1 |

[macOS fixture used for replay](https://github.com/cpisciotta/xcbeautify/blob/513e4b12c3f6c965d1d3b66bd5cd9d635f03112d/Tests/XcbeautifyLibTests/TestData/MixedTestLog_6_0_macOS.txt)

Patch application with whitespace checks passed. For integration, run the existing CI workflow on the applied patch and inspect the generated unit and UI bundle evidence.
