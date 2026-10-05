# Nabu packaged color profile provenance

The four ICC files in `kde/color/icc/senemos/nabu/` were generated on
2026-08-25 by the packaged `senemos-nabu-color-profile` converter from locally
authorized Xiaomi Pad 5 Qualcomm QDCM calibration XML files. The XML inputs
are not included in this source package.

Input SHA-256 identifiers:

- `36_02_0b`: `57c40ec5f96a03dfd616c7c48cc542a1980f1154036e24ab38621e48135ab0a1`
- `42_02_0a`: `4042668f046f5299d954036d25e36122fa3d0bf955c6fa5df2498b0a3b5f6cbf`

Packaged ICC SHA-256 identifiers:

- `xiaomi-nabu-36-02-0b-srgb.icc`: `562dcd0fc7bd8fcb9d7c2f08b0a6590e197b84a242a1c54cd2e089613b98655c`
- `xiaomi-nabu-36-02-0b-display-p3.icc`: `dd17cb965ed3025881f7b3a4014084b8b38d937c840c2236df6d5d998e350c6e`
- `xiaomi-nabu-42-02-0a-srgb.icc`: `f940e9fcc0c17e9ae54b40b62c5fef9f854e7689aff376abdda7ca77b7d10f65`
- `xiaomi-nabu-42-02-0a-display-p3.icc`: `f6ac5e0c5caaf5da34864aa98656b2f436db2a12fbff92401b46aaee1e70b4fc`

These are experimental factory-derived profiles, not colorimeter-validated
Linux characterizations. They reproduce only the supported static SDR IGC,
3D-LUT and gamma stages. The Android display HAL and panel behavior can add
processing that an ICC profile cannot represent.
