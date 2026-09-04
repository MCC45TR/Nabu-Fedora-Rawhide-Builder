import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / "files" / "nabu-audio-orientation"
if not SCRIPT.exists():
    SCRIPT = Path(__file__).parents[1] / "kde" / "nabu-audio-orientation"


def load_module():
    loader = importlib.machinery.SourceFileLoader("nabu_audio_orientation", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class KWinRotationTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.tempdir = tempfile.TemporaryDirectory()
        self.config = Path(self.tempdir.name) / "kwinoutputconfig.json"
        os.environ["NABU_KWIN_OUTPUT_CONFIG"] = str(self.config)

    def tearDown(self):
        os.environ.pop("NABU_KWIN_OUTPUT_CONFIG", None)
        self.tempdir.cleanup()

    def write_transform(self, transform):
        self.config.write_text(
            json.dumps(
                [
                    {
                        "name": "outputs",
                        "data": [
                            {"connectorName": "DSI-1", "transform": transform}
                        ],
                    }
                ]
            ),
            encoding="utf-8",
        )

    def test_all_kwin_transforms_match_kscreen_rotations(self):
        for transform, expected in self.module.KWIN_TRANSFORMS.items():
            self.write_transform(transform)
            self.module.cached_kwin_mtime = None
            self.assertEqual(self.module.kwin_config_rotation(), expected)

    def test_valid_kwin_config_avoids_kscreen_process(self):
        self.write_transform("Rotated270")

        def unexpected_command(*_args, **_kwargs):
            raise AssertionError("kscreen-doctor must not run for a valid KWin config")

        self.module.command_output = unexpected_command
        self.assertEqual(self.module.kscreen_rotation(), 8)


if __name__ == "__main__":
    unittest.main()
