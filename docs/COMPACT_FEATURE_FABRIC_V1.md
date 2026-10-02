# Compact Feature Fabric V1

## Goal

As VeilLink gains games, local AI, nearby transport and utilities, adding features must not turn the app into disconnected screens or increase background work. This checkpoint establishes a compact, linked feature surface with iPhone 7 as the minimum performance profile.

## Navigation and layout

- The Tool Center is reachable from Chats, Games, Nearby and Settings rather than being hidden behind one screen.
- Four local utilities use an adaptive `LazyVGrid`: two columns on compact phones and additional columns only when width is available.
- Tool tiles use bounded text and a 128-point minimum height, avoiding oversized marketing cards and preserving predictable tap targets.
- Existing top-level tabs remain unchanged, so the feature expansion does not add a sixth cramped tab or alter navigation persistence.

## Work limits

- Password generation uses `SystemRandomNumberGenerator` on demand only.
- SHA-256 text fingerprinting has no persistence or network path.
- QR rendering is debounced by 180 ms, canceled on every edit and canceled when leaving the screen. A 1024-byte input cap bounds Core Image work.
- The link dashboard subscribes only to existing published LAN/BLE state. Its refresh action restarts VeilLink Bonjour/BLE discovery; it does not run an internet speed test, port scan or new polling timer.
- Tactical strategist search performs continuation analysis for at most the strongest eight immediate candidates.
- Tactical coach text reuses one situation snapshot instead of repeating supply/threat scans per unit.

## Privacy and authority

Tool inputs stay inside their view state and are excluded from chat, diagnostics and telemetry. Copy actions are explicit and hand data to the system clipboard. Temporary QR codes warn against encoding long-term keys. No tool gains transport, identity, storage or Agent mutation authority.

## Gates

CI checks the compact grid, QR cancellation/debounce, cross-entry links, password randomness contract, known SHA-256 vector, daily tactical deployments, bounded strategist search and the existing legacy compositor rules.

## UI finish

- Utility surfaces use real ultra-thin material only where the render profile allows expensive effects; the iPhone 7/iOS 15 path receives an opaque, single-layer surface instead.
- Password replacement, QR appearance, scenario changes and tactical coach updates use the shared Reveal/Transit/Resolve motion language.
- Reduce Motion and minimal visual-complexity profiles remove those transitions rather than merely shortening an infinite animation.
- Compact cards have fixed alignment zones, bounded secondary copy and dynamic text styles. Password length labels and values use fixed columns so the slider does not jump; medal chips use an adaptive grid instead of overflowing horizontally.
