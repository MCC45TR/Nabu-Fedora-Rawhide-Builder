#!/usr/bin/python3
"""Synthetic, redistributable tests for the QDCM-to-ICC conversion path."""

import importlib.machinery
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET


SCRIPT = Path(__file__).parents[1] / "kde" / "senemos-nabu-color-profile"
LOADER = importlib.machinery.SourceFileLoader("nabu_color_profile", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
MODULE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(MODULE)


def curve_payload(points, maximum, header):
    words = [header, points, 6] + [0] * (1024 * 3)
    for channel in range(3):
        offset = 3 + channel * 1024
        for index in range(points):
            words[offset + index] = round(index * maximum / (points - 1))
    return struct.pack(f"<{len(words)}I", *words)


def clut_payload():
    words = [0, 0, 0, 4913]
    for blue in range(17):
        for green in range(17):
            for red in range(17):
                words.extend((
                    red * 256, green * 256, blue * 256,
                    red * 256, green * 256, blue * 256,
                ))
    return struct.pack(f"<{len(words)}I", *words)


def add_feature(mode, feature_type, payload):
    feature = ET.SubElement(
        mode, "Feature",
        FeatureType=feature_type, Disable="false", DataSize=str(len(payload)),
    )
    feature.text = payload.hex().upper()


def write_fixture(path):
    root = ET.Element("Calib_Data")
    modes = ET.SubElement(root, "Disp_Modes", NumModes="2")
    for name, mode_id, gamut in (("hal_srgb", "3", "srgb"), ("hal_dci_p3", "36", "dcip3")):
        mode = ET.SubElement(
            modes, "Mode", Name=name, ModeID=mode_id,
            ColorGamut=gamut, DynamicRange="sdr",
        )
        add_feature(mode, "7", curve_payload(256, 4095, 262144))
        add_feature(mode, "3", clut_payload())
        add_feature(mode, "8", curve_payload(1024, 1023, 0))
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)


