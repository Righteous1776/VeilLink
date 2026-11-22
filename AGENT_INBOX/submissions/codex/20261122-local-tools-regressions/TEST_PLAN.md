# Regression evidence

Baseline and candidate were compared using Swift 6.1.2 on Linux. The tests ran against isolated copies of the product code.

| Area | Baseline | Candidate | Method |
| --- | --- | --- | --- |
| Productivity Lab | 3 new methods failed with 6 failed assertions | 12 of 12 XCTest methods passed | Compiled the actual Foundation engine with its full test class from the patch and a Linux XCTest entry point |
| Message Forge | 3 new methods failed | 13 of 13 XCTest methods passed | Ran the actual Foundation engine and its full test class with a Linux XCTest entry point |
| Tap tempo | 3 of 6 timing cases failed | 6 of 6 passed | Ran the controller extracted from the Swift file with Foundation dates and inert stand-ins for haptics and Combine observability, with the controller stopped |

The controller checks used the three timing sequences in PROPOSAL.md and steady 60, 120 and 240 BPM controls. The productivity tests include 400 and 401 CRLF-separated lines, empty lines, a trailing newline, and stray delimiters before and between placeholders. Message Forge tests cover preservation of inner dots and whitespace, whole-grapheme boundaries and an impossible byte budget.

The combined patch passed `git apply --check` against the recorded main SHA, `git diff --check` in the patched checkout and `swiftc -frontend -parse` on all seven proposed Swift files.

## Integration verification

Run the three test classes listed in MANIFEST.md on an iOS simulator after applying PATCH.diff. Exercise TAP while the metronome is running, paste Windows text into the diff view, and preview dotted tokens and a multi-segment draft in Message Forge. The Linux runs cover algorithm behavior. Apple SDK type-checking, simulator UI and device haptics remain pending.
