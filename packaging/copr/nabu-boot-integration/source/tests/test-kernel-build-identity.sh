#!/usr/bin/bash
set -Eeuo pipefail

tool=payload/usr/libexec/senemos-nabu/kernel-build-identity
stamp=${NABU_TEST_BUILD_STAMP:-$(date +%y%m%d%H%M)}
[[ $stamp =~ ^[0-9]{10}$ ]]
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

for base in 6.17.0 7.2.0; do
    for release_separator in - -senemos-; do
        uname_r="${base}${release_separator}${stamp}"
        major=${base%%.*}
        test "$("$tool" --field=base "$uname_r")" = "$base"
        test "$("$tool" --field=major "$uname_r")" = "$major"
        test "$("$tool" --field=stamp "$uname_r")" = "$stamp"
        test "$("$tool" --field=uname "$uname_r")" = "$uname_r"
        test "$("$tool" --field=efi-name "$uname_r")" = "SENEMOS${major}-${stamp}.efi"
        test "$("$tool" --field=efi-title "$uname_r")" = \
            "Fedora Rawhide (SENEMOS${major} ${stamp})"
    done
done

cat >"$test_root/rpm" <<EOF
#!/usr/bin/bash
[[ \$1 == -qf && \$2 == --qf && \$3 == '%{RELEASE}\\n' ]]
printf '%s.alpha.fc46\\n' '$stamp'
EOF
chmod +x "$test_root/rpm"
fixed_mainline=7.2.0-nabu-senemos-mainline-alpha
for field_and_expected in \
    "base 7.2.0" \
    "major 7" \
    "stamp $stamp" \
    "uname $fixed_mainline" \
    "efi-name SENEMOS7-$stamp.efi"; do
    read -r identity_field expected <<<"$field_and_expected"
    actual=$(NABU_KERNEL_IDENTITY_RPM="$test_root/rpm" \
        "$tool" "--field=$identity_field" "$fixed_mainline")
    test "$actual" = "$expected"
done

if NABU_KERNEL_IDENTITY_RPM=/bin/false "$tool" --field=stamp 7.2.0-v0.0.9.2; then
    printf 'Legacy product version was accepted as a timestamp identity.\n' >&2
    exit 1
fi

printf 'Dynamic kernel/EFI identity policy: PASS (%s)\n' "$stamp"
