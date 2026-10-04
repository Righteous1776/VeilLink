# Blackout District — Art Direction

## Camera

Top-down / light oblique feel, not strict pixel-art.

The maintenance truck should read clearly while the city remains dense enough to feel inhabited.

## Palette

Powered:
- warm amber windows;
- cyan grid glow;
- white/cyan truck lamps.

Blackout:
- blue-black facades;
- muted red fault markers;
- almost no window light.

Weather:
- cold gray rain;
- cyan puddle reflections;
- white lightning exposure.

## Third-party integration

Kenney assets should be recolored/graded toward the same storm palette rather than displayed with their original bright palette.

Do not preserve mixed pack art styles unmodified.

## Visual payoff

Repair should have three stages:
1. node turns from red to cyan;
2. grid line re-energizes;
3. building windows come back in a short wave.

The city itself is the reward screen.

## Effects

- ShaderKit dynamic gray noise at low alpha;
- ShaderKit radial gradient district glow;
- Core Image Bloom;
- high-density rain;
- puddle reflection shapes;
- lightning exposure flash;
- electric fault particles;
- repair burst;
- vehicle headlights.

## Performance policy

Modern hardware first.
iOS 15 source compatibility retained.
iPhone 7 performance is not the visual design ceiling.
