#!/usr/bin/env python3
"""Fail-closed R8-compatible vs R14 native color-swapped arena JSONL.

Standalone / standard-library only. Inputs must be recorded full games, never
classifier rows or hypothetical positions. This gates evidence, not shipping.
"""
import argparse
import hashlib
import json
import math
import random
from collections import defaultdict
from pathlib import Path


def is_five(board, last, stone):
    row, col = divmod(last, 15)
    for dr, dc in ((0, 1), (1, 0), (1, 1), (1, -1)):
        count = 1
        for sign in (-1, 1):
            rr, cc = row + dr * sign, col + dc * sign
            while 0 <= rr < 15 and 0 <= cc < 15 and board[rr * 15 + cc] == stone:
                count += 1
                rr += dr * sign
                cc += dc * sign
        if count >= 5:
            return True
    return False


def audit_game(row):
    if row.get("invalid") or row.get("result") in ("capped", "invalid"):
        raise ValueError("invalid/capped evidence cannot qualify")
    if row.get("schema") != "veillink.r8-vs-r14.native-paired-arena.v1":
        raise ValueError("wrong/missing live-arena schema")
    if row.get("baseline") != "R8-compat-disabled-unified":
        raise ValueError("baseline provenance mismatch")
    if row.get("challenger") != "R14-frozen-native-pvs-enabled":
        raise ValueError("candidate provenance mismatch")
    side = row["trainedSide"]
    if side not in (1, 2):
        raise ValueError("trainedSide must be 1 or 2")
    moves = row["moves"]
    presets = row["presets"]
    if row["presetPlies"] != len(presets) or moves[:len(presets)] != presets:
        raise ValueError("preset journal mismatch")
    board = [0] * 225
    winner = 0
    for ply, index in enumerate(moves):
        if type(index) is not int or not 0 <= index < 225 or board[index] or winner:
            raise ValueError("illegal or post-terminal move")
        stone = ply % 2 + 1
        board[index] = stone
        if is_five(board, index, stone):
            winner = stone
    if winner != row["winner"]:
        raise ValueError("winner is not rule-derived")
    expected = ("trainedWon" if winner == side else "baselineWon") if winner else ("draw" if len(moves) == 225 else "capped")
    if expected != row["result"]:
        raise ValueError("result mismatch")
    diag = row["decisions"]
    if len(diag) != len(moves) - len(presets):
        raise ValueError("decision count mismatch")
    count_unified = 0
    count_fallback = 0
    for ply, decision in enumerate(diag, len(presets)):
        candidate = decision["side"] == side
        if decision.get("candidate") is not candidate:
            raise ValueError("candidate flag does not match side assignment")
        if candidate:
            count_unified += int(decision.get("engineLabel") is not None)
            count_fallback += int(decision.get("engineLabel") is None)
        if (decision.get("milliseconds", -1) < 0 or decision.get("nodes", -1) < 0):
            raise ValueError("invalid timing or node count")
        if decision["index"] != moves[ply] or decision["side"] != ply % 2 + 1:
            raise ValueError("decision/turn mismatch")
    if row.get("countUnified") != count_unified or row.get("countFallback") != count_fallback:
        raise ValueError("reported candidate engine routing mismatch")
    return 1.0 if expected == "trainedWon" else 0.5 if expected == "draw" else 0.0


def assess(paths, *, bootstrap=10000, seed=1941, min_pairs=30):
    files = {}
    seen = {}
    groups = defaultdict(list)
    for path in paths:
        data = path.read_bytes()
        files[str(path)] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        for num, line in enumerate(data.splitlines(), 1):
            if not line.strip():
                continue
            row = json.loads(line)
            key = (row["seed"], row["pair"], row["trainedSide"])
            if key in seen:
                raise ValueError(f"duplicate (seed,pair,color): {key}")
            seen[key] = (str(path), num)
            try:
                score = audit_game(row)
            except Exception as exc:
                raise ValueError(f"{path}:{num}: {exc}") from exc
            groups[key[:2]].append((row, score))
    values = []
    routed = {"unified": 0, "fallback": 0}
    decision_times = {"candidate": [], "baseline": []}
    for key, entries in groups.items():
        if len(entries) != 2 or {row["trainedSide"] for row, _ in entries} != {1, 2}:
            raise ValueError(f"unpaired/same-color opening: {key}")
        if entries[0][0]["presets"] != entries[1][0]["presets"]:
            raise ValueError(f"nonmatching opening preset: {key}")
        for row, _ in entries:
            for decision in row["decisions"]:
                decision_times["candidate" if decision["candidate"] else "baseline"].append(decision["milliseconds"])
            routed["unified"] += row["countUnified"]
            routed["fallback"] += row["countFallback"]
        values.append(sum(s for _, s in entries) / 2)
    if len(values) < min_pairs:
        raise ValueError(f"insufficient independent opening pairs: {len(values)} < {min_pairs}")
    point_rate = sum(values) / len(values)
    rng = random.Random(seed)
    n = len(values)
    samples = sorted(sum(rng.choices(values, k=n)) / n for _ in range(bootstrap))
    lower, upper = samples[math.floor(bootstrap * .025)], samples[min(bootstrap - 1, math.ceil(bootstrap * .975) - 1)]
    def timing_summary(times):
        if not times:
            return {"n": 0}
        times.sort()
        return {"n": len(times), "meanMs": round(sum(times) / len(times), 3),
                "medianMs": times[(len(times)-1)//2], "p95Ms": times[math.ceil(len(times)*.95)-1],
                "maxMs": times[-1]}
    status = ("NO_R14_UNIFIED_SEARCH_EXERCISED" if routed["unified"] == 0 else
              "SUPPORTED_AT_TESTED_BUDGET" if lower > .5 else "SUPERIORITY_NOT_ESTABLISHED")
    return {"status": status,
            "scope": "paired native-game evidence; no Elo/sixfold-ability/generalization claim",
            "openingPairs": n, "completeGames": n * 2, "pointRate": round(point_rate, 6),
            "candidateRouting": routed,
            "decisionTiming": {kind: timing_summary(times) for kind, times in decision_times.items()},
            "candidateRoutedFraction": round(routed["unified"] / max(1, sum(routed.values())), 6),
            "pairedBootstrap95": [round(lower, 6), round(upper, 6)],
            "bootstrapSamples": bootstrap, "bootstrapSeed": seed, "files": files}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("jsonl", nargs="+", type=Path)
    ap.add_argument("--min-pairs", type=int, default=30)
    ap.add_argument("--bootstrap", type=int, default=10000)
    ap.add_argument("--bootstrap-seed", type=int, default=1941)
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()
    if args.bootstrap < 100 or args.min_pairs < 1:
        ap.error("bootstrap >= 100 and min-pairs >= 1 required")
    try:
        output = assess(args.jsonl, bootstrap=args.bootstrap, seed=args.bootstrap_seed, min_pairs=args.min_pairs)
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "EVIDENCE_REJECTED", "reason": str(exc)}, ensure_ascii=False))
        return 2
    blob = json.dumps(output, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.write_text(blob, encoding="utf-8")
    print(blob, end="")
    return 0 if output["status"] == "SUPPORTED_AT_TESTED_BUDGET" else 1


if __name__ == "__main__":
    raise SystemExit(main())
