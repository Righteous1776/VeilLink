# VeilFlyBuilder

Build-time tooling only. **No Python runtime ships inside VeilLink.**

Canonical data source: MaleCNS v1.0 (`male-cns:v1.0`, CC BY 4.0). Primary implementation reference: `alextitonis/fly.ai` pinned in `docs/AGENT_UPSTREAM_LOCK.md`.

## Fast reference route

```bash
python3 fetch_malecns.py --mode prebuilt --dest ./data
python3 export_vfly.py --data ./data --output ./out/MaleCNSReference.vfly
python3 verify_vfly.py ./out/MaleCNSReference.vfly --expect-neurons 166700 --expect-edges 25582938
python3 build_subgraph.py --input ./out/MaleCNSReference.vfly --tier core --output ./out/VeilFlyCore.vfly
python3 build_subgraph.py --input ./out/MaleCNSReference.vfly --tier lite --output ./out/VeilFlyLite.vfly
```

The prebuilt route accepts only fly.ai's published `brain-v1` SHA-256 values. It is a reproducible derivative of MaleCNS v1.0, not a replacement for the authoritative dataset.

## Raw authoritative route

```bash
python3 fetch_malecns.py --mode raw --dest ./raw-data
python3 build_graph.py --raw ./raw-data --output ./raw-reference
python3 export_vfly.py --data ./raw-reference --output ./out/MaleCNSReference.vfly --tier reference
python3 verify_vfly.py ./out/MaleCNSReference.vfly --expect-neurons 166700 --expect-edges 25582938
```

The raw route fetches the official Feather tables, rebuilds the signed/normalized matrix with `pyarrow`, and follows the pinned `flybrain/build.py` retention/sign/normalization recipe. Raw 1+ GB source tables are never committed to VeilLink. The first raw builder does not yet reconstruct fly.ai's optic-column azimuth table; V0.9.3 validation injects named feature-detector sensory groups directly, and that limitation is recorded in provenance.

## VFLY1

VFLY1 is little-endian, versioned, and stores source-neuron CSR/CSC-style adjacency arrays (`offsets`, `targets`, float32 weights), compact sensory/readout groups, deterministic JSON metadata, and a SHA-256 of the payload. Full/reference graphs remain research/build artifacts; only device-appropriate Core/Lite artifacts are candidates for an IPA after physical-device validation.
