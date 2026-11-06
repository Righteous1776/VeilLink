#!/usr/bin/env python3
"""Kimi K2 2.5D board source archive -> scoped GitHub staging checkout (never runtime / main)."""
import argparse,hashlib,json,pathlib,subprocess,zipfile
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(("blob "+str(len(b))+"\0").encode()+b).hexdigest()
def main():
 p=argparse.ArgumentParser()
 p.add_argument("source_zip",type=pathlib.Path)
 p.add_argument("--repo",required=True,type=pathlib.Path)
 p.add_argument("--dry-run",action="store_true")
 a=p.parse_args();repo=a.repo.resolve()
 branch=subprocess.check_output(["git","branch","--show-current"],cwd=repo,text=True).strip()
 if branch!="dev/veilopoly":raise SystemExit("Must be dev/veilopoly")
 if not (repo/"VEILOPOLY_DEV/GOVERNANCE.md").is_file():raise SystemExit("Missing governance root")
 lock_path=repo/"VEILOPOLY_DEV/INCOMING_ASSETS/KIMI_K2_BOARD_20261107/KIMI_K2_SELECTED_ASSET_LOCK.json"
 lock=json.loads(lock_path.read_text())
 if sha(a.source_zip.read_bytes())!=lock["source_zip_sha256"]:raise SystemExit("Source ZIP SHA-256 mismatch")
 with zipfile.ZipFile(a.source_zip) as z:
  bad=z.testzip()
  if bad:raise SystemExit("ZIP CRC failed: "+bad)
  prefix="Veilopoly_Kimi_K2_v1/"
  for line in z.read(prefix+"SHA256SUMS.txt").decode().splitlines():
   if not line.strip():continue
   digest,member=line.split(maxsplit=1)
   if sha(z.read(prefix+member.lstrip("*")))!=digest:raise SystemExit("Source checksum mismatch: "+member)
  # Preflight every selection before writing even one file.
  pending=[]
  for asset in lock["assets"]:
   payload=z.read(asset["source_path"])
   if (len(payload)!=asset["bytes"] or sha(payload)!=asset["sha256"] or
       blob(payload)!=asset["expected_git_blob_sha1"]):
    raise SystemExit("Asset hash, bytes or Git blob mismatch: "+asset["id"])
   dst=repo/asset["stage_path"]
   if dst.exists() and sha(dst.read_bytes())!=asset["sha256"]:
    raise SystemExit("Conflicting destination: "+str(dst))
   pending.append((dst,payload))
  for dst,payload in pending:
   if not a.dry_run and not dst.exists():
    dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(payload)
  for member,name in [("SPRITE_MAP.json","SOURCE_SPRITE_MAP.json"),
                      ("ASSET_MANIFEST.json","SOURCE_ASSET_MANIFEST.json"),
                      ("sources/board_model.json","SOURCE_BOARD_MODEL.json")]:
   b=z.read(prefix+member)
   dst=lock_path.parent/name
   if dst.exists() and dst.read_bytes()!=b:raise SystemExit("Source mapping differs: "+str(dst))
   if not a.dry_run and not dst.exists():dst.write_bytes(b)
 print("CHECKED:",len(pending),"PNGs; stage dry-run:",a.dry_run)
 print("No SpriteKit activation, no Engine/Net/main, no IPA or release.")
if __name__=="__main__":main()
