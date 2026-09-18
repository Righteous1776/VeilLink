# VFLY1 Graph Artifact

VFLY1 is VeilLink's build-time compact graph carrier for MaleCNS-derived runtime graphs. Python/Feather/NPZ are **not** parsed on iOS.

## Locked semantics

- Source dataset: MaleCNS v1.0 (`male-cns:v1.0`, CC BY 4.0).
- Primary recipe reference: `alextitonis/fly.ai` pinned in `AGENT_UPSTREAM_LOCK.md`.
- Reference graph recipe: superclass-retained neurons; inhibitory sign for GABA/glutamate/histamine presynaptic cells; postsynaptic incoming absolute-weight normalization; float32 weights.
- Reference validation count for the pinned fly.ai build: 166,700 neurons / 25,582,938 directed connections.

## Binary layout

Little-endian header (`136` bytes):

- `VFLY1\0\0\0` magic
- format version / header size / endian marker / weight encoding
- neuron, edge, group, membership counts
- byte offsets for graph offsets, targets, weights, group offsets, group neurons and metadata
- metadata byte length / payload byte length
- SHA-256 of every byte after the header

Payload sections:

1. `UInt32[neuronCount + 1]` source-neuron edge offsets.
2. `UInt32[edgeCount]` target neuron indexes.
3. `Float32[edgeCount]` signed normalized weights.
4. `UInt32[groupCount + 1]` group membership offsets.
5. `UInt32[membershipCount]` group neuron indexes.
6. deterministic UTF-8 JSON metadata.

Groups are named stable ports, not raw app/game structures. First supported sensory groups include LC4/LPLC2/LPLC1/LC10a by side; readouts include descending-neuron and fly.ai motor groups when present.

## Tiers

- `reference`: complete pinned fly.ai/MaleCNS retained graph; build/research host, not an iPhone 7 claim.
- `core`: graph-guided induced subgraph for stronger devices.
- `lite`: smaller graph-guided induced subgraph for legacy devices.

`Core/Lite` extraction is deterministic and records seed groups, hop radius, node cap and minimum edge magnitude. Random neuron deletion is prohibited.


## Device admission rule

The runtime does not trust asset filenames. It parses `metadata.tier` and applies the device capability gate after payload SHA verification. Legacy A10 loads only `lite`; balanced/high loads `core` with `lite` fallback; `reference` is rejected on all phone profiles. Build-host tooling may create reference artifacts, but `scripts/inject-vfly-assets.sh` packages only verified Core/Lite artifacts and explicitly removes any stale Reference file.
