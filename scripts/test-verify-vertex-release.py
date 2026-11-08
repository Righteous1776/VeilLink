#!/usr/bin/env python3
"""Portable verifier logic tests, NOT native inference or Mach-O validation."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("release", ROOT / "scripts/verify-core-release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class VertexReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="v29-model-gate-")
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "VeilLink.app"
        self.app.mkdir()
        shutil.copyfile(ROOT / "VeilLink/Resources/LocalAI" / release.VERTEX_NAME,
                        self.app / release.VERTEX_NAME)
        self.binary = self.app / "Frameworks/llama.framework/llama"
        self.binary.parent.mkdir(parents=True)
        self.binary.write_bytes(b"mock metadata fixture, not a native framework")

    def check(self, arch="arm64", build="platform IOS\nminos 15.0\n"):
        with patch.object(release.subprocess, "check_output", side_effect=[arch, build]):
            return release.verify_vertex_resources(self.app, "@rpath/llama.framework/llama")

    def test_actual_pinned_model_with_mocked_native_metadata(self):
        report = self.check()
        self.assertEqual(report["bytes"], 29_203_168)
        self.assertEqual(report["sha256"], release.VERTEX_SHA256)
        self.assertEqual(report["chinese_quality"], "NOT_VALIDATED")

    def test_missing_framework_fails(self):
        self.binary.unlink()
        with self.assertRaises(SystemExit): self.check()

    def test_unlinked_framework_fails(self):
        with self.assertRaises(SystemExit): release.verify_vertex_resources(self.app, "libSystem")

    def test_wrong_model_bytes_fail(self):
        (self.app / release.VERTEX_NAME).write_bytes(b"incorrect model")
        with self.assertRaises(SystemExit): self.check()

    def test_other_gguf_model_fails(self):
        (self.app / "unexpected.gguf").write_bytes(b"wrong")
        with self.assertRaises(SystemExit): self.check()

    def test_simulator_architecture_fails(self):
        with self.assertRaises(SystemExit): self.check(arch="x86_64")

    def test_wrong_platform_or_minimum_os_fails(self):
        for build in ["platform IOSSIMULATOR\nminos 15.0\n", "platform IOS\nminos 16.4\n"]:
            with self.assertRaises(SystemExit): self.check(build=build)


if __name__ == "__main__": unittest.main()
