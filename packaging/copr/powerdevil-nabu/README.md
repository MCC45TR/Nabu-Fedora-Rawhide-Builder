# Nabu PowerDevil keyboard-backlight guard

This recipe reproduces Fedora's `powerdevil-6.7.5-2` source package from
dist-git commit `b854e9b0de0be0b0bbeab427effdc20e15d899dc` and carries a bounded
two-line fix: a keyboard brightness range is available only when its maximum is
positive.

On Nabu, UPower's compatibility object legitimately reports `0/0` with an
empty native path when no backlit keyboard is attached. The unpatched Plasma
applet treated a successful D-Bus reply as hardware and rendered `nan%`.
