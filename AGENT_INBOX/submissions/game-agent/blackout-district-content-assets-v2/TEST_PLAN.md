# Test Plan

- equal-seed deterministic replay;
- grid stability/node/building metrics remain bounded;
- representative storm seeds generate faults;
- seed divergence remains deterministic;
- terminal state remains immutable;
- initial city has 12 nodes, >130 building units and 4 critical facilities;
- graph reconnect/power propagation remains valid with 12-node topology;
- missing ShaderKit resources use fallback without crash;
- radial fallback texture renders if SHKRadialGradient is absent;
- Reduce Motion lowers presentation intensity only;
- iPad camera scale preserves controls/HUD visibility;
- optional Kenney-derived sprites can replace procedural art without rule changes;
- three staged GLB hashes/bytes match ASSET_MANIFEST.json;
- full iOS 15 semantic compile and XCTest during Governor integration.
