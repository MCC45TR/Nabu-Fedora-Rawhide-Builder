#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

g++ -std=c++20 -O2 -Wall -Wextra -Werror \
    -DNABU_RPM_EXECUTABLE=\"$repo_root/tests/fixtures/rpm-query-stub.sh\" \
    "$repo_root/tools/lib/rpm-file-ownership.cpp" -o "$scratch/rpm-file-ownership"

"$scratch/rpm-file-ownership" capture / "$scratch/query.tsv"
"$scratch/rpm-file-ownership" capture-dump / "$scratch/dump.tsv"
grep -Fxq '/etc/passwd|0|0' "$scratch/query.tsv"
cmp "$scratch/query.tsv" "$scratch/dump.tsv"

"$scratch/rpm-file-ownership" verify / "$scratch/query.tsv" "$scratch/good.txt"
grep -Fxq 'mismatches=0' "$scratch/good.txt"
sed 's/|0|0$/|1|1/' "$scratch/query.tsv" >"$scratch/bad.tsv"
if "$scratch/rpm-file-ownership" verify / "$scratch/bad.tsv" "$scratch/bad.txt"; then
    echo 'incorrect ownership passed verification' >&2
    exit 1
fi
grep -Fxq 'mismatches=1' "$scratch/bad.txt"
grep -Fxq '/etc/passwd|expected=1:1|actual=0:0' "$scratch/bad.txt"
echo 'rpm-file-ownership native helper passed'
