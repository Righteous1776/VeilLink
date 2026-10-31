import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "ci-collect-evidence.py"
spec = importlib.util.spec_from_file_location("veillink_ci_evidence", SCRIPT)
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class XCTestEvidenceTests(unittest.TestCase):
    def inspect(self, text):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "unit-tests.log"
            path.write_text(text, encoding="utf-8")
            return ci.extract_xctest_summary(path)

    def test_passed_bundle_has_summary(self):
        result = self.inspect(
            "Test Suite 'All tests' passed at 2026-10-31\n"
            "Executed 766 tests, with 0 failures (0 unexpected)\n"
        )
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["latest_reported_tests"], 766)

    def test_failed_case_is_not_overlooked(self):
        result = self.inspect(
            "Test Case '-[VeilLinkTests.GomokuTests testMode]' failed (1.0 seconds).\n"
            "Test Suite 'All tests' failed at 2026-10-31\n"
            "Executed 789 tests, with 1 failure (0 unexpected)\n"
        )
        self.assertEqual(result["status"], "failed")
        self.assertEqual(len(result["failed_cases"]), 1)

    def test_no_summary_is_unverified(self):
        self.assertEqual(self.inspect("** TEST SUCCEEDED **")["status"], "unverified")

    def test_missing_log_is_not_run(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(ci.extract_xctest_summary(
                Path(root) / "missing.log")["status"], "not_run")


if __name__ == "__main__":
    unittest.main()
