#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy import sparse

from vfly_format import write_vfly, sha256_file

EXPECTED = {
    "brain.npz": "cc9bd1ecd00bd703a6fa648bc6ad145c93c7c1ee53debdcc9ce0d1f4305e6aca",
    "weights.npz": "c29919aa44069a271b1ee978abe05fa9bf6e45e4ba3e436e92b624ef1b5be40c",
}
REFERENCE_NEURONS = 166_700
REFERENCE_EDGES = 25_582_938


def verify_known_prebuilt(data_dir: Path, allow_unpinned: bool) -> dict[str, str]:
    hashes = {name: sha256_file(data_dir / name) for name in EXPECTED}
    if not allow_unpinned:
        for name, expected in EXPECTED.items():
            if hashes[name] != expected:
                raise SystemExit(f"{name} sha256 mismatch: {hashes[name]} != {expected}")
    return hashes


def group_dict(meta: np.lib.npyio.NpzFile) -> dict[str, tuple[str, np.ndarray]]:
    groups: dict[str, tuple[str, np.ndarray]] = {}
    # Sensory groups needed by the first native stimulus encoder.
    for cell_name in ("LC4", "LPLC2", "LPLC1", "LC10a"):
        cell_types = meta["cell_type"].astype(str)
        sides = meta["side"].astype(str)
        for side in ("L", "R"):
            idx = np.flatnonzero((cell_types == cell_name) & (sides == side)).astype(np.uint32)
            if idx.size:
                groups[f"sensory.{cell_name}.{side}"] = ("sensory", idx)
    if "visual" in meta.files:
        groups["sensory.photoreceptors"] = ("sensory", meta["visual"].astype(np.uint32))
    if "superclass" in meta.files:
        superclass = meta["superclass"].astype(str)
        dn = np.flatnonzero(superclass == "descending_neuron").astype(np.uint32)
        if dn.size:
            groups["readout.descending_all"] = ("readout", dn)
    for key in sorted(meta.files):
        if key.startswith("group_"):
            groups[f"readout.{key.removeprefix('group_')}"] = ("readout", meta[key].astype(np.uint32))
    return groups


def main() -> None:
    ap = argparse.ArgumentParser(description="Export fly.ai MaleCNS prebuilt graph to VFLY1")
    ap.add_argument("--data", type=Path, required=True, help="directory containing brain.npz + weights.npz")
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--graph-id", default="malecns-v1.0-flyai-reference")
    ap.add_argument("--tier", choices=["reference", "core", "lite"], default="reference")
    ap.add_argument("--allow-unpinned", action="store_true", help="only for CI fixtures; production/reference must use pinned source hashes")
    ap.add_argument("--source-revision", default="1dc982f62da58a29f920fdd4d645fcab4da23624")
    args = ap.parse_args()

    for name in EXPECTED:
        if not (args.data / name).exists():
            raise SystemExit(f"missing {args.data/name}")
    hashes = verify_known_prebuilt(args.data, args.allow_unpinned)
    meta = np.load(args.data / "brain.npz", allow_pickle=False)
    W = sparse.load_npz(args.data / "weights.npz").tocsc().astype(np.float32)
    n = int(W.shape[0])
    if W.shape[0] != W.shape[1]:
        raise SystemExit("weights matrix must be square")
    if not args.allow_unpinned and (n != REFERENCE_NEURONS or int(W.nnz) != REFERENCE_EDGES):
        raise SystemExit(f"reference count mismatch: {n} neurons, {W.nnz} edges")
    # CSC columns are exactly source-neuron adjacency, matching VeilFly's offsets[source] model.
    offsets = W.indptr.astype(np.uint32, copy=False)
    targets = W.indices.astype(np.uint32, copy=False)
    weights = W.data.astype(np.float32, copy=False)
    groups = group_dict(meta)
    manifest = write_vfly(
        args.output,
        offsets=offsets,
        targets=targets,
        weights=weights,
        groups=groups,
        metadata={
            "graph_id": args.graph_id,
            "tier": args.tier,
            "dataset_id": "male-cns:v1.0",
            "dataset_license": "CC BY 4.0",
            "primary_reference": "https://github.com/alextitonis/fly.ai",
            "primary_reference_revision": args.source_revision,
            "source_brain_sha256": hashes["brain.npz"],
            "source_weights_sha256": hashes["weights.npz"],
            "recipe": "fly.ai superclass-retained, transmitter-signed, abs-incoming-normalized weights",
            "lif_reference": {"dt": 0.020, "tau": 0.100, "gain": 3.0, "tonic": 0.14, "threshold": 1.0},
            "notes": "Derived computational graph; not an exact biological simulation.",
        },
    )
    sidecar = args.output.with_suffix(args.output.suffix + ".manifest.json")
    sidecar.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
