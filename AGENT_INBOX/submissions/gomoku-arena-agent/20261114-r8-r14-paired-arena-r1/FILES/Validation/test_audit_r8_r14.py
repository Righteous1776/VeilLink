import json
import tempfile
import unittest
from pathlib import Path
from audit_r8_r14 import audit_game, assess


def make_record(candidate_side: int):
    # Toy verifier-only fixture, never actual AI evidence.
    moves = [112, 0, 113, 2, 114, 4, 115, 6, 116]
    decisions = []
    for ply in range(6, len(moves)):
        turn = ply % 2 + 1
        challenger = turn == candidate_side
        decisions.append({"index": moves[ply], "side": turn, "candidate": challenger,
                          "nodes": 42, "milliseconds": 4,
                          "engineLabel": "ECLIPSE-TEST" if challenger else None})
    return {"schema": "veillink.r8-vs-r14.native-paired-arena.v1",
            "baseline": "R8-compat-disabled-unified",
            "challenger": "R14-frozen-native-pvs-enabled",
            "seed": 123, "pair": 0, "trainedSide": candidate_side,
            "presets": moves[:6], "presetPlies": 6, "moves": moves, "decisions": decisions,
            "winner": 1, "result": "trainedWon" if candidate_side == 1 else "baselineWon",
            "invalid": False,
            "countUnified": sum(bool(d["engineLabel"]) for d in decisions if d["candidate"]),
            "countFallback": 0}


class ReplayTests(unittest.TestCase):
    def test_matched_color_pair_is_neutral(self):
        one, two = make_record(1), make_record(2)
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / 'toy-fixture-not-ai-games.jsonl'
            p.write_text(json.dumps(one) + '\n' + json.dumps(two) + '\n')
            report = assess([p], bootstrap=100, seed=12, min_pairs=1)
        self.assertEqual(report['completeGames'], 2)
        self.assertEqual(report['pointRate'], .5)
        self.assertEqual(report['status'], 'SUPERIORITY_NOT_ESTABLISHED')

    def test_winner_is_replayed_not_trusted(self):
        row = make_record(1)
        row['winner'] = 2
        with self.assertRaisesRegex(ValueError, 'winner'):
            audit_game(row)

    def test_illegal_occupied_move_rejected(self):
        row = make_record(1)
        row['moves'][-1] = 112
        with self.assertRaises(ValueError):
            audit_game(row)

    def test_unpaired_color_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / 'toy-fixture.jsonl'
            p.write_text(json.dumps(make_record(1)) + '\n')
            with self.assertRaisesRegex(ValueError, 'unpaired'):
                assess([p], bootstrap=100, min_pairs=1)

    def test_duplicate_color_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / 'toy-fixture.jsonl'
            x = json.dumps(make_record(1))
            p.write_text(x + '\n' + x + '\n')
            with self.assertRaisesRegex(ValueError, 'duplicate'):
                assess([p], bootstrap=100, min_pairs=1)

    def test_engine_route_cannot_be_faked(self):
        row = make_record(1)
        row['countUnified'] = 0
        with self.assertRaisesRegex(ValueError, 'routing'):
            audit_game(row)

    def test_capped_not_allowed(self):
        row = make_record(1)
        row['result'] = 'capped'
        with self.assertRaisesRegex(ValueError, 'invalid/capped'):
            audit_game(row)

if __name__ == '__main__':
    unittest.main()
