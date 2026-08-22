# Nabu Plasma Mobile profile

The Nabu Plasma Mobile image uses Fedora's stock Plasma Mobile, KWin and
Plasma Login Manager packages. It does not ship a forked KWin.

The integrated `nabu-repository-config` source RPM publishes three Mobile
subpackages:

- `nabu-kde-plasma-mobile`: common shell, first-boot, login and session policy.
- `nabu-kde-plasma-mobile-minimal`: Index, Koko, KWrite and QMLKonsole.
- `nabu-kde-plasma-mobile-optimal`: Dolphin, Angelfish, Koko, KWrite, KWeather,
  KClock, Kalk, QMLKonsole and Elisa, plus the retained optimal utilities.

Plasma Setup remains a separate first-boot service and runs before the display
manager. Plasma Login Manager is the display manager. Its systemd mount
namespace replaces `/usr/share/wayland-sessions` with the package-owned
directory containing only `plasma-mobile.desktop`; therefore the greeter does
not offer a second desktop session even though Fedora's `plasma-desktop`
package remains installed as the `plasmashell` provider required by
`plasma-workspace`.

The v1.4.0.6 Mobile image was updated from the preserved v1.4.0.5 image using
signed COPR RPMs. Relevant successful COPR builds are:

- `nabu-kde-integration` release 6: build 10893234.
- `nabu-repository-config` release 14: build 10893271.

Image release gates must verify one exposed Mobile session, Plasma Login
Manager enablement, Plasma Setup enablement and marker absence, app policy,
RPM ownership and special modes, ext4/FAT health, EFI identity and SHA-256.
