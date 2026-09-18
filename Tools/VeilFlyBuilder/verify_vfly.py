#!/usr/bin/env python3
from __future__ import annotations
import argparse, json
from pathlib import Path
from vfly_format import read_vfly, sha256_file

ap = argparse.ArgumentParser()
ap.add_argument("path", type=Path)
ap.add_argument("--expect-neurons", type=int)
ap.add_argument("--expect-edges", type=int)
ap.add_argument("--expect-tier", choices=["reference", "core", "lite"])
ap.add_argument("--expect-dataset")
args = ap.parse_args()
a = read_vfly(args.path, verify_hash=True)
if args.expect_neurons is not None and a.neuron_count != args.expect_neurons:
    raise SystemExit(f"neuron count {a.neuron_count} != {args.expect_neurons}")
if args.expect_edges is not None and a.edge_count != args.expect_edges:
    raise SystemExit(f"edge count {a.edge_count} != {args.expect_edges}")
if args.expect_tier is not None and a.metadata.get("tier") != args.expect_tier:
    raise SystemExit(f"tier {a.metadata.get('tier')} != {args.expect_tier}")
if args.expect_dataset is not None and a.metadata.get("dataset_id") != args.expect_dataset:
    raise SystemExit(f"dataset {a.metadata.get('dataset_id')} != {args.expect_dataset}")
print(json.dumps({
    "ok": True,
    "sha256": sha256_file(args.path),
    "neuron_count": a.neuron_count,
    "edge_count": a.edge_count,
    "groups": dict(zip(a.group_names, a.group_kinds)),
    "graph_id": a.metadata.get("graph_id"),
    "tier": a.metadata.get("tier"),
    "dataset_id": a.metadata.get("dataset_id"),
}, ensure_ascii=False, indent=2, sort_keys=True))
