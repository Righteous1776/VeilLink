#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
mode=""
source_dir=""
vfly_dir=""
output_dir=""
inject=1

usage() {
  cat >&2 <<'EOF'
usage:
  install-vfly-assets.sh --from-prebuilt DIR [--output-dir DIR] [--no-inject]
  install-vfly-assets.sh --from-vfly DIR [--output-dir DIR] [--no-inject]
  install-vfly-assets.sh --fetch-prebuilt [--output-dir DIR] [--no-inject]

--from-prebuilt DIR  requires pinned brain.npz + weights.npz and rebuilds Reference/Core/Lite.
--from-vfly DIR       verifies an existing VeilFlyCore.vfly + VeilFlyLite.vfly pair.
--fetch-prebuilt      downloads only the pinned public prebuilt files, verifies SHA-256, then rebuilds.
--output-dir DIR      stage verified Core/Lite + sidecars/provenance here (default: .local-vfly/out).
--no-inject           do not copy Core/Lite into VeilLink/Resources.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-prebuilt) mode="prebuilt"; source_dir="${2:-}"; shift 2 ;;
    --from-vfly) mode="vfly"; vfly_dir="${2:-}"; shift 2 ;;
    --fetch-prebuilt) mode="fetch"; shift ;;
    --output-dir) output_dir="${2:-}"; shift 2 ;;
    --no-inject) inject=0; shift ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done
[[ -n "$mode" ]] || usage

builder="$repo_root/Tools/VeilFlyBuilder"
inject_script="$repo_root/scripts/inject-vfly-assets.sh"
verify_installed="$repo_root/scripts/verify-vfly-installed.py"
lock_file="$repo_root/scripts/vfly-source-lock.json"
[[ -x "$inject_script" || -f "$inject_script" ]] || { echo "inject-vfly-assets.sh missing" >&2; exit 3; }
[[ -f "$verify_installed" ]] || { echo "verify-vfly-installed.py missing" >&2; exit 3; }
[[ -f "$lock_file" ]] || { echo "vfly-source-lock.json missing" >&2; exit 3; }
if [[ "$mode" != "vfly" ]]; then
  [[ -f "$builder/fetch_malecns.py" && -f "$builder/export_vfly.py" && -f "$builder/build_subgraph.py" && -f "$builder/verify_vfly.py" && -f "$builder/provenance.py" ]] || { echo "VeilFlyBuilder missing/incomplete" >&2; exit 3; }
fi

output_dir="${output_dir:-$repo_root/.local-vfly/out}"
mkdir -p "$output_dir"
work="$repo_root/.local-vfly/work"
mkdir -p "$work"

verify_source() {
  local dir="$1"
  python3 - "$dir" "$lock_file" <<'PY'
import hashlib,json,pathlib,sys
src=pathlib.Path(sys.argv[1]); lock=json.loads(pathlib.Path(sys.argv[2]).read_text())
for name,spec in lock['prebuilt_files'].items():
    p=src/name
    if not p.is_file(): raise SystemExit(f'missing {p}')
    if p.stat().st_size != int(spec['byte_count']): raise SystemExit(f'{name} byte_count mismatch')
    h=hashlib.sha256()
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1<<20),b''): h.update(c)
    if h.hexdigest()!=spec['sha256']: raise SystemExit(f'{name} sha256 mismatch: {h.hexdigest()}')
print('Pinned MaleCNS prebuilt source verification PASS')
PY
}

