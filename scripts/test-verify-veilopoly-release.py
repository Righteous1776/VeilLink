#!/usr/bin/env python3
"""Negative gates for the actual app-resource verifier; not an iOS simulation."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("core_release", ROOT / "scripts/verify-core-release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class VeilopolyReleaseResourcesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="veilopoly-resource-gate-")
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "VeilLink.app"
        self.bundle = self.app / "Veilopoly_VeilopolyUI.bundle"
        shutil.copytree(ROOT / "VEILOPOLY_DEV/Veilopoly/Sources/VeilopolyUI/Resources", self.bundle)

    def test_complete_payload_has_all_hashes(self):
        report = release.verify_veilopoly_resources(self.app)
        self.assertEqual(len(report["files"]), 114)
        self.assertEqual(report["manuals"], 1)
        self.assertEqual(report["images"], 99)
        self.assertEqual(report["sounds"], 13)

    def test_missing_sound_fails_closed(self):
        (self.bundle / "cash.wav").unlink()
        with self.assertRaises(SystemExit):
            release.verify_veilopoly_resources(self.app)

    def test_changed_image_fails_closed(self):
        (self.bundle / "die1.png").write_bytes(b"not-the-confirmed-texture")
        with self.assertRaises(SystemExit):
            release.verify_veilopoly_resources(self.app)

    def test_duplicate_module_bundle_is_rejected(self):
        (self.app / "VeilopolyUI.bundle").mkdir()
        with self.assertRaises(SystemExit):
            release.verify_veilopoly_resources(self.app)

    def test_missing_manual_fails_closed(self):
        (self.bundle / "VeilopolyCompleteManual.md").unlink()
        with self.assertRaises(SystemExit):
            release.verify_veilopoly_resources(self.app)


if __name__ == "__main__":
    unittest.main()
