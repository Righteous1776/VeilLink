#!/usr/bin/env python3
"""Fail-closed validation of the exact Vertex 35M GGUF before build/use."""
import hashlib
import pathlib
import struct
import sys

EXPECTED_BYTES = 29203168
EXPECTED_SHA256 = "c55c3c32740d5a283c505fc9f9b7313e4b3f0c98bb11efd21b651651d5cb36b5"
ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_PATH = ROOT / "VeilLink/Resources/LocalAI/Vertex-0.6-35M-Instruct-Q4_K_M.gguf"

def main():
    path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PATH
    if not path.is_file() or path.stat().st_size != EXPECTED_BYTES:
        raise SystemExit(f"Wrong model size/file: {path}")
    with path.open("rb") as handle:
        if handle.read(8) != b"GGUF" + struct.pack("<I", 3):
            raise SystemExit("Not GGUF version 3")
        handle.seek(0)
        h = hashlib.sha256()
        for piece in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(piece)
    actual = h.hexdigest()
    if actual != EXPECTED_SHA256:
        raise SystemExit(f"Wrong model SHA-256: {actual}")
    print(f"VERTEX35M_MODEL_VALIDATED bytes={EXPECTED_BYTES} sha256={actual}")

if __name__ == "__main__":
    main()
