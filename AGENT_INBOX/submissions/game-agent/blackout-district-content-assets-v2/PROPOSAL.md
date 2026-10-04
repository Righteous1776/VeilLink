# Blackout District / 熄灯街区 — Content + Assets V2

V2 expands the deterministic city grid to 12 nodes and adds three new districts: East Station Interchange, Emergency Command and Riverside Commercial. The graph adds alternate routes, increasing the value of repair order and connectivity rather than merely adding more repair bars.

Compatibility hardening removes the previous fatal shader-resource assumption. If ShaderKit .fsh files are unavailable, the noise layer disables cleanly and district glow uses a locally generated radial texture. Reduce Motion lowers rain/noise/lightning intensity without changing simulation. iPad/large screens receive a wider camera scale.

Three unmodified CC0 Kenney model assets are staged in ASSETS/: maintenance truck, straight road and traffic light. They are source models for controlled top-down sprite baking; existing programmatic city art remains a complete runtime fallback.

ShaderKit MIT source remains vendored through FILES/PATCH.diff with its license.

No product-tree write, protocol/schema/storage/workflow/version/release or A9/A10 mutation is proposed.
