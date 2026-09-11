#!/usr/bin/env python3
"""Prepare, apply and verify SELinux labels without trusting a FUSE view."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import selinux
except ImportError as exc:
    raise SystemExit("python3 SELinux bindings are required") from exc


RELABEL_RE = re.compile(r"^Would relabel (.+) from (\S+) to (\S+)$")
COMMAND_RE = re.compile(r"^debugfs: ea_get <(\d+)> security\.selinux$")
STAT_COMMAND_RE = re.compile(r"^debugfs: stat <(\d+)>$")
OWNER_RE = re.compile(r"^User:\s+(\d+)\s+Group:\s+(\d+)")
VALUE_RE = re.compile(r'^security\.selinux \(\d+\) = "(.+)"$')
VALID_CONTEXT_RE = re.compile(
    r"^system_u:object_r:[A-Za-z0-9_]+:s0(?:-s0(?::c\d+(?:\.c\d+)?)?)?\\000$"
)
UNSAFE_TYPES = {"unlabeled_t", "fusefs_t"}
CRITICAL_PATHS = {
    "/": "root_t",
    "/etc/ld.so.cache": "ld_so_cache_t",
    "/usr/lib/systemd/systemd": "init_exec_t",
    "/usr/bin/bash": "shell_exec_t",
    "/usr/lib/systemd/system/dbus-broker.service": "systemd_unit_file_t",
}
# The targeted policy deliberately marks descendants below /mnt/<name> as
# <<none>> because they are normally separate filesystems. This directory is
# the native, empty mountpoint for Android persist and still needs a safe host
# filesystem label before the real partition is mounted.
EXPLICIT_MOUNTPOINT_CONTEXTS = {
    "/mnt/vendor/persist": "system_u:object_r:mnt_t:s0",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def normalized_target(root: Path, rendered: str) -> tuple[Path, str]:
    candidate = Path(rendered)
    if not candidate.is_absolute():
        candidate = Path(os.path.abspath(Path.cwd() / candidate))
    else:
        candidate = Path(os.path.abspath(candidate))
    try:
        relative = candidate.relative_to(root)
    except ValueError:
        fail(f"setfiles returned a path outside the mounted root: {rendered}")
    image_path = "/" if str(relative) == "." else "/" + relative.as_posix()
    return candidate, image_path


def iter_tree(root: Path):
    yield root
    stack = [root]
    while stack:
        directory = stack.pop()
        try:
            entries = list(os.scandir(directory))
        except OSError as exc:
            fail(f"could not enumerate {directory}: {exc}")
        for entry in entries:
            path = Path(entry.path)
            yield path
            if entry.is_dir(follow_symlinks=False):
                stack.append(path)


def prepare(args: argparse.Namespace) -> None:
    root = Path(args.root).resolve(strict=True)
    mapped: dict[int, dict[str, object]] = {}
    paths: dict[str, int] = {}
    all_inodes: dict[int, str] = {}
    matched_paths = 0
    if selinux.matchpathcon_init(args.policy) != 0:
        fail(f"could not initialize target SELinux policy: {args.policy}")
    try:
        for host_path in iter_tree(root):
            try:
                inode_stat = os.lstat(host_path)
            except OSError as exc:
                fail(f"path vanished during inode inventory: {host_path}: {exc}")
            inode = inode_stat.st_ino
            relative = host_path.relative_to(root)
            image_path = "/" if str(relative) == "." else "/" + relative.as_posix()
            all_inodes.setdefault(inode, image_path)
            paths.setdefault(image_path, inode)
            try:
                status, context = selinux.matchpathcon(image_path, inode_stat.st_mode)
            except FileNotFoundError:
                continue
            if status != 0 or not context:
                fail(f"target policy lookup failed for {image_path} with status {status}")
            matched_paths += 1
            record = mapped.setdefault(
                inode, {"inode": inode, "context": context, "paths": []}
            )
            if record["context"] != context:
                fail(
                    f"hard-linked inode {inode} has conflicting SELinux contexts: "
                    f"{record['context']} and {context}"
                )
            record["paths"].append(image_path)
    finally:
        selinux.matchpathcon_fini()

    for image_path, context in EXPLICIT_MOUNTPOINT_CONTEXTS.items():
        inode = paths.get(image_path)
        if inode is None:
            fail(f"required native mountpoint is absent: {image_path}")
        record = mapped.setdefault(
            inode, {"inode": inode, "context": context, "paths": []}
        )
        if record["context"] != context:
            fail(
                f"native mountpoint {image_path} has conflicting context "
                f"{record['context']} instead of {context}"
            )
        if image_path not in record["paths"]:
            record["paths"].append(image_path)

    missing_critical = sorted(path for path in CRITICAL_PATHS if path not in paths)
    if missing_critical:
        fail("critical SELinux paths are absent: " + ", ".join(missing_critical))

    manifest = {
        "format": 1,
        "root": str(root),
        "mapped": sorted(mapped.values(), key=lambda item: int(item["inode"])),
        "all_inodes": [
            {"inode": inode, "path": path, "mapped": inode in mapped}
            for inode, path in sorted(all_inodes.items())
        ],
        "critical": [
            {"path": path, "inode": paths[path], "type": expected_type}
            for path, expected_type in CRITICAL_PATHS.items()
        ],
    }
    Path(args.manifest).write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    report = {
        "unique_inodes": len(all_inodes),
        "policy_mapped_inodes": len(mapped),
        "policy_unmatched_inodes": len(all_inodes) - len(mapped),
        "policy_matched_paths": matched_paths,
        "setfiles_dry_run_changes": sum(1 for _ in Path(args.dry_run).open()),
        "hardlink_aliases": sum(len(item["paths"]) - 1 for item in mapped.values()),
    }
    Path(args.report).write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def load_manifest(path: str) -> dict[str, object]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("format") != 1:
        fail("unsupported SELinux inode manifest format")
    return data


def run_debugfs(image: str, batch: Path, output: Path, writable: bool) -> None:
    command = ["debugfs"]
    if writable:
        command.append("-w")
    command.extend(["-f", str(batch), image])
    with output.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, text=True)
    if result.returncode != 0:
        fail(f"debugfs failed with status {result.returncode}; see {output}")


def apply(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    work = Path(args.work_dir)
    work.mkdir(parents=True, exist_ok=True)
    contexts = work / "contexts"
    contexts.mkdir(exist_ok=True)
    batch = work / "selinux-apply.debugfs"
    context_files: dict[str, Path] = {}
    with batch.open("w", encoding="utf-8") as stream:
        for item in manifest["mapped"]:
            context = str(item["context"])
            value_path = context_files.get(context)
            if value_path is None:
                digest = hashlib.sha256(context.encode()).hexdigest()
                value_path = contexts / digest
                value_path.write_bytes(context.encode() + b"\0")
                context_files[context] = value_path
            stream.write(
                f'ea_set -f "{value_path}" <{int(item["inode"])}> security.selinux\n'
            )
    output = Path(args.output)
    run_debugfs(args.image, batch, output, writable=True)
    text = output.read_text(encoding="utf-8", errors="replace")
    error_lines = [
        line for line in text.splitlines()
        if re.search(r"(^|\s)(ea_set:|Command not found|No such file|Invalid argument)", line)
    ]
    if error_lines:
        fail("debugfs SELinux application reported errors; see " + str(output))


def decode_type(rendered: str) -> str:
    plain = rendered.removesuffix(r"\000")
    parts = plain.split(":")
    return parts[2] if len(parts) >= 4 else ""


def verify(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    work = Path(args.work_dir)
    work.mkdir(parents=True, exist_ok=True)
    batch = work / "selinux-verify.debugfs"
    with batch.open("w", encoding="utf-8") as stream:
        for item in manifest["all_inodes"]:
            stream.write(f'stat <{int(item["inode"])}>\n')
            stream.write(f'ea_get <{int(item["inode"])}> security.selinux\n')
    output = Path(args.output)
    run_debugfs(args.image, batch, output, writable=False)

    observed: dict[int, str | None] = {}
    ownership: dict[int, tuple[int, int]] = {}
    current: int | None = None
    current_stat: int | None = None
    for line in output.read_text(encoding="utf-8", errors="replace").splitlines():
        stat_command = STAT_COMMAND_RE.match(line)
        if stat_command:
            current_stat = int(stat_command.group(1))
            continue
        owner = OWNER_RE.match(line)
        if owner and current_stat is not None:
            ownership[current_stat] = (int(owner.group(1)), int(owner.group(2)))
            current_stat = None
            continue
        command = COMMAND_RE.match(line)
        if command:
            current = int(command.group(1))
            observed[current] = None
            continue
        if current is None:
            continue
        value = VALUE_RE.match(line)
        if value:
            observed[current] = value.group(1)

    all_records = {int(item["inode"]): item for item in manifest["all_inodes"]}
    expected = {
        int(item["inode"]): str(item["context"]) + r"\000"
        for item in manifest["mapped"]
    }
    errors: list[str] = []
    for inode, record in all_records.items():
        value = observed.get(inode)
        path = str(record["path"])
        owner = ownership.get(inode)
        if owner is None:
            errors.append(f"inode {inode} {path}: missing direct ownership readback")
        elif 65534 in owner:
            errors.append(f"inode {inode} {path}: unsafe nobody ownership {owner[0]}:{owner[1]}")
        if value is None:
            errors.append(f"inode {inode} {path}: missing security.selinux")
            continue
        if not VALID_CONTEXT_RE.match(value):
            errors.append(f"inode {inode} {path}: malformed context {value}")
            continue
        context_type = decode_type(value)
        if context_type in UNSAFE_TYPES:
            errors.append(f"inode {inode} {path}: unsafe context {value}")
        if inode in expected and value != expected[inode]:
            errors.append(
                f"inode {inode} {path}: expected {expected[inode]}, observed {value}"
            )

    for item in manifest["critical"]:
        inode = int(item["inode"])
        expected_type = str(item["type"])
        actual_type = decode_type(observed.get(inode) or "")
        if actual_type != expected_type:
            errors.append(
                f"critical path {item['path']}: expected {expected_type}, observed {actual_type or 'missing'}"
            )

    report = {
        "verified_inodes": len(all_records),
        "verified_inode_owners": len(ownership),
        "nobody_uid_gid_inodes": sum(1 for owner in ownership.values() if 65534 in owner),
        "mapped_inodes": len(expected),
        "unmatched_inodes_with_preserved_safe_label": len(all_records) - len(expected),
        "errors": errors[:200],
    }
    Path(args.report).write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if errors:
        fail(f"SELinux inode verification failed for {len(errors)} inode(s); see {args.report}")


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("--root", required=True)
    prepare_parser.add_argument("--policy", required=True)
    prepare_parser.add_argument("--dry-run", required=True)
    prepare_parser.add_argument("--manifest", required=True)
    prepare_parser.add_argument("--report", required=True)
    prepare_parser.set_defaults(func=prepare)

    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("--image", required=True)
    apply_parser.add_argument("--manifest", required=True)
    apply_parser.add_argument("--work-dir", required=True)
    apply_parser.add_argument("--output", required=True)
    apply_parser.set_defaults(func=apply)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--image", required=True)
    verify_parser.add_argument("--manifest", required=True)
    verify_parser.add_argument("--work-dir", required=True)
    verify_parser.add_argument("--output", required=True)
    verify_parser.add_argument("--report", required=True)
    verify_parser.set_defaults(func=verify)

    arguments = parser.parse_args()
    arguments.func(arguments)


if __name__ == "__main__":
    main()
