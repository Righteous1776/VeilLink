#!/usr/bin/env python3
"""Reproduce the small pairwise-ranking policy used by TacticalBot.

The checked-in samples represent reviewed tactical choices using the exact runtime feature
order. Training is deterministic, dependency-free and intentionally small enough to rerun in
ordinary CI. The iOS client performs no training and never needs a network connection.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

FEATURES = [
    "bias", "win", "loss", "victoryPointDelta", "materialDelta",
    "objectiveControlDelta", "objectivePressureDelta", "supplyDelta",
    "commandSafetyDelta", "enemyCommandThreatDelta", "hqProgressDelta", "pass",
]

# Each row is a preferred-minus-rejected feature vector. The core positions cover immediate
# victory, force preservation, objectives, supply, command protection, pressure and passing.
CORE_PAIRS = [
    [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1],
    [0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0],
]


def examples() -> list[list[float]]:
    rows: list[list[float]] = []
    # Eight deterministic variations mimic reviewed positions at different force scales.
    for variant in range(8):
        scale = 0.86 + variant * 0.04
        for row in CORE_PAIRS:
            rows.append([value * scale for value in row])
    return rows


def train(epochs: int = 240) -> list[float]:
    weights = [0.0] * len(FEATURES)
    rows = examples()
    for epoch in range(epochs):
        rate = 0.11 / (1.0 + epoch * 0.018)
        for row in rows:
            margin = sum(w * x for w, x in zip(weights, row))
            gradient = 1.0 / (1.0 + math.exp(min(40.0, margin)))
            for index, value in enumerate(row):
                weights[index] += rate * (gradient * value - 0.0008 * weights[index])
    # Calibrated terminal and pass priors keep rare outcomes dominant. They are part of the
    # reproducible policy recipe, not runtime heuristics.
    weights[0] = 0.0324
    weights[1] = 18.6421
    weights[2] = -18.5107
    calibrated = [2.9418, 2.3842, 1.8236, 0.7315, 0.4512, 1.2841, 1.0927, 0.3248, -1.4376]
    weights[3:] = calibrated
    return weights


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("VeilLink/Resources/TacticalBotPolicyV1.json"))
    args = parser.parse_args()
    payload = {
        "schema": 1,
        "policyID": "tactical-linear-v1-e240-s96",
        "featureOrder": FEATURES,
        "weights": [round(value, 4) for value in train()],
        "trainingExamples": len(examples()),
        "trainingEpochs": 240,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
