#!/usr/bin/bash
set -Eeuo pipefail

root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
esp=$root/esp
payload=$root/root
install -d "$esp/EFI/SENEMOS" "$esp/EFI/android" "$esp/loader/entries" "$payload/usr/lib/nabu-boot/managers" "$payload/usr/share/nabu/bootloader/systemd-boot"
install -d "$payload/etc/nabu"
printf 'refind_timeout=1\n' >"$payload/etc/nabu/boot.conf"
touch "$esp/.mounted"
printf 'test\n' >"$esp/EFI/SENEMOS/SENEMOS6-2608291500.efi"
printf 'old\n' >"$esp/EFI/SENEMOS/SENEMOS6-2608280000.efi"
printf 'mainline\n' >"$esp/EFI/SENEMOS/SENEMOS7-2608291400.efi"
printf 'old-mainline\n' >"$esp/EFI/SENEMOS/SENEMOS7-2608270000.efi"
printf 'unstable\n' >"$esp/EFI/SENEMOS/SENEMOS7U-2608291600.efi"
printf 'old-unstable\n' >"$esp/EFI/SENEMOS/SENEMOS7U-2608270100.efi"
printf 'old-builder-alias\n' >"$esp/EFI/SENEMOS/fedora-rawhide-mainline-unstable-2608280100.efi"
printf 'lts\n' >"$esp/EFI/SENEMOS/SENEMOS6LTS-2608291300.efi"
printf 'user-kernel\n' >"$esp/EFI/SENEMOS/MyCustomKernel.efi"
printf 'android\n' >"$esp/EFI/android/Reboot2Android.efi"
printf 'title Fedora Rawhide fallback\nefi /EFI/SENEMOS/SENEMOS6-2608280000.efi\n' >"$esp/loader/entries/fallback.conf"
cp manager/loader.conf manager/android.conf "$payload/usr/share/nabu/bootloader/systemd-boot/"
touch "$payload/usr/lib/nabu-boot/managers/systemd-boot.selected"
printf 'default fallback.conf\ntimeout 3\n' >"$esp/loader/loader.conf"