build_from_source() {
  local src="$1"
  verify_source "$src"
  python3 - <<'PY'
import importlib.util
for m in ('numpy','scipy'):
    if importlib.util.find_spec(m) is None: raise SystemExit(f'missing Python dependency: {m}; install Tools/VeilFlyBuilder/requirements.txt')
PY
  rm -f "$work/MaleCNSReference.vfly" "$work/VeilFlyCore.vfly" "$work/VeilFlyLite.vfly"
  PYTHONPATH="$builder" python3 "$builder/export_vfly.py" --data "$src" --output "$work/MaleCNSReference.vfly" --tier reference
  PYTHONPATH="$builder" python3 "$builder/verify_vfly.py" "$work/MaleCNSReference.vfly" --expect-neurons 166700 --expect-edges 25582938 --expect-tier reference --expect-dataset male-cns:v1.0
  PYTHONPATH="$builder" python3 "$builder/build_subgraph.py" --input "$work/MaleCNSReference.vfly" --tier core --hops 5 --max-nodes 48000 --min-abs-weight 0.001 --output "$work/VeilFlyCore.vfly"
  PYTHONPATH="$builder" python3 "$builder/build_subgraph.py" --input "$work/MaleCNSReference.vfly" --tier lite --hops 4 --max-nodes 12000 --min-abs-weight 0.002 --output "$work/VeilFlyLite.vfly"
  PYTHONPATH="$builder" python3 "$builder/verify_vfly.py" "$work/VeilFlyCore.vfly" --expect-tier core --expect-dataset male-cns:v1.0
  PYTHONPATH="$builder" python3 "$builder/verify_vfly.py" "$work/VeilFlyLite.vfly" --expect-tier lite --expect-dataset male-cns:v1.0
  PYTHONPATH="$builder" python3 "$builder/provenance.py" --output "$work/PROVENANCE.json" \
    --artifact "$work/MaleCNSReference.vfly" --artifact "$work/VeilFlyCore.vfly" --artifact "$work/VeilFlyLite.vfly" \
    --command 'source SHA verification' --command 'export_vfly.py --tier reference' \
    --command 'build_subgraph.py --tier core' --command 'build_subgraph.py --tier lite'
  cp "$work/VeilFlyCore.vfly" "$work/VeilFlyCore.vfly.manifest.json" "$work/VeilFlyLite.vfly" "$work/VeilFlyLite.vfly.manifest.json" "$work/PROVENANCE.json" "$output_dir/"
}

if [[ "$mode" == "fetch" ]]; then
  source_dir="$repo_root/.local-vfly/source"
  mkdir -p "$source_dir"
  PYTHONPATH="$builder" python3 "$builder/fetch_malecns.py" --mode prebuilt --dest "$source_dir"
  build_from_source "$source_dir"
elif [[ "$mode" == "prebuilt" ]]; then
  [[ -d "$source_dir" ]] || { echo "source directory not found: $source_dir" >&2; exit 4; }
  build_from_source "$source_dir"
else
  [[ -d "$vfly_dir" ]] || { echo "VFLY directory not found: $vfly_dir" >&2; exit 4; }
  python3 - "$vfly_dir" <<'PY'
import hashlib,json,pathlib,struct,sys
MAGIC=b"VFLY1\0\0\0"; H=struct.Struct("<8sIIIIIIIIQQQQQQQQ32s"); HS=H.size
def check(p,tier):
    raw=p.read_bytes()
    if len(raw)<HS: raise SystemExit(f'{p}: truncated')
    v=H.unpack_from(raw,0)
    magic,ver,hs,endian,enc,neurons,edges,groups,members,*rest=v
    metadata_pos,metadata_len,payload_len,payload_hash=rest[-4:]
    if magic!=MAGIC or ver!=1 or hs!=HS or endian!=0x01020304 or enc!=1: raise SystemExit(f'{p}: invalid VFLY1 header')
    if len(raw)!=HS+payload_len or hashlib.sha256(raw[HS:]).digest()!=payload_hash: raise SystemExit(f'{p}: payload verification failed')
    md=json.loads(raw[metadata_pos:metadata_pos+metadata_len].decode())
    if md.get('format')!='VFLY1' or md.get('dataset_id')!='male-cns:v1.0' or md.get('tier')!=tier: raise SystemExit(f'{p}: metadata mismatch')
    print(f'{p.name}: {tier} PASS neurons={neurons} edges={edges}')
d=pathlib.Path(sys.argv[1]); check(d/'VeilFlyCore.vfly','core'); check(d/'VeilFlyLite.vfly','lite')
PY
  cp "$vfly_dir/VeilFlyCore.vfly" "$vfly_dir/VeilFlyLite.vfly" "$output_dir/"
  [[ -f "$vfly_dir/VeilFlyCore.vfly.manifest.json" ]] && cp "$vfly_dir/VeilFlyCore.vfly.manifest.json" "$output_dir/"
  [[ -f "$vfly_dir/VeilFlyLite.vfly.manifest.json" ]] && cp "$vfly_dir/VeilFlyLite.vfly.manifest.json" "$output_dir/"
  [[ -f "$vfly_dir/PROVENANCE.json" ]] && cp "$vfly_dir/PROVENANCE.json" "$output_dir/"
fi

if [[ "$inject" -eq 1 ]]; then
  bash "$inject_script" "$output_dir" "$repo_root/VeilLink/Resources"
  python3 "$verify_installed" "$repo_root/VeilLink/Resources" --json-out "$repo_root/VeilLink/Resources/VFLYInstallationVerification.json"
fi

echo "VFLY install closure PASS"
echo "staged=$output_dir"
echo "injected=$inject"
