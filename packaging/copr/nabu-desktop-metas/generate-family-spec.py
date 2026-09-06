#!/usr/bin/python3
"""Generate the unified desktop-meta spec from the five maintained profiles."""

from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / "nabu-unified-meta"
PROFILES = (
    "gnome-nabu-meta",
    "gnome-mobile-nabu-meta",
    "kde-plasma-nabu-meta",
    "kde-plasma-mobile-nabu-meta",
    "phosh-nabu-meta",
)
SOURCE_MAP = {
    "gnome-nabu-meta": {0: 0, 1: 1},
    "gnome-mobile-nabu-meta": {0: 0, 1: 1, 2: 13, 3: 14, 4: 15, 5: 16, 6: 17, 7: 18, 8: 19},
    "kde-plasma-nabu-meta": {0: 4, 1: 2, 2: 0, 3: 3, 4: 1, 5: 5, 6: 6, 7: 7, 8: 8},
    "kde-plasma-mobile-nabu-meta": {0: 9, 1: 10, 2: 11, 3: 12, 4: 2, 5: 0, 6: 3, 7: 1, 8: 5, 9: 6, 10: 7, 11: 8},
    "phosh-nabu-meta": {0: 0},
}


def text(name: str) -> str:
    return (SOURCE / f"{name}.spec").read_text()


def remap_sources(value: str, name: str) -> str:
    mapping = SOURCE_MAP[name]

    def replace(match: re.Match[str]) -> str:
        old = int(match.group(1))
        return f"%{{SOURCE{mapping[old]}}}"

    return re.sub(r"%\{SOURCE(\d+)\}", replace, value)


def section(value: str, heading: str) -> str:
    match = re.search(rf"(?ms)^%{re.escape(heading)}\s*\n(.*?)(?=^%(?:prep|build|install|check|files|post|preun|postun|posttrans|changelog)\b)", value)
    return match.group(1).rstrip() if match else ""


def description(value: str) -> str:
    match = re.search(r"(?ms)^%description\s*\n(.*?)(?=^%prep\b)", value)
    return match.group(1).strip()


def package_header(value: str, name: str) -> str:
    prefix = value.split("%description", 1)[0]
    lines = []
    for line in prefix.splitlines():
        if re.match(r"^(Summary|Requires|Recommends|Suggests|Conflicts|Provides|Obsoletes):", line):
            lines.append(line)
    return f"%package -n {name}\n" + "\n".join(lines)


def files(value: str, name: str) -> str:
    match = re.search(r"(?ms)^%files\s*\n(.*?)(?=^%(?:post|preun|postun|posttrans|changelog)\b)", value)
    if not match:
        raise RuntimeError("missing files section")
    result = match.group(1).rstrip()
    if name == "kde-plasma-nabu-meta":
        # Both translation archives carry the same SPDX license texts. Keep a
        # single packaged copy to avoid duplicate-file warnings.
        result = result.replace(" l10n/LICENSES/plasma-setup/*", "")
    return result


def scriptlets(value: str, name: str) -> str:
    matches = re.finditer(
        r"(?ms)^(%(?:pretrans|posttrans|preun|postun|pre|post))(?!\w)([^\n]*)\n(.*?)(?=^%(?:pretrans|posttrans|preun|postun|pre|post|files|changelog)\b)",
        value,
    )
    chunks = []
    for match in matches:
        command, options, body = match.groups()
        if " -n " not in f" {options} ":
            options = f" -n {name}{options}"
        chunks.append(f"{command}{options}\n{body.rstrip()}")
    return "\n\n".join(chunks)


headers = []
build_requires = set()
for profile in PROFILES:
    value = text(profile)
    headers.append(package_header(value, profile))
    for line in value.split("%description", 1)[0].splitlines():
        if line.startswith("BuildRequires:"):
            build_requires.add(line)

