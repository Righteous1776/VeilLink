#!/usr/bin/env python3
"""Read-only by default. Audit Kimi cumulative ZIP and optionally stage K2–K4 inputs on dev/veilopoly."""
import argparse, hashlib, json, subprocess, zipfile
from pathlib import Path

CANDIDATES = {
 "kimiBoardBase": "K2/assets/board/board-base.png",
 "kimiTokenPawnBlue": "K2/assets/tokens/token-pawn-blue-512.png",
 "kimiTokenCarRed": "K2/assets/tokens/token-car-red-512.png",
 "kimiTokenShipGreen": "K2/assets/tokens/token-ship-green-512.png",
 "kimiTokenPlaneYellow": "K2/assets/tokens/token-plane-yellow-512.png",
 "kimiTileRail": "K2/assets/tiles/icon-rail.png",
 "kimiTileTax": "K2/assets/tiles/icon-tax.png",
 "kimiTileChance": "K2/assets/tiles/icon-chance.png",
 "kimiFxTilePulseAtlas": "K2/assets/effects/fxTilePulseAtlas.png",
 "kimiFxCashChipAtlas": "K2/assets/effects/fxCashChipAtlas.png",
 "kimiFxPawnShadowAtlas": "K2/assets/effects/fxPawnShadowAtlas.png",
 "kimiFxTurnBanner": "K2/assets/effects/fxTurnBanner.png",
 "kimiFxVictoryBadge": "K2/assets/effects/fxVictoryBadge.png",
 "kimiCardFaceFrame": "K2/assets/cards/uiCardFaceFrame.png",
}
STAGING_ONLY = {
 "kimiStarBadge": "K3/assets/star-badge.png",
 "kimiChestGreen": "K3/assets/chest-green.png",
 "kimiHouseRed": "K3/assets/house-red.png",
 "kimiHouseGreen": "K3/assets/house-green.png",
}
DOCS = [
 "K2/docs/SKIN_EXPORT.md", "K2/docs/TOKEN_SPEC.md",
 "K2/assets/effects/fx-atlas-meta.json", "K3/docs/HUD_SPEC.md",
 "K4/docs/THEME_LIGHT.md", "K4/previews/iphone-landscape/k4-01-light-main.png",
 "K4/previews/ipad-landscape/k4-02-ipad-bank.png",
]
def sha(data): return hashlib.sha256(data).hexdigest()
def main():
 parser=argparse.ArgumentParser()
 parser.add_argument("zip", type=Path)
 parser.add_argument("--apply", action="store_true")
 args=parser.parse_args()
 repo=Path(__file__).resolve().parents[2]
 if args.apply:
  branch=subprocess.check_output(["git","branch","--show-current"],cwd=repo,text=True).strip()
  if branch!="dev/veilopoly" or not (repo/"VEILOPOLY_DEV/GOVERNANCE.md").is_file():
   raise SystemExit("Refusing to stage outside authorized dev/veilopoly checkout")
 with zipfile.ZipFile(args.zip) as z:
  bad=z.testzip()
  if bad is not None: raise SystemExit("ZIP CRC mismatch: "+bad)
  checks={}
  for k in ("K1","K2","K3","K4"):
   lines=z.read(k+"/SHA256SUMS.txt").decode().splitlines()
   for line in lines:
    digest,path=line.split(maxsplit=1)
    member=k+"/"+path.lstrip("*")
    if sha(z.read(member))!=digest:
     raise SystemExit("SHA256 mismatch: "+member)
   checks[k]=len(lines)
  manifests={}
  for k in ("K2","K3","K4"):
   for entry in json.loads(z.read(k+"/ASSET_MANIFEST.json"))["items"]:
    manifests[k+"/"+entry["path"]]=entry
  rows=[]
  for alias,member in {**CANDIDATES,**STAGING_ONLY}.items():
   data=z.read(member)
   if sha(data)!=manifests[member]["sha256"]:
    raise SystemExit("Asset-manifest SHA mismatch: "+member)
   rows.append({"alias":alias,"source":member,"bytes":len(data),
                "sha256":sha(data),"stage_only":alias in STAGING_ONLY})
  for f in DOCS: z.read(f)
  result={"source_sha256":sha(args.zip.read_bytes()),"checks":checks,"selected":rows}
  if args.apply:
   dest=repo/"VEILOPOLY_DEV/INCOMING_ASSETS/KIMI_K2K4_20261106"
   for member in [x["source"] for x in rows]+DOCS:
    out=dest/member
    payload=z.read(member)
    if out.exists() and out.read_bytes()!=payload:
     raise SystemExit("Existing file differs; refusing overwrite: "+str(out))
    out.parent.mkdir(parents=True,exist_ok=True)
    if not out.exists(): out.write_bytes(payload)
   (dest/"VALIDATED_SELECTION.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
  print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=="__main__": main()
