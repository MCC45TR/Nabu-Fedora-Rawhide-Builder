#!/usr/bin/python3
"""Build-only contract tests for the native Nabu color-profile selector."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


BINARY = os.environ.get("SENEMOS_NABU_COLOR_SETTINGS_BINARY", "./senemos-nabu-color-settings")


class ColorSettingsTests(unittest.TestCase):
    def run_selector(self, *arguments, tool=None):
        env = os.environ.copy()
        if tool is not None:
            env["SENEMOS_NABU_PROFILE_TOOL"] = str(tool)
        env["SENEMOS_NABU_PROFILE_DIR"] = "/tmp/nabu-profile-fixture"
        return subprocess.run(
            [BINARY, *arguments], env=env, text=True, capture_output=True,
            timeout=5, check=False,
        )

    def test_list_preserves_four_explicit_choices(self):
        result = self.run_selector("--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([line.split("\t", 1)[0] for line in result.stdout.splitlines()], [
            "36-02-0b-srgb", "36-02-0b-display-p3",
            "42-02-0a-srgb", "42-02-0a-display-p3",
        ])

    def test_selection_is_whitelisted_and_forwarded_without_shell(self):
        with tempfile.TemporaryDirectory() as tmp:
            tool = Path(tmp) / "profile-tool"
            tool.write_text("#!/bin/sh\nprintf '%s\\n' \"$@\"\n", encoding="utf-8")
            tool.chmod(0o700)
            result = self.run_selector("--apply", "42-02-0a-display-p3", "--dry-run", tool=tool)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), [
                "apply", "display-p3", "--panel", "42-02-0a", "--profile-dir",
                "/tmp/nabu-profile-fixture", "--dry-run",
            ])
            invalid = self.run_selector("--apply", "bogus", tool=tool)
            self.assertEqual(invalid.returncode, 2)
            self.assertIn("Unknown Nabu color profile", invalid.stderr)

    def test_helper_error_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            tool = Path(tmp) / "profile-tool"
            tool.write_text("#!/bin/sh\necho 'mock failure' >&2\nexit 7\n", encoding="utf-8")
            tool.chmod(0o700)
            result = self.run_selector("--apply", "36-02-0b-srgb", tool=tool)
            self.assertEqual(result.returncode, 7)
            self.assertIn("mock failure", result.stderr)


if __name__ == "__main__":
    unittest.main()
