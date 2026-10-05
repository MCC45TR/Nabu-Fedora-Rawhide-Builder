#!/usr/bin/env python3
"""Build-time fixture tests only, never uses the machine's real sysfs."""
import pathlib
import subprocess
import sys
import tempfile

program = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="nabu-displaylink-test-") as temp:
    root = pathlib.Path(temp)
    def run(*args):
        return subprocess.run([program, "--sysfs-root", str(root), *args],
                              capture_output=True, text=True, check=False)
    result = run()
    assert result.returncode == 2 and "displaylink_docks=unknown" in result.stdout
    devices = root / "bus/usb/devices"
    devices.mkdir(parents=True)
    assert run().returncode == 0
    assert run("--require-dock").returncode == 1
    for name, vendor in (("1-2", "17e9"), ("1-2:1.0", "17e9"), ("1-3", "1d6b")):
        dev = devices / name
        dev.mkdir()
        (dev / "idVendor").write_text(vendor + "\n")
        (dev / "idProduct").write_text("6000\n")
        (dev / "speed").write_text("480\n")
    module = root / "devices/evdi"
    module.mkdir(parents=True)
    (module / "version").write_text("1.15.1\n")
    result = run("--require-dock")
    assert result.returncode == 0
    for text in ("displaylink_docks=1", "dock=1-2 product=6000 usb_mbps=480",
                 "evdi_module_version=1.15.1", "frames=not_tested"):
        assert text in result.stdout, result.stdout
    assert run("--unknown").returncode == 2
print("PASS: missing sysfs, absent dock, exact vendor, interface deduplication, version and arguments")
