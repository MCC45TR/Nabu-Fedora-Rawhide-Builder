#!/usr/bin/env python3
"""Report RPM-owned translation payloads that are absent from an installroot."""

import os
import subprocess
import sys


if len(sys.argv) != 4:
    raise SystemExit("usage: find-missing-rpm-locales.py ROOT REPORT PACKAGES")

root, report_path, packages_path = sys.argv[1:]
query = subprocess.check_output(
    ["rpm", "--root", root, "-qa", "--qf", "PKG:%{NAME}\\n[%{FILENAMES}\\n]"],
    text=True,
    errors="surrogateescape",
)

missing = []
package = ""
for record in query.splitlines():
    if record.startswith("PKG:"):
        package = record[4:]
        continue
    if not package or not record.startswith("/"):
        continue
    is_translation = (
        record.startswith("/usr/share/locale/")
        or record.startswith("/usr/share/qt5/translations/")
        or record.startswith("/usr/share/qt6/translations/")
    )
    if is_translation and not os.path.lexists(root + record):
        missing.append((package, record))

missing = sorted(set(missing))
with open(report_path, "w", encoding="utf-8") as report:
    report.write(f"missing={len(missing)}\n")
    report.writelines(f"{package}|{path}\n" for package, path in missing)
with open(packages_path, "w", encoding="utf-8") as packages:
    packages.writelines(f"{package}\n" for package in sorted({item[0] for item in missing}))
