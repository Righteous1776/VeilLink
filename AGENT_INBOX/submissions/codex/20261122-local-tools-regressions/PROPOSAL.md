# Eight local tool regressions

| Tool | Input or action | Current result | Proposed result |
| --- | --- | --- | --- |
| Tap tempo | Tap at 0 and 2 seconds | Remains at the default 120 BPM | Sets 30 BPM, the lower end of the displayed range |
| Tap tempo | Tap at 0, 0.5, 0.6 and 1 second | Accidental extra tap changes the estimate to 133 BPM | Ignores the extra tap and stays at 120 BPM |
| Tap tempo | Tap at 0, 0.5, 2.6 and 2.85 seconds | Old and new intervals average to 160 BPM | Measures a fresh sequence at 240 BPM |
| Variable template | Render `}} {{name}}` with a value for name | Stray delimiter appears in the generated message | Reports a malformed placeholder |
| Text diff | Compare the same text with Windows and Unix line endings | Reports extra blank lines. Windows text can exceed the 400-line limit prematurely | Counts CRLF as one break, preserving intentional blank lines |
| Message Forge bullets | Format a URL, filename, email address or decimal | Periods inside tokens create extra bullets and change the content | Preserves embedded periods and splits on a sentence-ending period before whitespace or end of input |
| Message Forge segments | Split a draft where a segment boundary contains spaces | Joining the preview segments loses interior spaces | Joining segments recovers the outer-trimmed draft exactly |
| Message Forge byte limit | One extended grapheme exceeds the segment budget | Preview counts an oversized segment as usable | Shows that complete segmentation is impossible and prompts the user to edit |

The metronome keeps the existing debounce threshold and three-second sampling window. It ignores accidental taps before storing them and clears prior samples after a gap above two seconds. The template scanner checks literal spans between placeholders. The diff tokenizer splits on Swift newline characters, including CRLF. Message Forge measures UTF-8 bytes per whole character and keeps each accepted segment intact.
