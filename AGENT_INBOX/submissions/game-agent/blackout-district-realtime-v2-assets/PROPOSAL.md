# Blackout District / 熄灯街区 V2

## Content expansion
- Grid expanded from 9 to 12 nodes.
- Adds East Station interchange, emergency command and riverside commercial districts.
- Building population increases to more than 130 declared building units.
- Stabilization threshold is raised to reflect the larger network.
- Critical-facility count is expanded and tested.

## Compatibility
- ShaderKit resource lookup is no longer fatal: missing radial/noise shaders fall back to generated radial glow or no-noise rendering.
- Reduce Motion lowers rain density and converts multi-flash lightning to a single low-intensity flash.
- Large screens/iPad receive a wider camera scale.
- Kenney service-truck image alias remains optional; procedural truck rendering stays available.
- Scene restart remains idempotent.

## Third-party materials
- Direct ShaderKit MIT source/shaders.
- Kenney Car Kit service truck OBJ under CC0.
- Kenney City Kit Roads straight-road OBJ under CC0.
- Texture-free CC0 derivative MTL files avoid a hard dependency on the original colormap PNG.

Governor may bake the models into 2D sprites/atlases or import them directly.
