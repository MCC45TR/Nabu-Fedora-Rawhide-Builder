#!/usr/bin/python3

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


PROJECT_DIR = Path(__file__).resolve().parents[1]
HELPER = PROJECT_DIR / "files" / "nabu-kde-auto-brightness-guard"
SAFE_CURVE = [
    -3.20176853966701,
    34.970977888676,
    194.969856211704,
    1019.04321965955,
    2031.9863105125,
    2383.34012739443,
    2734.69394427636,
    3086.04776115829,
    5122.65304622817,
    13917.4136651532,
    100000.0,
]


def document(curve, enabled=True):
    return [
        {
            "name": "outputs",
            "data": [
                {
                    "connectorName": "DSI-1",
                    "automaticBrightness": enabled,
                    "autoBrightnessCurve": curve,
                    "scale": 2,
                }
            ],
        }
    ]


class BrightnessGuardTests(unittest.TestCase):
    def run_guard(self, payload):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        config = root / "config" / "kwinoutputconfig.json"
        state = root / "state"
        config.parent.mkdir()
        config.write_text(json.dumps(payload), encoding="utf-8")
        environment = os.environ.copy()
        environment.update(
            {
                "NABU_KWIN_OUTPUT_CONFIG": str(config),
                "XDG_STATE_HOME": str(state),
            }
        )
        subprocess.run([str(HELPER)], check=True, env=environment)
        return json.loads(config.read_text(encoding="utf-8")), state

    def test_repairs_observed_collapsed_curve(self):
        collapsed = [-4.8, -3.8, -2.8, -1.8, -0.6, 0.4, 77, 81, 85, 89, 94]
        result, state = self.run_guard(document(collapsed))
        output = result[0]["data"][0]
        self.assertEqual(output["autoBrightnessCurve"], SAFE_CURVE)
        self.assertEqual(output["scale"], 2)
        self.assertTrue(
            (state / "senemos-nabu/kwinoutputconfig.pre-brightness-guard.json").is_file()
        )

    def test_preserves_safe_learned_curve(self):
        learned = SAFE_CURVE.copy()
        learned[5] += 100
        result, state = self.run_guard(document(learned))
        self.assertEqual(result[0]["data"][0]["autoBrightnessCurve"], learned)
        self.assertFalse(state.exists())

    def test_does_not_change_disabled_automatic_brightness(self):
        collapsed = [0] * 11
        result, state = self.run_guard(document(collapsed, enabled=False))
        self.assertEqual(result[0]["data"][0]["autoBrightnessCurve"], collapsed)
        self.assertFalse(state.exists())


if __name__ == "__main__":
    unittest.main()
