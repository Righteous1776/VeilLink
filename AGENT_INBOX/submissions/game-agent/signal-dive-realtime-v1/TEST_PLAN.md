# Test Plan

## Static checks

- Apply PATCH.diff against exact base_main_sha.
- Confirm only four declared product/test files are introduced.
- Swift strict-concurrency scan.
- Confirm SpriteKit/CoreImage/UIKit imports resolve on repository iOS target.
- Standard repository preflight after Governor application.

## Unit tests

1. Equal seed + equal 3,000-step input stream yields exactly equal state.
2. Hull, power and noise stay in bounds during long simulation.
3. Sonar consumes power, creates cooldown and emits a sonar event.
4. Sonar contacts are stable for identical state.
5. Low-speed proximity recovers a beacon.
6. Hull-failure state is terminal and immutable.
7. Different seeds alter the massive-unknown echo field.

## Additional integration tests

- Verify sonar pulse is consumed once per UI press and is not repeated across catch-up frames.
- Verify sorted contact ordering is stable.
- Verify recovered beacons disappear from gameplay contacts/render layer.
- Verify final-beacon recovery switches mission to ascent phase.
- Verify surfaced outcome requires all-beacon phase completion + shallow depth + far-route position.

## Scene / rendering tests

- SpriteView presents without crash.
- Scene resize safely rebuilds fog/background/particles.
- Core Image bloom renders on floodlight.
- Full-screen abyss fog shader compiles on simulator/device.
- Sonar ring expands and removes itself.
- Echo blips respect terrain/beacon/massive-unknown class.
- Particulate node count remains bounded.
- World obstacle/beacon node streaming remains bounded.
- Restart clears transient sonar/effect nodes.
- Camera shake/impact burst is finite.
- Power loss fades floodlight.

## Negative / failure cases

- repeated sonar requests inside cooldown;
- sonar request below minimum power;
- sustained max thrust;
- max-depth collision;
- floodlight on at near-zero power;
- obstacle collision at high pressure;
- no contacts in sonar range;
- many contacts in one pulse;
- power loss after beacon recovery;
- restart after each terminal outcome.

## Regression invariants

- Existing games unchanged.
- MiniGameKind unchanged.
- No protocol/schema/persistence mutation.
- No workflow/version/build/release/signing change.
- No A9/A10 governance mutation.

## Device / OS coverage

- iOS 15 compile compatibility check.
- current iPhone portrait.
- iPad aspect-ratio smoke.
- Dynamic Type/VoiceOver for HUD controls.
- Modern-device visual target: stable 60 Hz with full bloom/fog/particles.
- Old-device/iPhone 7 performance is not a gating requirement for this proposal.
