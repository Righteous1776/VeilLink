#!/usr/bin/env python3
"""Verify official Monogatari release BYTES; never substitute a fake runtime.

Writes no product files. Optional --extract extracts pristine upstream assets
ONLY into an explicit location AFTER verification. No IPA build or release.
"""
import argparse
import hashlib
import io
import json
import pathlib
import stat
import sys
import urllib.request
import zipfile

LOCK = json.loads((pathlib.Path(__file__).parent / "VENDOR_LOCK.json").read_text())
def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
def get_bytes(p):
    if p is not None:
        return p.read_bytes()
    errs = []
    for url in (LOCK["assetURL"], LOCK["officialPublisherMirror"]):
        try:
            with urllib.request.urlopen(url, timeout=40) as resp:
                b = resp.read(15000001)
            if hashlib.sha256(b).hexdigest() == LOCK["releaseSHA256"]:
                return b
            errs.append("digest mismatch from " + url)
        except Exception as e:
            errs.append(type(e).__name__ + " from " + url)
    sys.exit("NO_VERIFIED_RELEASE_DOWNLOAD: " + "; ".join(errs))
def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-zip", type=pathlib.Path)
    parser.add_argument("--extract", type=pathlib.Path, help="pristine upstream extraction, optional")
    args = parser.parse_args()
    b = get_bytes(args.release_zip)
    got = hashlib.sha256(b).hexdigest()
    if len(b) != LOCK["releaseBytes"] or got != LOCK["releaseSHA256"]:
        sys.exit("PIN_MISMATCH: size=" + str(len(b)) + " sha256=" + got)
    with zipfile.ZipFile(io.BytesIO(b)) as z:
        files = [i for i in z.infolist() if not i.is_dir()]
        names = [i.filename for i in files]
        if len(names) != len(set(names)) or len(files)>5000 or sum(i.file_size for i in files)>150000000:
            sys.exit("BAD_ARCHIVE_LIMITS_OR_DUPLICATES")
        candidates=[name[:-10] for name in names if name.endswith("index.html") and
          name[:-10]+"engine/core/monogatari.js" in names and name[:-10]+"js/options.js" in names]
        if len(candidates)!=1: sys.exit("COMPLETE_RUNTIME_ROOT_NOT_UNIQUE")
        root = candidates[0]
        checks={"engine/core/monogatari.js":LOCK["compiledBrowserCoreGitBlob"],
                "engine/core/monogatari.css":LOCK["compiledCSSGitBlob"]}
        for file,sha in checks.items():
            raw = z.read(root+file)
            if git_blob(raw)!=sha: sys.exit("GIT_BLOB_MISMATCH: "+file)
        for info in files:
            if not info.filename.startswith(root): continue
            rel=info.filename[len(root):]
            pp=pathlib.PurePosixPath(rel)
            mode=info.external_attr>>16
            if (not rel or rel.startswith("/") or "\\\\" in rel or ":" in rel or
                any(p in ("..", ".") for p in pp.parts) or
                stat.S_ISLNK(mode) or info.file_size>30000000):
                sys.exit("UNSAFE_ARCHIVE_PATH: "+rel)
        if args.extract:
            output = args.extract.resolve()
            if output.exists() or output.is_symlink():
                sys.exit("EXTRACT_OUTPUT_MUST_NOT_EXIST")
            output.mkdir(parents=True)
            for info in files:
                if not info.filename.startswith(root): continue
                rel=info.filename[len(root):]
                target=output.joinpath(*pathlib.PurePosixPath(rel).parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(z.read(info))
        print(json.dumps({"status":"VERIFIED_OFFICIAL_BYTES","zipSHA256":got,
         "bytes":len(b),"entries":len(files),"extracted":bool(args.extract)}, indent=2))
if __name__ == "__main__": run()
