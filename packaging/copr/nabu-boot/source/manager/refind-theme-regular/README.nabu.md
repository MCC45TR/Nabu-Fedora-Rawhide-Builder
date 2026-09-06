# Nabu rEFInd theme profile

This runtime subset comes from
`bobafetthotmail/refind-theme-regular` commit
`ed76f1e6d1bfe790ea7333fe5886fa7af126475d` (2026-08-02).

The Nabu profile deliberately ships only the `256-96` bitmap set and the
28-pixel Source Code Pro font. Together these are 2x the upstream default
128/48-pixel icons and 14-pixel font. The dark background and dark selection
assets are enabled in `theme.conf`.

The Xiaomi Pad 5 kernel device tree reports `rotation = <90>` for the built-in
panel, which gives the normal 2560x1600 landscape workspace. The profile asks
rEFInd for the native `resolution 1600 2560`; the packaged GopRotate driver and
the Nabu rEFInd `rotation 3` setting then apply 270 degrees counter-clockwise.

`drivers_aa64` contains only the pinned GopRotate binary. It remains the
fail-open extension point for future, separately developed and validated Nabu
EFI drivers. Automatic sensor-driven rotation, NT36523 touch input and USB
input are not provided by this theme package.