# GNOME Mobile is a strict superset of the GNOME payload. KDE Desktop carries
# the complete shared KDE payload; only the first mobile-session stanza is
# additional for Plasma Mobile. Avoid executing identical install operations
# twice, especially creation of fixed systemd symlinks.
gnome_install = remap_sources(section(text("gnome-mobile-nabu-meta"), "install"), "gnome-mobile-nabu-meta")
kde_install = remap_sources(section(text("kde-plasma-nabu-meta"), "install"), "kde-plasma-nabu-meta")
mobile_install = remap_sources(section(text("kde-plasma-mobile-nabu-meta"), "install"), "kde-plasma-mobile-nabu-meta")
mobile_session_install = mobile_install.split("install -Dm0755 kde-integration", 1)[0].rstrip()
install_parts = [
    "# Shared GNOME and GNOME Mobile payload\n" + gnome_install,
    "# Shared KDE Plasma payload\n" + kde_install,
    "# Plasma Mobile session-only payload\n" + mobile_session_install,
]
check_parts = []
for profile in ("gnome-mobile-nabu-meta", "kde-plasma-nabu-meta", "kde-plasma-mobile-nabu-meta"):
    check_parts.append(f"# {profile}\n" + remap_sources(section(text(profile), "check"), profile))

source_lines = """Source0:        nabu-kde-l10n-1.1.0.tar.gz
Source1:        nabu-flashlight-integration-1.0.0.tar.gz
Source2:        nabu-kde-integration-1.4.0.1.tar.gz
Source3:        nabu-kde-widgets-debug-1.0.1.tar.zst
Source4:        95-nabu-plasma-login.preset
Source5:        80-nabu-plasma-login-theme.conf
Source6:        nabu-plasma-login.svg
Source7:        90-nabu-powerdevil.conf
Source8:        90-nabu-compositor-realtime.conf
Source9:        plasma-mobile.desktop
Source10:       20-nabu-mobile-session.conf
Source11:       90-nabu-mobile-login.conf
Source12:       95-nabu-plasma-mobile.preset
Source13:       gnome-mobile-copr.repo
Source14:       nabu-gnome-mobile-sync
Source15:       nabu-gnome-mobile-sync.service
Source16:       nabu-gnome-mobile-sync.timer
Source17:       90-nabu-gnome-mobile-sync.preset
Source18:       test-gnome-mobile-repo-sync.sh
Source19:       20-nabu-mobile-user-mode.conf"""

out = [
    "%global debug_package %{nil}",
    "%global legacy_meta_max 9999999999-99",
    "",
    "Name:           nabu-desktop-metas",
    "Version:        3.0.0",
    "Release:        100%{?dist}",
    "Summary:        Unified desktop profile family for Xiaomi Pad 5",
    "License:        MIT AND GPL-2.0-or-later AND GPL-3.0-or-later AND BSD-2-Clause AND CC0-1.0",
    "URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder",
    source_lines,
    "BuildArch:      noarch",
    *sorted(build_requires),
    "",
    "%description",
    "One source package for the five supported Nabu desktop manifests. Existing",
    "binary RPM names, dependencies, conflicts, integration payloads and update",
    "semantics are preserved for ordinary DNF upgrades.",
    "",
]

for profile, header in zip(PROFILES, headers):
    out.extend([header, "", f"%description -n {profile}", description(text(profile)), ""])

out.extend([
    "%prep",
    "%setup -q -c -T",
    "mkdir l10n flashlight kde-integration widgets",
    "tar -xzf %{SOURCE0} -C l10n --strip-components=1",
    "tar -xzf %{SOURCE1} -C flashlight --strip-components=1",
    "tar -xzf %{SOURCE2} -C kde-integration --strip-components=1",
    "tar --zstd -xf %{SOURCE3} -C widgets --strip-components=1",
    "chmod +x kde-integration/kde/senemos-nabu-color-profile kde-integration/tests/mock-kscreen-doctor",
    "",
    "%build",
    "",
    "%install",
    "\n\n".join(install_parts),
    "",
    "%check",
    "\n\n".join(check_parts),
    "",
])

for profile in PROFILES:
    scripts = scriptlets(text(profile), profile)
    if scripts:
        out.extend([scripts, ""])
    out.extend([f"%files -n {profile}", files(text(profile), profile), ""])

out.extend([
    "%changelog",
    "* Sun Sep 06 2026 mcc45tr <mcc45tr@gmail.com> - 3.0.0-100",
    "- Build all five desktop manifests from one COPR source family.",
    "- Preserve the existing binary names and stock Fedora/KDE package policy.",
    "",
])

(HERE / "nabu-desktop-metas.spec").write_text("\n".join(out))
