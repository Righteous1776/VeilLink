#!/usr/bin/env python3
"""Independent replay and paired-score audit, never trusts reported winners."""
import argparse
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path


def terminal(board, idx, side):
    r, c = divmod(idx, 15)
    for dr, dc in ((0, 1), (1, 0), (1, 1), (1, -1)):
        n = 1
        for sign in (-1, 1):
            rr, cc = r + sign * dr, c + sign * dc
            while 0 <= rr < 15 and 0 <= cc < 15 and board[rr * 15 + cc] == side:
                n += 1
                rr += sign * dr
                cc += sign * dc
        if n >= 5:
            return True
    return False


def audit(paths):
    rows = []
    files = {}
    for path in paths:
        raw = path.read_bytes()
        files[str(path)] = {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
        rows.extend(json.loads(line) for line in raw.splitlines() if line)
    pairs = defaultdict(list)
    errors = []
    results = Counter()
    elapsed = []
    depths = Counter()
    nodes = 0
    decisions = 0
    presets = 0
    sequences = set()
    scores = []
    by_side = defaultdict(Counter)
    policy_times = defaultdict(list)
    for game, row in enumerate(rows):
        board = [0] * 225
        win = 0
        for ply, idx in enumerate(row["moves"]):
            if win or not isinstance(idx, int) or not 0 <= idx < 225 or board[idx]:
                errors.append([game, ply, "illegal-or-post-terminal"])
                break
            side = ply % 2 + 1
            board[idx] = side
            if terminal(board, idx, side):
                win = side
        expected = "invalid" if row["invalid"] else "trainedWon" if win == row["trainedSide"] else "baselineWon" if win else "draw" if len(row["moves"]) == 225 else "capped"
        if expected != row["result"] or win != row["winner"]:
            errors.append([game, "winner-or-result-mismatch"])
        if row["presets"] != row["moves"][:row["presetPlies"]]:
            errors.append([game, "preset-mismatch"])
        diag = row["decisions"]
        if [d["index"] for d in diag] != row["moves"][row["presetPlies"]:]:
            errors.append([game, "decision-journal-mismatch"])
        for ply, d in enumerate(diag, row["presetPlies"]):
            challenger = d["side"] == row["trainedSide"]
            if d["side"] != ply % 2 + 1 or d["trained"] != (challenger or row.get("baselineTrained", False)) or d.get("challenger", challenger) != challenger:
                errors.append([game, ply, "policy-assignment-mismatch"])
        results[row["result"]] += 1
        by_side[str(row["trainedSide"])][row["result"]] += 1
        pairs[(row["seed"], row["pair"])].append(row)
        presets += row["presetPlies"]
        decisions += len(diag)
        sequences.add(tuple(row["moves"]))
        nodes += sum(d["nodes"] for d in diag)
        elapsed.extend(d["milliseconds"] for d in diag)
        for d in diag:
            policy_times["learned" if d["trained"] else "original"].append(d["milliseconds"])
        depths.update(str(d["completedDepth"]) for d in diag)
    complete_pairs = []
    for pair, games in pairs.items():
        if len(games) != 2 or {g["trainedSide"] for g in games} != {1, 2} or games[0]["presets"] != games[1]["presets"]:
            errors.append([pair, "broken-color-pair"])
            continue
        if any(g["result"] in ("invalid", "capped") for g in games):
            continue
        points = sum(1 if g["result"] == "trainedWon" else .5 if g["result"] == "draw" else 0 for g in games)
        complete_pairs.append(points / 2)
    counted = results["trainedWon"] + results["baselineWon"] + results["draw"]
    point_rate = (results["trainedWon"] + .5 * results["draw"]) / counted if counted else None
    # Wilson interval is descriptive per-game only; paired bootstrap below is primary.
    wilson = None
    if counted:
        z = 1.959963984540054
        den = 1 + z*z/counted
        mid = (point_rate + z*z/(2*counted))/den
        rad = z*math.sqrt(point_rate*(1-point_rate)/counted + z*z/(4*counted*counted))/den
        wilson = [mid-rad, mid+rad]
    bootstrap = None
    if complete_pairs:
        import random
        rng = random.Random(937551923)
        samples = sorted(sum(rng.choices(complete_pairs, k=len(complete_pairs)))/len(complete_pairs) for _ in range(10000))
        bootstrap = [samples[250], samples[9749]]
    elapsed.sort()
    timing_by_policy = {}
    for policy, times in policy_times.items():
        times.sort()
        timing_by_policy[policy] = {"decisions": len(times), "meanMilliseconds": sum(times)/len(times),
                                    "p95Milliseconds": times[math.ceil(.95*len(times))-1], "maxMilliseconds": max(times)}
    return {"files": files, "games": len(rows), "result": dict(results), "resultsByTrainedColor": {k: dict(v) for k,v in by_side.items()}, "invalidReplayErrors": errors,
            "presets": presets, "actualNativeDecisions": decisions, "nodes": nodes,
            "exactFullSequences": len(sequences), "completeColorPairs": len(complete_pairs),
            "trainedPointRateCompleteGames": point_rate, "perGameWilson95Descriptive": wilson,
            "pairedBootstrap95": bootstrap, "completedDepthHistogram": dict(depths),
            "meanMillisecondsPerDecision": sum(elapsed)/len(elapsed) if elapsed else None,
            "p95MillisecondsPerDecision": elapsed[min(len(elapsed)-1, math.ceil(.95*len(elapsed))-1)] if elapsed else None,
            "maxMillisecondsPerDecision": max(elapsed) if elapsed else None,
            "decisionTimingByPolicy": timing_by_policy,
            "strengthScope": "CPU Linux native kernel at the exact recorded budget; not full Master/Elo/device result",
            "budgetCaveat": "Node cap applies to counted search-tree nodes; mandatory root safety scans are not included and may exceed the wall-time ceiling"}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("input", nargs="+", type=Path)
    p.add_argument("--output", type=Path)
    args = p.parse_args()
    report = audit(args.input)
    text = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")
    raise SystemExit(bool(report["invalidReplayErrors"]))
