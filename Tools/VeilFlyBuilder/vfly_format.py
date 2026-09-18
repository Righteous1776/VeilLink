from __future__ import annotations

import hashlib
import json
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping

import numpy as np

MAGIC = b"VFLY1\0\0\0"
FORMAT_VERSION = 1
ENDIAN_MARKER = 0x01020304
WEIGHT_F32 = 1
HEADER_STRUCT = struct.Struct("<8sIIIIIIIIQQQQQQQQ32s")
HEADER_SIZE = HEADER_STRUCT.size

@dataclass(frozen=True)
class VFlyArtifact:
    neuron_count: int
    edge_count: int
    offsets: np.ndarray
    targets: np.ndarray
    weights: np.ndarray
    group_names: list[str]
    group_kinds: list[str]
    group_offsets: np.ndarray
    group_neurons: np.ndarray
    metadata: dict


def _u32(values: Iterable[int]) -> np.ndarray:
    return np.asarray(values, dtype="<u4")


def _f32(values: Iterable[float]) -> np.ndarray:
    return np.asarray(values, dtype="<f4")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_vfly(
    output: Path,
    *,
    offsets: np.ndarray,
    targets: np.ndarray,
    weights: np.ndarray,
    groups: Mapping[str, tuple[str, np.ndarray]],
    metadata: dict,
) -> dict:
    offsets = _u32(offsets)
    targets = _u32(targets)
    weights = _f32(weights)
    if targets.size != weights.size:
        raise ValueError("targets/weights size mismatch")
    if offsets.ndim != 1 or offsets.size < 2:
        raise ValueError("invalid offsets")
    neuron_count = int(offsets.size - 1)
    edge_count = int(targets.size)
    if int(offsets[0]) != 0 or int(offsets[-1]) != edge_count:
        raise ValueError("offsets do not span edge table")
    if np.any(offsets[1:] < offsets[:-1]):
        raise ValueError("offsets not monotonic")
    if edge_count and int(targets.max()) >= neuron_count:
        raise ValueError("target out of range")

    names = list(groups)
    kinds: list[str] = []
    group_offsets = [0]
    group_neurons: list[int] = []
    for name in names:
        kind, members = groups[name]
        members = _u32(members)
        if members.size and int(members.max()) >= neuron_count:
            raise ValueError(f"group {name} has out-of-range neuron")
        kinds.append(kind)
        group_neurons.extend(int(x) for x in members)
        group_offsets.append(len(group_neurons))

    group_offsets_arr = _u32(group_offsets)
    group_neurons_arr = _u32(group_neurons)
    metadata = dict(metadata)
    metadata.update({
        "format": "VFLY1",
        "format_version": FORMAT_VERSION,
        "neuron_count": neuron_count,
        "edge_count": edge_count,
        "weight_encoding": "float32-le",
        "group_names": names,
        "group_kinds": kinds,
        "group_member_count": int(group_neurons_arr.size),
    })
    metadata_bytes = json.dumps(metadata, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")

    cursor = HEADER_SIZE
    offsets_pos = cursor; cursor += offsets.nbytes
    targets_pos = cursor; cursor += targets.nbytes
    weights_pos = cursor; cursor += weights.nbytes
    group_offsets_pos = cursor; cursor += group_offsets_arr.nbytes
    group_neurons_pos = cursor; cursor += group_neurons_arr.nbytes
    metadata_pos = cursor; cursor += len(metadata_bytes)

    # Payload hash excludes the header so it can be computed before the final header is written.
    payload = b"".join([
        offsets.tobytes(order="C"),
        targets.tobytes(order="C"),
        weights.tobytes(order="C"),
        group_offsets_arr.tobytes(order="C"),
        group_neurons_arr.tobytes(order="C"),
        metadata_bytes,
    ])
    payload_hash = hashlib.sha256(payload).digest()
    header = HEADER_STRUCT.pack(
        MAGIC,
        FORMAT_VERSION,
        HEADER_SIZE,
        ENDIAN_MARKER,
        WEIGHT_F32,
        neuron_count,
        edge_count,
        len(names),
        int(group_neurons_arr.size),
        offsets_pos,
        targets_pos,
        weights_pos,
        group_offsets_pos,
        group_neurons_pos,
        metadata_pos,
        len(metadata_bytes),
        len(payload),
        payload_hash,
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as fh:
        fh.write(header)
        fh.write(payload)

    return {
        "path": str(output),
        "byte_count": output.stat().st_size,
        "sha256": sha256_file(output),
        "payload_sha256": payload_hash.hex(),
        "neuron_count": neuron_count,
        "edge_count": edge_count,
        "group_count": len(names),
        "group_member_count": int(group_neurons_arr.size),
    }


def read_vfly(path: Path, verify_hash: bool = True) -> VFlyArtifact:
    raw = path.read_bytes()
    if len(raw) < HEADER_SIZE:
        raise ValueError("file too small")
    values = HEADER_STRUCT.unpack_from(raw, 0)
    (
        magic, version, header_size, endian, weight_encoding,
        neuron_count, edge_count, group_count, membership_count,
        offsets_pos, targets_pos, weights_pos, group_offsets_pos,
        group_neurons_pos, metadata_pos, metadata_len, payload_len, payload_hash,
    ) = values
    if magic != MAGIC or version != FORMAT_VERSION or header_size != HEADER_SIZE:
        raise ValueError("unsupported VFLY header")
    if endian != ENDIAN_MARKER or weight_encoding != WEIGHT_F32:
        raise ValueError("unsupported VFLY encoding")
    if len(raw) != HEADER_SIZE + payload_len:
        raise ValueError("payload length mismatch")
    payload = raw[HEADER_SIZE:]
    if verify_hash and hashlib.sha256(payload).digest() != payload_hash:
        raise ValueError("payload sha256 mismatch")

    def take_u32(pos: int, count: int) -> np.ndarray:
        end = pos + count * 4
        if pos < HEADER_SIZE or end > len(raw): raise ValueError("section out of range")
        return np.frombuffer(raw, dtype="<u4", count=count, offset=pos).copy()

    offsets = take_u32(offsets_pos, neuron_count + 1)
    targets = take_u32(targets_pos, edge_count)
    w_end = weights_pos + edge_count * 4
    if weights_pos < HEADER_SIZE or w_end > len(raw): raise ValueError("weights out of range")
    weights = np.frombuffer(raw, dtype="<f4", count=edge_count, offset=weights_pos).copy()
    group_offsets = take_u32(group_offsets_pos, group_count + 1)
    group_neurons = take_u32(group_neurons_pos, membership_count)
    md_end = metadata_pos + metadata_len
    if metadata_pos < HEADER_SIZE or md_end > len(raw): raise ValueError("metadata out of range")
    metadata = json.loads(raw[metadata_pos:md_end].decode("utf-8"))
    names = list(metadata.get("group_names", []))
    kinds = list(metadata.get("group_kinds", []))
    if len(names) != group_count or len(kinds) != group_count:
        raise ValueError("group metadata mismatch")
    if int(offsets[-1]) != edge_count or int(group_offsets[-1]) != membership_count:
        raise ValueError("section count mismatch")
    if edge_count and int(targets.max()) >= neuron_count:
        raise ValueError("target out of range")
    if membership_count and int(group_neurons.max()) >= neuron_count:
        raise ValueError("group member out of range")
    return VFlyArtifact(
        neuron_count=neuron_count,
        edge_count=edge_count,
        offsets=offsets,
        targets=targets,
        weights=weights,
        group_names=names,
        group_kinds=kinds,
        group_offsets=group_offsets,
        group_neurons=group_neurons,
        metadata=metadata,
    )
