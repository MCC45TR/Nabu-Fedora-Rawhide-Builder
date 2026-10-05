#!/usr/bin/python3
"""Black-box tests for the native C++ audio orientation helper."""
import os
from pathlib import Path
import subprocess
import unittest

BINARY = Path(os.environ.get("NABU_AUDIO_ORIENTATION_BINARY", "./nabu-audio-orientation"))

class NativeAudioOrientationTests(unittest.TestCase):
    def test_all_rotations_are_bijective(self):
        result = subprocess.run([BINARY, "--self-test"], check=True, text=True, capture_output=True)
        lines = result.stdout.strip().splitlines()
        self.assertEqual(len(lines), 4)
        expected = {"1": "FL,FR,RL,RR", "2": "RL,FL,RR,FR", "4": "RR,RL,FR,FL", "8": "FR,RR,FL,RL"}
        for line in lines:
            fields = dict(field.split("=", 1) for field in line.split())
            self.assertEqual(fields["mapping"], expected[fields["rotation"]])

    def test_binary_is_native_elf(self):
        self.assertEqual(BINARY.read_bytes()[:4], b"\x7fELF")

    def test_stereo_bypasses_filter_and_unrelated_cards_are_ignored(self):
        env = os.environ.copy()
        env.pop("NABU_AUDIO_TARGET", None)
        result = subprocess.run([BINARY, "--self-test-targets"], env=env,
                                check=True, text=True, capture_output=True)
        self.assertEqual(result.stdout.strip(),
                         "stereo=direct legacy=filter unrelated=ignored")

if __name__ == "__main__":
    unittest.main()
