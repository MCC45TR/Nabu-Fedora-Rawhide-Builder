#!/usr/bin/env python3
"""One-shot profile test; isolated files/bus, no display or sensor access."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BINARY = str(Path(os.environ['NABU_BRIGHTNESS_PROFILE_BINARY']).resolve())

class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.root))
        self.path = self.root / 'kwinoutputconfig.json'
        self.original = [
            {'name': 'outputs', 'data': [
                {'connectorName': 'DSI-1', 'automaticBrightness': False,
                 'scale': 2, 'autoBrightnessCurve': list(range(11))},
                {'connectorName': 'HDMI-1', 'brightness': .45}]},
            {'name': 'setups', 'data': [{'preserve': True}]}]
        self.path.write_text(json.dumps(self.original))
    def tearDown(self):
        self.temp.cleanup()
    def run_helper(self, *args, ok=True):
        result = subprocess.run([BINARY, *args], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stderr)
        return result
    def apply(self, ok=True):
        result = subprocess.run(['dbus-run-session', '--', BINARY, '--apply-pending'],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stderr)
    def test_stages_then_applies_once_preserving_other_settings(self):
        self.run_helper('--stage', 'standard')
        self.assertEqual(json.loads(self.path.read_text()), self.original)
        self.apply()
        new = json.loads(self.path.read_text())
        panel = new[0]['data'][0]
        self.assertFalse(panel['automaticBrightness'])
        self.assertEqual(panel['scale'], 2)
        self.assertEqual(new[0]['data'][1], self.original[0]['data'][1])
        self.assertEqual(new[1], self.original[1])
        curve = panel['autoBrightnessCurve']
        self.assertEqual(len(curve), 11)
        self.assertTrue(all(a < b for a, b in zip(curve, curve[1:])))
        panel['autoBrightnessCurve'] = [i * 10 for i in range(11)]
        self.path.write_text(json.dumps(new))
        self.apply()
        self.assertEqual(json.loads(self.path.read_text()), new)
        backup = self.root / 'senemos-nabu/kwin-before-brightness-profile.json'
        self.assertEqual(json.loads(backup.read_text()), self.original)
    def test_modern_point_format_preserved(self):
        self.original[0]['data'][0]['autoBrightnessCurve'] = [[0, .1], [1000, 1]]
        self.path.write_text(json.dumps(self.original))
        self.run_helper('--stage', 'dim'); self.apply()
        curve = json.loads(self.path.read_text())[0]['data'][0]['autoBrightnessCurve']
        self.assertEqual(len(curve), 11)
        self.assertTrue(all(isinstance(point, list) and len(point) == 2 for point in curve))
    def test_unknown_and_ambiguous_targets_do_not_write(self):
        self.run_helper('--stage', 'battery-unsupported', ok=False)
        self.original[0]['data'].append(dict(self.original[0]['data'][0]))
        self.path.write_text(json.dumps(self.original))
        self.run_helper('--stage', 'bright'); self.apply(ok=False)
        self.assertEqual(json.loads(self.path.read_text()), self.original)
    def test_invalid_document_does_not_write(self):
        self.path.write_text('{broken')
        self.run_helper('--stage', 'standard'); self.apply(ok=False)
        self.assertEqual(self.path.read_text(), '{broken')

if __name__ == '__main__': unittest.main()