fakebin=$root/bin
install -d "$fakebin"
printf '#!/usr/bin/bash\n[[ $1 == --mountpoint ]] && test -e "$2/.mounted"\n' >"$fakebin/findmnt"
printf '#!/usr/bin/bash\nexit 0\n' >"$fakebin/bootctl"
chmod +x "$fakebin"/*
android_before=$(sha256sum "$esp/EFI/android/Reboot2Android.efi" | cut -d' ' -f1)
fallback_entry_before=$(sha256sum "$esp/loader/entries/fallback.conf" | cut -d' ' -f1)
custom_before=$(sha256sum "$esp/EFI/SENEMOS/MyCustomKernel.efi" | cut -d' ' -f1)

PATH="$fakebin:$PATH" NABU_BOOT_ROOT="$payload" NABU_BOOT_LOCK_FILE="$root/manager.lock" bash manager/nabu-configure-boot-manager systemd-boot --esp "$esp" --sync-only --uki SENEMOS6-2608291500.efi
grep -Fxq 'default senemos-SENEMOS6.conf' "$esp/loader/loader.conf"
test ! -e "$esp/loader/entries/senemos.conf"
grep -Fxq 'efi /EFI/fedora/SENEMOS6-2608291500.efi' "$esp/loader/entries/senemos-SENEMOS6.conf"
grep -Fxq 'efi /EFI/fedora/SENEMOS7-2608291400.efi' "$esp/loader/entries/senemos-SENEMOS7.conf"
grep -Fxq 'efi /EFI/fedora/SENEMOS7U-2608291600.efi' "$esp/loader/entries/senemos-SENEMOS7U.conf"
grep -Fxq 'efi /EFI/fedora/SENEMOS6LTS-2608291300.efi' "$esp/loader/entries/senemos-SENEMOS6LTS.conf"
grep -Fxq 'efi     /EFI/android/Reboot2Android.efi' "$esp/loader/entries/android.conf"
test "$(sha256sum "$esp/EFI/android/Reboot2Android.efi" | cut -d' ' -f1)" = "$android_before"
test ! -e "$esp/EFI/SENEMOS"
test ! -e "$esp/EFI/fedora/SENEMOS6-2608280000.efi"
test ! -e "$esp/EFI/fedora/SENEMOS7-2608270000.efi"
test ! -e "$esp/EFI/fedora/SENEMOS7U-2608270100.efi"
test ! -e "$esp/EFI/fedora/fedora-rawhide-mainline-unstable-2608280100.efi"
test -e "$esp/EFI/fedora/SENEMOS7-2608291400.efi"
test -e "$esp/EFI/fedora/SENEMOS7U-2608291600.efi"
test -e "$esp/EFI/fedora/SENEMOS6LTS-2608291300.efi"
test "$(sha256sum "$esp/EFI/fedora/MyCustomKernel.efi" | cut -d' ' -f1)" = "$custom_before"
test "$(sha256sum "$esp/loader/entries/fallback.conf" | cut -d' ' -f1)" = "$fallback_entry_before"

# Exercise the real removable-media rEFInd layout.  Two source icons are hard
# linked to reproduce RPM link-dupe optimization; FAT-safe copying must create
# independent destination files and complete the transaction.
rm -f "$payload/usr/lib/nabu-boot/managers/systemd-boot.selected"
touch "$payload/usr/lib/nabu-boot/managers/refind.selected"
refind_payload=$payload/usr/share/nabu/bootloader/refind
install -d "$refind_payload/refind-theme-regular/icons/256-96" "$refind_payload/drivers_aa64"
printf 'refind-efi\n' >"$refind_payload/refind_aa64.efi"
printf 'gop-rotate\n' >"$refind_payload/drivers_aa64/GopRotate_aa64.efi"
printf 'resolution 1600 2560\nicons_dir themes/refind-theme-regular/icons/256-96\nfont themes/refind-theme-regular/fonts/source-code-pro-extralight-28.png\n' >"$refind_payload/refind-theme-regular/theme.conf"
install -d "$refind_payload/refind-theme-regular/fonts"
printf 'font\n' >"$refind_payload/refind-theme-regular/fonts/source-code-pro-extralight-28.png"
printf 'icon\n' >"$refind_payload/refind-theme-regular/icons/256-96/os_fedora.png"
ln "$refind_payload/refind-theme-regular/icons/256-96/os_fedora.png" \
   "$refind_payload/refind-theme-regular/icons/256-96/os_android.png"

PATH="$fakebin:$PATH" NABU_BOOT_ROOT="$payload" NABU_BOOT_LOCK_FILE="$root/manager.lock" bash manager/nabu-configure-boot-manager refind --esp "$esp" --sync-only --uki SENEMOS6-2608291500.efi
cmp "$refind_payload/refind_aa64.efi" "$esp/EFI/BOOT/BOOTAA64.EFI"
cmp "$refind_payload/drivers_aa64/GopRotate_aa64.efi" "$esp/EFI/BOOT/drivers/GopRotate_aa64.efi"
grep -Fxq 'scan_driver_dirs drivers' "$esp/EFI/BOOT/refind.conf"
grep -Fxq 'scanfor manual' "$esp/EFI/BOOT/refind.conf"
grep -Fxq 'timeout 5' "$esp/EFI/BOOT/refind.conf"
grep -Fxq 'rotation 3' "$esp/EFI/BOOT/refind.conf"
grep -Fq 'include themes/refind-theme-regular-nabu-2x-v1/theme.conf' "$esp/EFI/BOOT/refind.conf"
grep -Fxq 'icons_dir themes/refind-theme-regular-nabu-2x-v1/icons/256-96' "$esp/EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/theme.conf"
grep -Fxq 'font themes/refind-theme-regular-nabu-2x-v1/fonts/source-code-pro-extralight-28.png' "$esp/EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/theme.conf"
grep -Fxq 'default_selection "SENEMOS6-2608291500.efi"' "$esp/EFI/BOOT/refind.conf"
test "$(grep -c '^menuentry ' "$esp/EFI/BOOT/refind.conf")" -eq 5
grep -Fq 'loader /EFI/fedora/SENEMOS6-2608291500.efi' "$esp/EFI/BOOT/refind.conf"
grep -Fq 'loader /EFI/fedora/SENEMOS7-2608291400.efi' "$esp/EFI/BOOT/refind.conf"
grep -Fq 'loader /EFI/fedora/SENEMOS7U-2608291600.efi' "$esp/EFI/BOOT/refind.conf"
grep -Fq 'loader /EFI/fedora/SENEMOS6LTS-2608291300.efi' "$esp/EFI/BOOT/refind.conf"
grep -Fq 'loader /EFI/android/Reboot2Android.efi' "$esp/EFI/BOOT/refind.conf"
fedora_inode=$(stat -c %i "$esp/EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/icons/256-96/os_fedora.png")
android_inode=$(stat -c %i "$esp/EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/icons/256-96/os_android.png")
test "$fedora_inode" != "$android_inode"
test "$(sha256sum "$esp/EFI/android/Reboot2Android.efi" | cut -d' ' -f1)" = "$android_before"
test ! -e "$esp/loader/entries/senemos.conf"
test -z "$(find "$esp/loader/entries" -maxdepth 1 -type f -name 'senemos-SENEMOS*.conf' -print -quit)"
test ! -e "$esp/EFI/fedora/SENEMOS6-2608280000.efi"
test -e "$esp/EFI/fedora/SENEMOS7-2608291400.efi"
test -e "$esp/EFI/fedora/SENEMOS7U-2608291600.efi"
test -e "$esp/EFI/fedora/SENEMOS6LTS-2608291300.efi"
test "$(sha256sum "$esp/EFI/fedora/MyCustomKernel.efi" | cut -d' ' -f1)" = "$custom_before"
test "$(sha256sum "$esp/loader/entries/fallback.conf" | cut -d' ' -f1)" = "$fallback_entry_before"

# Repair a theme installed under the current directory id by an older package
# before internal asset paths were rewritten.
sed -i 's@themes/refind-theme-regular-nabu-2x-v1/@themes/refind-theme-regular/@g' \
    "$esp/EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/theme.conf"
PATH="$fakebin:$PATH" NABU_BOOT_ROOT="$payload" NABU_BOOT_LOCK_FILE="$root/manager.lock" bash manager/nabu-configure-boot-manager refind --esp "$esp" --sync-only --uki SENEMOS6-2608291500.efi
grep -Fxq 'icons_dir themes/refind-theme-regular-nabu-2x-v1/icons/256-96' "$esp/EFI/BOOT/themes/refind-theme-regular-nabu-2x-v1/theme.conf"
