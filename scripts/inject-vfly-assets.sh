#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:-}"
destination_dir="${2:-VeilLink/Resources}"

if [[ -z "$source_dir" || ! -d "$source_dir" ]]; then
  echo "usage: $0 <directory-containing-VeilFlyCore.vfly-and-VeilFlyLite.vfly> [destination]" >&2
  exit 2
fi

core="$source_dir/VeilFlyCore.vfly"
lite="$source_dir/VeilFlyLite.vfly"
[[ -s "$core" && -s "$lite" ]] || { echo "missing Core/Lite VFLY assets" >&2; exit 3; }

mkdir -p "$destination_dir"

python3 - "$core" "$lite" "$destination_dir" <<'PY'
import hashlib
import json
import os
import pathlib
import shutil
import struct
import sys
import tempfile

MAGIC = b"VFLY1\0\0\0"
HEADER = struct.Struct("<8sIIIIIIIIQQQQQQQQ32s")
HEADER_SIZE = HEADER.size

def inspect(path: pathlib.Path, expected_tier: str):
    raw = path.read_bytes()
    if len(raw) < HEADER_SIZE:
        raise SystemExit(f"{path}: truncated")
    values = HEADER.unpack_from(raw, 0)
    (
        magic, version, header_size, endian, weight_encoding,
        neurons, edges, groups, members,
        offsets_pos, targets_pos, weights_pos, group_offsets_pos, group_neurons_pos,
        metadata_pos, metadata_len, payload_len, payload_hash
    ) = values
    if magic != MAGIC or version != 1 or header_size != HEADER_SIZE:
        raise SystemExit(f"{path}: unsupported VFLY1 header")
    if endian != 0x01020304 or weight_encoding != 1:
        raise SystemExit(f"{path}: unsupported endian/weight encoding")
    if len(raw) != HEADER_SIZE + payload_len:
        raise SystemExit(f"{path}: payload length mismatch")
    if hashlib.sha256(raw[HEADER_SIZE:]).digest() != payload_hash:
        raise SystemExit(f"{path}: payload sha256 mismatch")
    end = metadata_pos + metadata_len
    if metadata_pos < HEADER_SIZE or end > len(raw):
        raise SystemExit(f"{path}: metadata out of bounds")
    metadata = json.loads(raw[metadata_pos:end].decode("utf-8"))
    if metadata.get("format") != "VFLY1":
        raise SystemExit(f"{path}: wrong format")
    if metadata.get("dataset_id") != "male-cns:v1.0":
        raise SystemExit(f"{path}: wrong dataset")
    if metadata.get("tier") != expected_tier:
        raise SystemExit(f"{path}: tier {metadata.get('tier')} != {expected_tier}")
    return {
        "filename": path.name,
        "tier": expected_tier,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "byte_count": len(raw),
        "neuron_count": neurons,
        "edge_count": edges,
        "graph_id": metadata.get("graph_id"),
        "dataset_id": metadata.get("dataset_id"),
    }

core = pathlib.Path(sys.argv[1]).resolve()
lite = pathlib.Path(sys.argv[2]).resolve()
dest = pathlib.Path(sys.argv[3]).resolve()
dest.mkdir(parents=True, exist_ok=True)

# Validate the complete source pair before touching a previously good installation.
items = [inspect(core, "core"), inspect(lite, "lite")]
manifest = {
    "schema": "VeilFlyBundleAssets/1",
    "dataset_id": "male-cns:v1.0",
    "assets": items,
}

stage = pathlib.Path(tempfile.mkdtemp(prefix=".vfly-stage-", dir=dest))
backups = {}
committed = []
names = ("VeilFlyCore.vfly", "VeilFlyLite.vfly", "VeilFlyAssets.json")

try:
    shutil.copy2(core, stage / "VeilFlyCore.vfly")
    shutil.copy2(lite, stage / "VeilFlyLite.vfly")
    (stage / "VeilFlyAssets.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    # Re-verify the staged bytes, not only the source paths.
    inspect(stage / "VeilFlyCore.vfly", "core")
    inspect(stage / "VeilFlyLite.vfly", "lite")

    for name in names:
        p = stage / name
        with p.open("rb") as f:
            os.fsync(f.fileno())

    # Keep rollback copies of the current good installation.
    for name in names:
        current = dest / name
        if current.exists():
            backup = stage / f"backup-{name}"
            shutil.copy2(current, backup)
            backups[name] = backup

    try:
        # Same-filesystem replacement is atomic per file. Manifest commits last.
        for name in ("VeilFlyCore.vfly", "VeilFlyLite.vfly", "VeilFlyAssets.json"):
            os.replace(stage / name, dest / name)
            committed.append(name)

        directory_fd = os.open(dest, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except Exception:
        # Best-effort rollback for normal process failures.
        for name in reversed(committed):
            current = dest / name
            if name in backups:
                os.replace(backups[name], current)
            else:
                current.unlink(missing_ok=True)
        raise

    # Full/reference graph is build-host only.
    (dest / "MaleCNSReference.vfly").unlink(missing_ok=True)

    print(json.dumps(manifest, ensure_ascii=False, sort_keys=True))
    print("Atomic staged VFLY Core/Lite commit PASS")
finally:
    shutil.rmtree(stage, ignore_errors=True)
PY

[[ -s "$destination_dir/VeilFlyCore.vfly" && -s "$destination_dir/VeilFlyLite.vfly" ]]
[[ ! -e "$destination_dir/MaleCNSReference.vfly" ]]
echo "Injected verified MaleCNS Core/Lite assets into $destination_dir"
