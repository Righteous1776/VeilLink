# V0.9.3 — MaleCNS VFLY1 Foundation

## Scope

V0.9.3 connects the V0.9.2 native VeilFly execution engine to a real MaleCNS-derived graph format. It adds build-host tooling, a versioned VFLY1 binary format, SHA-verified loading, stable sensory/readout groups, a deterministic/no-noise reference stimulus encoder, and graph-guided Core/Lite extraction.

The authoritative dataset remains MaleCNS v1.0 (`male-cns:v1.0`, CC BY 4.0). The current primary implementation recipe is pinned to `alextitonis/fly.ai@1dc982f62da58a29f920fdd4d645fcab4da23624`; `flybrain/build.py` and `flybrain/brain.py` blobs are recorded in the source lock. fly.ai's published `brain-v1` derivative is accepted only when its two published SHA-256 values match.

## Runtime

`VFLY1Loader` maps the artifact read-only, verifies payload SHA-256, validates section bounds/counts, builds the existing `MaleCNSNativeGraph`, and exposes named sensory/readout groups. `MaleCNSGraphRuntime` uses the existing A9 compute budget and native C episode/readout path. Runtime mutation is serialized internally while A9 budget publication remains non-blocking: a budget change that arrives during a bounded episode takes effect at the next episode, and trim requests never wait on the MainActor. First validation mode intentionally disables stochastic noise so deterministic graph/encoder/readout behavior can be tested before a separately versioned deterministic-noise implementation is introduced.

## Builder

`Tools/VeilFlyBuilder` includes:

- `fetch_malecns.py` — pinned prebuilt or official raw acquisition;
- `build_graph.py` — authoritative raw Feather -> fly.ai-compatible NPZ recipe;
- `export_vfly.py` — NPZ -> VFLY1 with provenance and count/hash gates;
- `build_subgraph.py` — deterministic graph-guided Core/Lite extraction;
- `verify_vfly.py` and `provenance.py`.

Raw 1+ GB MaleCNS tables and full/reference VFLY artifacts are never committed into Git.


## Device packaging and tier safety

`MaleCNSGraphManager` validates the VFLY metadata tier after loading; filenames are not trusted as a compatibility signal. Legacy A10 accepts `lite` only. Balanced/high profiles accept `core` or `lite`. `reference` is rejected for every iPhone profile. Probe execution runs off the MainActor.

The manual `MaleCNS VFLY heavy validation` workflow now has two gates: Ubuntu builds SHA-verified MaleCNS v1.0 `Core/Lite` artifacts, then macOS injects only those two verified assets, runs Simulator/XCTest, builds Release `iphoneos` without signing, verifies the VFLY resources are inside the app bundle, and publishes `VeilLink-unsigned-MaleCNS-v1.0`. The full `MaleCNSReference.vfly` is never packaged into the phone app.

## Current environment limitation

This checkpoint adds and validates the complete import/runtime pipeline with deterministic fixtures. The current ChatGPT container cannot fetch GitHub release binaries or Google Storage bulk assets, so the 260 MB pinned fly.ai derivative/full MaleCNS graph is **not fabricated or claimed as executed here**. The heavy asset build is a Work/macOS or external build-host gate. Once those pinned files are available, the builder is one command away from producing `MaleCNSReference.vfly`, `VeilFlyCore.vfly`, and `VeilFlyLite.vfly`.

Protocol 4, VLGM1 v1, E2EE, SQLite Schema V8 and current game rules remain unchanged.
