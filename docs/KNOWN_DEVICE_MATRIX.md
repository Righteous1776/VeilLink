# Known device matrix

Primary real-device targets for current VeilLink engineering:

- iPhone SE (1st generation): primary low-end target.
- iPhone 7: primary iOS 15 / A10 target and the strictest currently observed SwiftUI compatibility target.
- iPhone SE (2nd generation): primary compact modern target.
- iPhone 13 Pro: primary high-performance reference target.
- iPad Air 4: experimental secondary target. Multiple UI defects have been observed; record and preserve compatibility, but defer UI repair until the phone path is stable.

Optimization policy: do not degrade Protocol 4 interoperability by device. Hardware profiles may change local cache sizes, message windows, rendering detail, scheduling/coalescing and memory budgets only.
