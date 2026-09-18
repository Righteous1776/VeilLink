#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np

from vfly_format import read_vfly, write_vfly

DEFAULT_SEEDS = [
    "sensory.LC4.L", "sensory.LC4.R", "sensory.LPLC2.L", "sensory.LPLC2.R",
    "sensory.LC10a.L", "sensory.LC10a.R", "readout.escape_L", "readout.escape_R",
    "readout.steer_L", "readout.steer_R", "readout.forward_L", "readout.forward_R",
    "readout.backward_L", "readout.backward_R",
]


def members(artifact, name: str) -> np.ndarray:
    try: i = artifact.group_names.index(name)
    except ValueError: return np.empty(0, dtype=np.uint32)
    a, b = int(artifact.group_offsets[i]), int(artifact.group_offsets[i + 1])
    return artifact.group_neurons[a:b]


def _expand(adjacency, seeds: set[int], hops: int, cap: int, min_abs_weight: float) -> set[int]:
    selected = set(seeds)
    frontier = set(seeds)
    for _ in range(max(0, hops)):
        scored: dict[int, float] = {}
        for source in sorted(frontier):
            a, b = int(adjacency.indptr[source]), int(adjacency.indptr[source + 1])
            for edge in range(a, b):
                weight = float(adjacency.data[edge])
                if weight < min_abs_weight:
                    continue
                target = int(adjacency.indices[edge])
                if target in selected:
                    continue
                scored[target] = max(scored.get(target, 0.0), weight)
        if not scored:
            break
        room = cap - len(selected)
        if room <= 0:
            break
        ordered = sorted(scored, key=lambda n: (-scored[n], n))[:room]
        frontier = set(ordered)
        selected.update(ordered)
    return selected


def select_nodes(artifact, seeds: list[str], hops: int, max_nodes: int, min_abs_weight: float) -> np.ndarray:
    from scipy import sparse
    sensory_names = [name for name in seeds if name.startswith("sensory.")]
    readout_names = [name for name in seeds if name.startswith("readout.")]
    sensory: set[int] = set()
    readouts: set[int] = set()
    for name in sensory_names:
        sensory.update(int(x) for x in members(artifact, name))
    for name in readout_names:
        readouts.update(int(x) for x in members(artifact, name))
    if not sensory and not readouts:
        raise SystemExit("none of the requested seed groups exist")

    # VFLY offsets are source -> target. Expand forward from sensory circuits and backward from
    # descending/readout neurons, then induce the intersection-friendly union. This preserves
    # high-value paths near both ends instead of randomly deleting neurons.
    magnitude = np.abs(artifact.weights).astype(np.float32, copy=False)
    forward = sparse.csr_matrix((magnitude, artifact.targets, artifact.offsets), shape=(artifact.neuron_count, artifact.neuron_count))
    reverse = forward.transpose().tocsr()
    seed_union = sensory | readouts
    if len(seed_union) >= max_nodes:
        return np.asarray(sorted(seed_union)[:max_nodes], dtype=np.uint32)
    half = max(len(sensory), max_nodes // 2)
    forward_selected = _expand(forward, sensory or seed_union, hops, min(max_nodes, half), min_abs_weight)
    remaining_cap = max_nodes
    reverse_selected = _expand(reverse, readouts or seed_union, hops, remaining_cap, min_abs_weight)
    combined = seed_union | forward_selected | reverse_selected
    if len(combined) > max_nodes:
        # Seeds are non-negotiable; fill the remaining slots deterministically from the two
        # graph-guided expansions, preferring neurons present on both sides of the path.
        both = (forward_selected & reverse_selected) - seed_union
        only = (forward_selected | reverse_selected) - seed_union - both
        ordered = sorted(both) + sorted(only)
        combined = seed_union | set(ordered[:max(0, max_nodes - len(seed_union))])
    return np.asarray(sorted(combined), dtype=np.uint32)

def induced_graph(artifact, selected: np.ndarray):
    old_to_new = np.full(artifact.neuron_count, -1, dtype=np.int64)
    old_to_new[selected] = np.arange(selected.size, dtype=np.int64)
    offsets = [0]; targets: list[int] = []; weights: list[float] = []
    for old_source in selected:
        a, b = int(artifact.offsets[int(old_source)]), int(artifact.offsets[int(old_source) + 1])
        for edge in range(a, b):
            old_target = int(artifact.targets[edge])
            new_target = int(old_to_new[old_target])
            if new_target >= 0:
                targets.append(new_target); weights.append(float(artifact.weights[edge]))
        offsets.append(len(targets))
    return np.asarray(offsets, dtype=np.uint32), np.asarray(targets, dtype=np.uint32), np.asarray(weights, dtype=np.float32), old_to_new


def main() -> None:
    ap = argparse.ArgumentParser(description="Build graph-guided VeilFly Core/Lite induced subgraph")
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--tier", choices=["core", "lite"], required=True)
    ap.add_argument("--hops", type=int, default=4)
    ap.add_argument("--max-nodes", type=int, default=None)
    ap.add_argument("--min-abs-weight", type=float, default=0.002)
    ap.add_argument("--seed-group", action="append", default=[])
    args = ap.parse_args()
    artifact = read_vfly(args.input)
    max_nodes = args.max_nodes or (48_000 if args.tier == "core" else 12_000)
    seeds = args.seed_group or DEFAULT_SEEDS
    selected = select_nodes(artifact, seeds, args.hops, max_nodes, args.min_abs_weight)
    offsets, targets, weights, old_to_new = induced_graph(artifact, selected)

    groups = {}
    for i, name in enumerate(artifact.group_names):
        a, b = int(artifact.group_offsets[i]), int(artifact.group_offsets[i + 1])
        old = artifact.group_neurons[a:b]
        mapped = old_to_new[old]
        mapped = mapped[mapped >= 0].astype(np.uint32)
        if mapped.size:
            groups[name] = (artifact.group_kinds[i], mapped)
    metadata = dict(artifact.metadata)
    metadata.update({
        "graph_id": f"{metadata.get('graph_id','malecns')}-{args.tier}",
        "tier": args.tier,
        "parent_graph_sha256": __import__('hashlib').sha256(args.input.read_bytes()).hexdigest(),
        "subgraph_policy": {
            "kind": "graph-guided-sensory-forward-readout-reverse",
            "seed_groups": seeds,
            "hops": args.hops,
            "max_nodes": max_nodes,
            "min_abs_weight": args.min_abs_weight,
        },
        "selected_parent_neurons": selected.tolist(),
    })
    manifest = write_vfly(args.output, offsets=offsets, targets=targets, weights=weights, groups=groups, metadata=metadata)
    args.output.with_suffix(args.output.suffix + ".manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
