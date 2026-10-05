# Xiaomi Pad 5 / Nabu — 2.0 EOL

Bu sürüm, Xiaomi Pad 5 çalışmasının son kaynak ve imaj arşividir. Pad 7
ile uyumlu değildir. Kırık ekran nedeniyle bu EOL türevi tablet üzerinde
yeniden açılamadı; **ön sürüm** olarak yayımlanır.

İki imaj, 12 Eylül'de çevrimdışı doğrulanan Fedora Rawhide KDE/ext4 temiz
kurulumundan türetildi. Sistem imajında root parolası ve yedek özeti kaldırıldı,
makine kimliği ilk açılışta üretilecek duruma getirildi, derleme günlüğü
çıkarıldı ve EOL bilgisi eklendi. Önceden oluşturulmuş normal kullanıcı,
Wi-Fi profili veya SSH host anahtarı yoktur. Android ve Linux rEFInd girdileri
korundu. Kernel `7.2.4-6`, CORE meta `3.0.0-83`, KDE meta `3.0.0-103`
olarak kalır.

Yeni `nabu-core-meta 3.0.0-99` paketi, bu imajın KDE meta sürümünü reddetti.
DNF önizlemesi eski `3.0.0-96` sürümüne düşebileceğini gösterdi. Bu nedenle
paket güncellemesi uygulanmadı. COPR'da `7.2.8-1` derlemesinin başarılı
olması, bu imajın onunla açıldığını göstermez.

`SHA256SUMS` dosyası sıkıştırılmış imajların bayt bütünlüğünü denetler.
`zstd -t`, ext4 `e2fsck -fn`, FAT `fsck.vfat -vn`, SELinux etiketleri ve
imaj içeriği denetimleri yayın kapılarıdır. Ayrıntılı öğrenimler için
[teknik devir notu](https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder/blob/codex/nabu-pad5-eol-20260928/docs/PAD5-NABU-EOL-20260928.md) okunabilir.

Kişisel Btrfs HIL imajları bu sürüme dahil değildir; kullanıcı verisi ve
kimlik bilgileri içerir. Donanım firmware'inin kendi lisansı ayrı geçerlidir.
Bu EOL sürümü Xiaomi veya Fedora tarafından desteklenmez.

---

This prerelease archives the clean-install Fedora KDE/ext4 image for Xiaomi
Pad 5. It has no pre-created user, Wi-Fi profile or SSH host key. The root
password verifier was removed and the machine ID will be regenerated on
first boot. The image retains kernel 7.2.4-6 and was not retested on the
tablet after the display broke. It is not a Xiaomi Pad 7 image.
