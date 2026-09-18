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
rm -f "$destination_dir/VeilFlyCore.vfly" "$destination_dir/VeilFlyLite.vfly" "$destination_dir/MaleCNSReference.vfly"

python3 - "$core" "$lite" "$destination_dir" <<'PY'
import hashlib, json, pathlib, shutil, struct, sys

MAGIC=b"VFLY1\0\0\0"
HEADER=struct.Struct("<8sIIIIIIIIQQQQQQQQ32s")
HEADER_SIZE=HEADER.size

def inspect(path: pathlib.Path, expected_tier: str):
    raw=path.read_bytes()
    if len(raw) < HEADER_SIZE:
        raise SystemExit(f"{path}: truncated")
    values=HEADER.unpack_from(raw,0)
    (magic,version,header_size,endian,weight_encoding,neurons,edges,groups,members,
     offsets_pos,targets_pos,weights_pos,group_offsets_pos,group_neurons_pos,
     metadata_pos,metadata_len,payload_len,payload_hash)=values
    if magic != MAGIC or version != 1 or header_size != HEADER_SIZE or endian != 0x01020304 or weight_encoding != 1:
        raise SystemExit(f"{path}: unsupported VFLY1 header")
    if len(raw) != HEADER_SIZE + payload_len:
        raise SystemExit(f"{path}: payload length mismatch")
    if hashlib.sha256(raw[HEADER_SIZE:]).digest() != payload_hash:
        raise SystemExit(f"{path}: payload sha256 mismatch")
    end=metadata_pos+metadata_len
    if metadata_pos < HEADER_SIZE or end > len(raw):
        raise SystemExit(f"{path}: metadata out of bounds")
    metadata=json.loads(raw[metadata_pos:end].decode("utf-8"))
    if metadata.get("format") != "VFLY1" or metadata.get("dataset_id") != "male-cns:v1.0":
        raise SystemExit(f"{path}: wrong dataset/format")
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

core=pathlib.Path(sys.argv[1]); lite=pathlib.Path(sys.argv[2]); dest=pathlib.Path(sys.argv[3])
items=[inspect(core,"core"), inspect(lite,"lite")]
for src in (core,lite): shutil.copy2(src,dest/src.name)
manifest={"schema":"VeilFlyBundleAssets/1","dataset_id":"male-cns:v1.0","assets":items}
(dest/"VeilFlyAssets.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")
print(json.dumps(manifest,ensure_ascii=False,sort_keys=True))
PY

[[ -s "$destination_dir/VeilFlyCore.vfly" && -s "$destination_dir/VeilFlyLite.vfly" ]]
[[ ! -e "$destination_dir/MaleCNSReference.vfly" ]]
echo "Injected verified MaleCNS Core/Lite assets into $destination_dir"
