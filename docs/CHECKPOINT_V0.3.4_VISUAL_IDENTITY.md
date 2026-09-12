# V0.3.4 Visual Identity

VeilLink 0.3.4-dev build 10 is a UI/motion-only checkpoint based on V0.3.3.

## Design language

- **Veil**: layered near-black planes and restrained occlusion establish depth without neon or constant blur.
- **Identity**: every cryptographic identity ID deterministically derives a local visual glyph. The glyph is a recognition aid only and is not used as a cryptographic fingerprint.
- **Link**: thin state traces communicate scanning, secure-link activity and transfer motion only while those states are active.
- **Resolve**: delivery completion uses a short closure/resolve mark rather than a generic permanent glow.
- Generic rounded cards were reduced in favor of asymmetric cut panels with small metallic edge cues.
- Reduce Motion remains authoritative; continuous scanning/transit motion stops when requested.

## Surfaces changed

- Global visual primitives and background veils.
- Conversation list identity glyphs and secure-link rail.
- Chat navigation identity header, asymmetric message surfaces, reply/composer treatment, delivered-state resolve mark.
- Nearby scanner sweep and peer identity glyphs; pairing digits use segmented cut cells.
- Settings local identity card.
- iPad identity/navigation treatment.
- Onboarding brand reveal and lock keypad.
- Attachment transfer container and TX/RX transit rail.

## Compatibility boundary

- Wire protocol: **4 (unchanged)**.
- Database schema: **V7 (unchanged)**.
- No cryptographic, BLE, database, attachment, backup, or message behavior changed.
- Minimum deployment remains iOS 15.0.
- No iOS 16+ layout APIs were introduced.
