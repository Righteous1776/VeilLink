# Test Plan

- deterministic replay;
- 12 declared grid nodes;
- >130 declared building units;
- 4 critical nodes;
- grid stability / powered nodes / lit buildings remain bounded;
- storm eventually creates faults;
- different seeds diverge;
- terminal state remains immutable;
- shader resource absence falls back without crash;
- Reduce Motion affects presentation only;
- iPad-size scene rebuild and camera scaling smoke;
- scene restart idempotence;
- Asset Drop gate validates 4 staged assets with exact SHA-256/bytes;
- integration-time iOS 15 semantic build and full XCTest.
