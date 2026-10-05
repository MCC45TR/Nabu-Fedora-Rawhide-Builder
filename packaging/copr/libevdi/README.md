# Optional Nabu DisplayLink userspace

`libevdi` is the upstream native C API, with no pyevdi/Python runtime.
`nabu-displaylink-tools` supplies the native C++20 read-only command
`nabu-displaylink-status`. It takes a single snapshot and terminates, needs no
root and never changes DRM, loads modules, starts a daemon or polls in background.

The matching `evdi.ko` is built and signed in the Nabu kernel package from
7.2.7-3 onwards. Older DisplayLink adapters may instead use Linux's native UDL
driver. These are USB graphics solutions, not USB-C DisplayPort Alt-Mode.

Modern docks also require Synaptics' proprietary AArch64 DisplayLinkManager.
That binary is NOT bundled, downloaded or executed by these packages. It must
be obtained under its vendor license and installed separately. No license
acceptance or service auto-start is implied by installing libevdi or the tools.

The official Ubuntu download and community AArch64 packaging references are:

- https://www.synaptics.com/products/displaylink-graphics/downloads/ubuntu
- https://github.com/displaylink-rpm/displaylink-rpm
- https://github.com/DisplayLink/evdi/tree/v1.15.1

COPR allows only Fedora-acceptable licenses; the open library/module and tools
can be built there, but the proprietary Manager is excluded. Do not substitute
a generic DKMS RPM that pulls in a different Fedora kernel or recompiles modules
on the tablet. No Xorg-only configuration is installed on Plasma Wayland.

Qualification must include actual frames, dock hotplug, internal display,
suspend/resume, charging/USB host role and CPU/RAM/power. Seeing a dock in sysfs
or an EVDI module loaded does not pass those physical tests.
