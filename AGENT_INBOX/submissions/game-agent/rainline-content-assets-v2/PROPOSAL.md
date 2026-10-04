# Rainline / 雨线末班车 — Content + Assets V2

This successor keeps the eight-car real-time repair premise but makes faults system-specific instead of interchangeable.

Lighting faults primarily darken a carriage. Traction faults reduce traction. Thermal faults increase train-power drain. Communications faults preserve more lighting but use a distinct presentation path. Fault class remains deterministic from the session seed.

Compatibility work adds Reduce Motion, softer lightning/rain under that setting, optional third-party train art aliases, and safe shader lookup. Missing third-party art or shader files never becomes a gameplay failure; procedural rendering remains a complete fallback.

Two unmodified Kenney Train Kit GLB files are staged under ASSETS/ with CC0-1.0 provenance. They are intended as offline sprite-bake/reference sources. ShaderKit dynamic gray noise plus its MIT notice remains vendored as text through FILES/PATCH.diff.

No product-tree write, protocol/schema change, workflow dispatch, version/release change or A9/A10 mutation is proposed.