class ColorProfileTests(unittest.TestCase):
    def test_synthetic_qdcm_generates_kwin_compatible_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            source = directory / "qdcm_calib_data_xiaomi_36_02_0b_video_mode_dual_dsi_cphy_panel.xml"
            output = directory / "icc"
            write_fixture(source)
            MODULE.import_profiles(source, output)
            profiles = sorted(output.glob("*.icc"))
            self.assertEqual(len(profiles), 2)
            for profile in profiles:
                MODULE.validate_icc(profile, quiet=True)
                tags = MODULE.icc_tags(profile.read_bytes())
                self.assertEqual(tags["B2A0"][0:4], b"mBA ")
                self.assertEqual(tags["B2A1"][0:4], b"mBA ")

    def test_panel_revision_comes_from_kernel_attribute(self):
        with tempfile.TemporaryDirectory() as directory:
            revision = Path(directory) / "panel_revision"
            revision.write_text("42-02-0a\n", encoding="ascii")
            self.assertEqual(MODULE.detect_panel_revision([revision]), "42-02-0a")
            revision.write_text("unknown\n", encoding="ascii")
            self.assertIsNone(MODULE.detect_panel_revision([revision], []))

    def test_panel_revision_falls_back_to_display_uefi_variable(self):
        with tempfile.TemporaryDirectory() as directory:
            variable = Path(directory) / "DisplayPanelConfiguration-test"
            variable.write_bytes(
                b"\x06\x00\x00\x00 msm_drm.dsi_display0="
                b"dsi_k82_42_02_0a_dual_cphy_vid_display:\x00"
            )
            self.assertEqual(
                MODULE.detect_panel_revision([], [variable]), "42-02-0a"
            )

    def test_kernel_panel_revision_wins_over_uefi_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            revision = directory / "panel_revision"
            variable = directory / "DisplayPanelConfiguration-test"
            revision.write_text("36-02-0b\n", encoding="ascii")
            variable.write_bytes(b"\x06\x00\x00\x00 dsi_k82_42_02_0a")
            self.assertEqual(
                MODULE.detect_panel_revision([revision], [variable]), "36-02-0b"
            )

    def test_panel_revision_wait_is_bounded_and_retries(self):
        with (
            mock.patch.object(
                MODULE, "detect_panel_revision",
                side_effect=(None, None, "36-02-0b"),
            ) as detector,
            mock.patch.object(MODULE.time, "sleep") as sleeper,
        ):
            self.assertEqual(MODULE.wait_for_panel_revision(3, 0.25), "36-02-0b")
        self.assertEqual(detector.call_count, 3)
        self.assertEqual(sleeper.call_count, 2)

    def run_auto(self, directory, state, marker=None):
        directory = Path(directory)
        profile_dir = directory / "profiles"
        profile_dir.mkdir(exist_ok=True)
        marker_path = directory / "state" / "marker.json"
        if marker is not None:
            marker_path.parent.mkdir(parents=True)
            marker_path.write_text(json.dumps(marker), encoding="utf-8")
        target = profile_dir / "xiaomi-nabu-42-02-0a-srgb.icc"
        with (
            mock.patch.object(MODULE, "detect_panel_revision", return_value="42-02-0a"),
            mock.patch.object(MODULE, "wait_for_internal_output", return_value=state),
            mock.patch.object(MODULE, "find_profile", return_value=target) as finder,
            mock.patch.object(MODULE.subprocess, "run") as runner,
        ):
            MODULE.auto_profile(profile_dir, None, marker_path, 1, 0, False)
        return target, marker_path, finder, runner

    def test_auto_applies_variant_srgb_for_a_new_user(self):
        with tempfile.TemporaryDirectory() as directory:
            target, marker, finder, runner = self.run_auto(
                directory,
                {
                    "name": "DSI-1", "connected": True, "enabled": True,
                    "colorProfileSource": "sRGB", "iccProfilePath": "",
                },
            )
            finder.assert_called_once_with("srgb", "42-02-0a", target.parent)
            runner.assert_called_once()
            saved = json.loads(marker.read_text(encoding="utf-8"))
            self.assertTrue(saved["managed"])
            self.assertEqual(saved["panel"], "42-02-0a")
            self.assertEqual(saved["profile"], str(target))

    def test_auto_retains_p3_but_corrects_the_panel_variant(self):
        with tempfile.TemporaryDirectory() as directory:
            profile_dir = Path(directory) / "profiles"
            old = profile_dir / "xiaomi-nabu-36-02-0b-display-p3.icc"
            target, _marker, finder, runner = self.run_auto(
                directory,
                {
                    "name": "DSI-1", "connected": True, "enabled": True,
                    "colorProfileSource": 1, "iccProfilePath": str(old),
                },
            )
            finder.assert_called_once_with("display-p3", "42-02-0a", target.parent)
            runner.assert_called_once()

    def test_auto_preserves_custom_icc(self):
        with tempfile.TemporaryDirectory() as directory:
            _target, marker, finder, runner = self.run_auto(
                directory,
                {
                    "name": "DSI-1", "connected": True, "enabled": True,
                    "colorProfileSource": "ICC",
                    "iccProfilePath": "/home/test/calibrated.icc",
                },
            )
            finder.assert_not_called()
            runner.assert_not_called()
            saved = json.loads(marker.read_text(encoding="utf-8"))
            self.assertFalse(saved["managed"])

    def test_auto_preserves_later_unprofiled_user_choice(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = "/usr/share/color/icc/senemos/nabu/xiaomi-nabu-42-02-0a-srgb.icc"
            _target, marker, finder, runner = self.run_auto(
                directory,
                {
                    "name": "DSI-1", "connected": True, "enabled": True,
                    "colorProfileSource": "sRGB", "iccProfilePath": previous,
                },
                {"version": 1, "panel": "42-02-0a", "profile": previous, "managed": True},
            )
            finder.assert_not_called()
            runner.assert_not_called()
            saved = json.loads(marker.read_text(encoding="utf-8"))
            self.assertFalse(saved["managed"])


if __name__ == "__main__":
    unittest.main()
