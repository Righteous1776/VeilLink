#!/usr/bin/env python3
"""Verify Kimi K2 board assets; read-only by default, stage only with --stage.

Never writes to main, SwiftPM Resources, the game Engine, or any other lane.
"""
import argparse, hashlib, json, pathlib, subprocess, zipfile
ROOT=pathlib.Path("VEILOPOLY_DEV/INCOMING_ASSETS/KIMI_K2_BOARD_20261107")
PREFIX="Veilopoly_Kimi_K2_v1/"
def sha256(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()
def check_tile_data(compact, source):
    if len(compact["tiles"])!=40 or len(source["tiles"])!=40:
        raise ValueError("40-tile geometry missing")
    for i,(a,b) in enumerate(zip(compact["tiles"],source["tiles"])):
        fields=[(a["index"],b["i"]),(a["alias"],b["alias"]),
            (a["center_design_pt"],b["position_design_pt"]),
            (a["frame_px_top_origin"],b["atlas_frame_px"]),
            (a["display_pt"],b["display_size_local_pt"]),
            (a["rotation_deg"],b["z_rotation_deg"])]
        if a["id"]!=f"VL-K2-TILE-{i:03d}" or any(x!=y for x,y in fields):
            raise ValueError(f"tile {i} mapping mismatch")
        if any(abs(x-y)>1e-10 for x,y in zip(a["uv_bottom_origin"],b["uv_rect_bottom_origin"])):
            raise ValueError(f"tile {i} UV mismatch")
def main():
    p=argparse.ArgumentParser()
    p.add_argument("source_zip",type=pathlib.Path)
    p.add_argument("--repo",required=True,type=pathlib.Path)
    p.add_argument("--stage",action="store_true")
    a=p.parse_args()
    repo=a.repo.resolve()
    branch=subprocess.check_output(["git","branch","--show-current"],cwd=repo,text=True).strip()
    if branch!="dev/veilopoly":raise SystemExit("Must use dev/veilopoly")
    if not (repo/"VEILOPOLY_DEV/GOVERNANCE.md").is_file():raise SystemExit("Missing governance")
    folder=repo/ROOT
    lock=json.loads((folder/"KIMI_K2_SELECTED_ASSET_LOCK.json").read_text())
    compact=json.loads((folder/"KIMI_K2_TILE_MAP_40.json").read_text())
    if sha256(a.source_zip.read_bytes())!=lock["source_zip_sha256"]:
        raise SystemExit("ZIP SHA mismatch")
    pending=[]
    allowed=folder.resolve()
    if not allowed.is_relative_to((repo/"VEILOPOLY_DEV").resolve()):
        raise SystemExit("Staging root outside lane")
    with zipfile.ZipFile(a.source_zip) as z:
        if z.testzip() is not None:raise SystemExit("ZIP CRC failure")
        count=0
        for line in z.read(PREFIX+"SHA256SUMS.txt").decode().splitlines():
            if not line.strip():continue
            h,rel=line.split(maxsplit=1)
            if sha256(z.read(PREFIX+rel.lstrip("*")))!=h:
                raise SystemExit("SHA256SUMS mismatch "+rel)
            count+=1
        if count!=36:raise SystemExit("Unexpected checksum count")
        if len(lock["assets"])!=15:raise SystemExit("15 assets expected")
        for item in lock["assets"]:
            b=z.read(item["source_path"])
            if len(b)!=item["bytes"] or sha256(b)!=item["sha256"] or blob(b)!=item["expected_git_blob_sha1"]:
                raise SystemExit("Asset digest mismatch: "+item["id"])
            dest=(repo/item["stage_path"]).resolve()
            if not dest.is_relative_to(allowed):raise SystemExit("Illegal stage path")
            pending.append((dest,b))
        for src,name,key in [
            ("SPRITE_MAP.json","SOURCE_SPRITE_MAP.json","source_sprite_map_sha256"),
            ("ASSET_MANIFEST.json","SOURCE_ASSET_MANIFEST.json","source_manifest_sha256"),
            ("sources/board_model.json","SOURCE_BOARD_MODEL.json",None),
            ("sources/LICENSE.txt","SOURCE_LICENSE.txt",None)]:
            b=z.read(PREFIX+src)
            if key and sha256(b)!=lock[key]:raise SystemExit("Source hash mismatch")
            pending.append(((folder/name).resolve(),b))
        check_tile_data(compact,json.loads(z.read(PREFIX+"SPRITE_MAP.json")))
    for path,b in pending:
        if not path.is_relative_to(allowed):raise SystemExit("Illegal output path")
        if path.exists() and path.read_bytes()!=b:raise SystemExit("Refuse overwrite: "+str(path))
    if a.stage:
        for path,b in pending:
            if not path.exists():
                path.parent.mkdir(parents=True,exist_ok=True)
                path.write_bytes(b)
    print(json.dumps({"result":"PASS","mode":"STAGED" if a.stage else "READ_ONLY",
        "assets":15,"sha256sums":36,"tiles":40,"files_checked":len(pending)}))
if __name__=="__main__":main()
