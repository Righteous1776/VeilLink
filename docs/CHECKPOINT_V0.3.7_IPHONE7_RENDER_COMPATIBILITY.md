# V0.3.7 iPhone 7 Render Compatibility

VeilLink 0.3.7-dev build 13 is a render-compatibility checkpoint built from GitHub main `7397c5374e559fecdde07601b7f09646faf33bb4` after reproducing an iPhone 7 / iOS 15-only visual failure from a real screen recording.

The observed failure affected multiple custom-content surfaces (Nearby, Settings and Contact Details): SwiftUI content inside ScrollView/Sheet could shift, clip, disappear and recover while system navigation/tab bars remained stable. The common factor was the shared Veil visual compositor layer rather than BLE data state.

V0.3.7 adds an automatic legacy compositor profile for iPhone 7 / 7 Plus on iOS 15. The profile keeps the black-obsidian / warm-gold visual identity but removes persistent repeat-forever motion and high-cost off-screen composition. Ambient backgrounds use a static reduced layer stack; cards/glass avoid duplicate clipping + large shadows; identity glow is reduced; persistent link traces become static; radar sweep/pulse do not loop on the legacy path. Status-only screens no longer mark trusted/static identity state as active transit.

Protocol 4 and SQLite Schema V8 are unchanged. No BLE, cryptographic, storage or message semantics are changed.
