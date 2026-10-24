# Rainline / 雨线末班车 — Art Direction V1

## Visual statement

The player should feel that the train is a moving strip of warmth crossing a drowned blue-black city.

The core contrast is:

**inside = warm, human, fragile**
**outside = cold, wet, huge, indifferent**

## Composition

### Foreground

The full eight-car train occupies the lower third of the screen in side cutaway.

Every car must remain readable as an individual space:
- shell;
- interior panel;
- passenger silhouettes;
- power state;
- fault spark state.

The player character is deliberately small so the train feels larger than the character.

### Midground

Elevated tracks, bridge structures and bright reflection streaks.

### Background

Two skyline parallax layers:
- far skyline: softer, low-contrast, more blue;
- near skyline: darker silhouettes, occasional cyan/pink/yellow windows.

## Lighting

Primary:
- warm amber train interiors;
- cold blue rain/city;
- cyan maintenance light on player;
- orange fault sparks.

Emergency state:
- glass shader tint shifts toward red;
- interior cars fall from warm amber into dim charcoal.

Arrival:
- station lights introduce clean white/yellow geometry at the far side.

## Rain

Three layers:
1. world rain particle emitter;
2. full-screen glass droplet/streak shader;
3. lightning exposure flashes.

This prevents the scene from looking like “just particles falling down.”

## Bloom

Train interior light receives bloom so lit cars read as a continuous band of warmth.

Fault sparks also use additive particles.

## Motion

- skyline far: slow;
- skyline near: medium;
- reflections: fast;
- train itself remains comparatively stable;
- player movement is readable against the stable train.

This creates speed without constantly moving the camera.

## Sound direction for later work

Not part of this patch, but target palette:
- rail joint rhythm;
- rain on glass;
- low transformer hum;
- occasional electrical snap;
- muffled passenger ambience;
- very restrained music.

Avoid constant dramatic soundtrack.
