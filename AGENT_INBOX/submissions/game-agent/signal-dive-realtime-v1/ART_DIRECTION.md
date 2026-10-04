# Signal Dive / 深潜信号 — Art Direction V1

## Visual statement

The submarine should look small enough that the ocean feels unreasonable.

The screen is not “blue underwater.” It transitions from cold teal near the upper layer into almost black blue-green at depth.

## Composition

### Submersible

Small, readable, slightly left of center.

- cyan cockpit edge;
- narrow pale floodlight;
- tiny warm/cold instrument point;
- no large hero sprite dominating the scene.

### Floodlight

The floodlight is the main local contrast tool.

It should illuminate only a narrow forward cone and suspended particulate, reinforcing how little of the environment is actually visible.

### Sonar

Sonar is visualized as:

1. one expanding thin cyan ring;
2. delayed echo points positioned by bearing + distance;
3. different blip scale/color by contact class;
4. fast fade back into darkness.

No permanent minimap is required in V1.

## Depth

Upper trench:
- teal;
- more particulate;
- readable terrain.

Mid trench:
- darker cyan;
- larger empty areas;
- sparse signal light.

Deep trench:
- near-black;
- reduced saturation;
- pressure vignette;
- massive silhouettes that barely separate from the background.

## Unknown silhouettes

They must read as scale, not as a clearly identified monster.

- large ellipse/body masses;
- faint fins/projections;
- very low alpha;
- more visible during high-noise/deep states and sonar echoes;
- no attack animation in V1.

## Beacons

Warm orange is reserved for human-made recovery signals.

This gives the player one warm color to follow through the cold environment.

## Motion

- suspended particles drift slowly;
- deep silhouettes barely move relative to camera;
- sonar is the fastest clean motion;
- collision shake is short and mechanical.

## Sound direction for future work

Not in this patch:

- low hull creak;
- distant water/structure resonance;
- sonar ping with long decay;
- electric motor whine under thrust;
- radio fragments with bandwidth narrowing at depth;
- minimal music, especially below the third beacon.
