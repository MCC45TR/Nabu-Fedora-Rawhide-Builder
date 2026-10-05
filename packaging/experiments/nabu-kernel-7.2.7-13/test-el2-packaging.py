#!/usr/bin/env python3
"""Build-host RPM conditional policy test; never installs either kernel."""
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent
spec = root / "senemos-nabu-kernel-mainline.spec"

def expanded(*flags):
    return subprocess.check_output(["rpmspec", *flags, "-P", str(spec)], text=True)

normal = expanded()
experiment = expanded("--with", "nabu_el2")
assert "Name:           senemos-nabu-kernel-mainline\n" in normal
assert "Name:           senemos-nabu-kernel-el2-experimental\n" in experiment
assert "Provides:       kernel-nabu-core-uname-r\n" in normal
assert "Provides:       kernel-nabu-core-uname-r\n" not in experiment
assert "Provides:       kernel-nabu-el2-experimental-uname-r\n" in experiment
assert "Requires:       senemos-nabu-kernel-mainline >= " in experiment
assert "Obsoletes:" not in experiment
assert "%posttrans\n" in normal and "pending.d/mainline" in normal
for directive in ("%pre\n", "%post\n", "%preun\n", "%postun\n", "%posttrans\n", "%trigger"):
    assert directive not in experiment, "unexpected experimental RPM script: " + directive
files = experiment.split("%files\n", 1)[1].split("%changelog", 1)[0]
for entry in files.splitlines():
    if entry.strip():
        assert entry.startswith(("/boot/", "/usr/lib/modules/")), entry
        assert "-nabu-senemos-el2-experimental" in entry, entry
assert "CFLAGS=" in experiment
assert "nabu-el2-experimental.config" in experiment
assert "test-el2-dtb.py" in normal and "test-el2-dtb.py" in experiment
print("PASS: normal/experimental RPM identities, isolated files, retained fallback, no experiment scriptlets")
