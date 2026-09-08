#!/usr/bin/python3
"""Static and parser-level acceptance tests for the Nabu TuneD mapping."""

import configparser
from pathlib import Path
import sys

from tuned.ppd.config import PPDConfig


ROOT = Path(__file__).resolve().parents[1]
PAYLOAD = ROOT / "payload"
PROFILE_ROOT = PAYLOAD / "usr/lib/tuned/profiles"
MAPPING = PAYLOAD / "usr/share/senemos-nabu/tuned-ppd.conf"


class FakeTuned:
    def profiles(self):
        return [
            "senemos-nabu-balanced",
            "senemos-nabu-balanced-battery",
            "senemos-nabu-power-saver",
            "senemos-nabu-performance",
        ]


def read_profile(name):
    parser = configparser.ConfigParser(interpolation=None)
    path = PROFILE_ROOT / name / "tuned.conf"
    if not parser.read(path):
        raise AssertionError(f"missing profile: {path}")
    return parser


def require_sysfs(profile, expected):
    parser = read_profile(profile)
    actual = dict(parser["sysfs"])
    for path, value in expected.items():
        assert actual.get(path) == value, (profile, path, actual.get(path), value)
    assert not any("force_rail_on" in path or "force_clk_on" in path for path in actual)


def main():
    mapping = PPDConfig(str(MAPPING), FakeTuned())
    assert mapping.ppd_to_tuned.get("balanced", False) == "senemos-nabu-balanced"
    assert mapping.ppd_to_tuned.get("balanced", True) == "senemos-nabu-balanced-battery"
    assert mapping.ppd_to_tuned.get("power-saver", False) == "senemos-nabu-power-saver"
    assert mapping.ppd_to_tuned.get("performance", False) == "senemos-nabu-performance"
    assert mapping.sysfs_acpi_monitor is False

    common = {
        "/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq": "1785600",
        "/sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq": "2419200",
        "/sys/class/devfreq/2c00000.gpu/min_freq": "257000000",
        "/sys/class/devfreq/2c00000.gpu/max_freq": "675000000",
        "/sys/class/devfreq/2c00000.gpu/governor": "simple_ondemand",
    }
    require_sysfs("senemos-nabu-balanced", common | {
        "/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq": "2841600",
    })
    require_sysfs("senemos-nabu-performance", common | {
        "/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq": "2956800",
    })
    require_sysfs("senemos-nabu-power-saver", {
        "/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq": "1555200",
        "/sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq": "2131200",
        "/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq": "2534400",
        "/sys/class/devfreq/2c00000.gpu/min_freq": "257000000",
        "/sys/class/devfreq/2c00000.gpu/max_freq": "585000000",
        "/sys/class/devfreq/2c00000.gpu/governor": "simple_ondemand",
    })

    battery = read_profile("senemos-nabu-balanced-battery")
    assert battery["main"]["include"] == "senemos-nabu-balanced"
    assert battery["cpu"]["energy_performance_preference"] == "balance_power"

    dropin = (PAYLOAD / "usr/lib/systemd/system/tuned-ppd.service.d/90-senemos-nabu-profiles.conf").read_text()
    assert "BindReadOnlyPaths=/usr/share/senemos-nabu/tuned-ppd.conf:/etc/tuned/ppd.conf" in dropin


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, KeyError) as error:
        print(f"test-tuned-profiles: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("test-tuned-profiles: PASS")
