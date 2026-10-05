#!/usr/bin/python3
"""Black-box tests for the native, explicit-only ICC runtime selector."""
import os
from pathlib import Path
import subprocess
import unittest

BINARY = Path(os.environ.get("SENEMOS_NABU_COLOR_BINARY", "./senemos-nabu-color-profile"))
ROOT = Path(__file__).parents[1]
PROFILES = ROOT / "kde/color/icc/senemos/nabu"
MOCK = ROOT / "tests/mock-kscreen-doctor"

class NativeColorProfileTests(unittest.TestCase):
    def test_all_packaged_profiles_validate(self):
        profiles = sorted(PROFILES.glob("*.icc"))
        self.assertEqual(len(profiles), 4)
        for profile in profiles:
            result = subprocess.run([BINARY, "validate", profile], check=True, text=True, capture_output=True)
            self.assertIn("sha256=", result.stdout)

    def test_explicit_apply_is_dry_run_and_panel_bounded(self):
        env = dict(os.environ, KSCREEN_DOCTOR=str(MOCK))
        result = subprocess.run(
            [BINARY, "apply", "display-p3", "--panel", "42-02-0a", "--profile-dir", PROFILES, "--dry-run"],
            env=env, check=True, text=True, capture_output=True,
        )
        self.assertIn("connector=DSI-1", result.stdout)
        self.assertIn("xiaomi-nabu-42-02-0a-display-p3.icc", result.stdout)
        self.assertIn("color-profile-source=ICC", result.stdout)

    def test_automatic_application_command_is_absent(self):
        result = subprocess.run([BINARY, "auto"], text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_binary_is_native_elf(self):
        self.assertEqual(BINARY.read_bytes()[:4], b"\x7fELF")

if __name__ == "__main__":
    unittest.main()
