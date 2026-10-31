"""Make the localhost-only Relay API contract run in standard VeilLink CI preflight."""
from pathlib import Path
import subprocess
import sys
import unittest


class RelayAPIReferenceContractGate(unittest.TestCase):
    def test_stdlib_store_and_loopback_http_contract(self):
        root = Path(__file__).resolve().parents[2]
        directory = root / "server" / "relay-api-v1"
        result = subprocess.run(
            [sys.executable, "-m", "unittest", "discover", "-s", str(directory),
             "-p", "test_*.py", "-v"],
            cwd=directory,
            text=True, capture_output=True, timeout=45
        )
        self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)
