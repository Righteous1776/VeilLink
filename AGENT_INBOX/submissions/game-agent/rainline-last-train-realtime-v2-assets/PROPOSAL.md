# Rainline / 雨线末班车 V2

This successor carries the final Rainline V1 implementation forward onto the Asset Drop governance baseline.

## Content
- Four deterministic fault classes: lighting, traction, thermal, communications.
- Fault classes now affect different systems instead of sharing one generic penalty.
- Seven route story beats and fault-kind-specific repair feedback.
- Distinct spark color language per system.

## Compatibility
- Reduce Motion lowers rain density and replaces rapid lightning with a low-intensity single flash.
- Optional third-party train artwork remains fallback-safe.
- Missing ShaderKit noise resource disables only the noise layer.
- Procedural train/city rendering remains available.

## Third-party materials
- ShaderKit dynamic gray noise shader under MIT.
- Kenney Train Kit locomotive and detailed track OBJ under CC0.
- Texture-free CC0 derivative MTL files let both models render without the source pack colormap texture.

Governor may import the models directly or bake/atlas them into 2D sprites.
