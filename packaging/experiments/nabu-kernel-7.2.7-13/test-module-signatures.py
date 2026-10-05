#!/usr/bin/env python3
"""Offline release test, not tablet runtime: verify signed ARM64 Image/modules.

Use only on an extracted, already RPM-signature-verified Nabu kernel package.
Public certificates are recovered from this Image, never from the host kernel.
No modules are loaded. Only an automatically removed temporary directory is
written. Requires the build machine's openssl and zstd commands.
"""
import pathlib
import struct
import subprocess
import sys
import tempfile


def run(*args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: test-module-signatures.py EXTRACTED_RPM_ROOT UNAME_R")
    root, release = pathlib.Path(sys.argv[1]), sys.argv[2]
    image = (root / "boot" / ("vmlinuz-" + release)).read_bytes()
    assert image[56:60] == b"ARM\x64", "expected uncompressed AArch64 Image"
    symbols = {}
    for line in (root / "boot" / ("System.map-" + release)).read_text().splitlines():
        fields = line.split()
        if len(fields) == 3:
            symbols[fields[2]] = int(fields[0], 16)

    def offset(name, size):
        at = symbols[name] - symbols["_text"]
        assert 0 <= at <= len(image) - size, "symbol outside Image: " + name
        return at

    certificate_size = struct.unpack_from("<Q", image, offset("module_cert_size", 8))[0]
    assert 0 < certificate_size < 65536, "unexpected module certificate size"
    at = offset("system_certificate_list", certificate_size)
    certificate = image[at:at + certificate_size]
    modules = sorted((root / "usr/lib/modules" / release / "kernel").rglob("*.ko.zst"))
    assert modules, "no modules found"
    marker = b"~Module signature appended~\n"

    with tempfile.TemporaryDirectory(prefix="nabu-module-signatures-") as temp:
        directory = pathlib.Path(temp)
        cert = directory / "embedded.der"
        pem = directory / "embedded.pem"
        content = directory / "module.elf"
        signature = directory / "module.p7s"
        cert.write_bytes(certificate)
        run("openssl", "x509", "-inform", "DER", "-in", str(cert), "-out", str(pem))
        print(run("openssl", "x509", "-in", str(pem), "-noout", "-fingerprint", "-sha256").decode().strip())
        command = ["openssl", "cms", "-verify", "-binary", "-inform", "DER",
                   "-in", str(signature), "-content", str(content),
                   "-certfile", str(pem), "-nointern", "-noverify", "-out", "/dev/null"]
        # nointern: never trust an in-message certificate. noverify: the only
        # accepted public certificate is already pinned inside the signed RPM's
        # Image; do not require a public CA/expiry policy unrelated to Kbuild.
        negative_checked = False
        for module in modules:
            data = run("zstd", "-q", "-d", "-c", str(module))
            assert data.endswith(marker), "unsigned module: " + str(module)
            trailer_at = len(data) - len(marker) - 12
            algo, hash_id, kind, signer_len, key_len, sig_len = struct.unpack_from(
                ">5B3xI", data, trailer_at)
            assert (algo, hash_id, kind, signer_len, key_len) == (0, 0, 2, 0, 0)
            assert 0 < sig_len < trailer_at, "invalid PKCS7 length"
            payload = data[:trailer_at - sig_len]
            assert payload[:6] == b"\x7fELF\x02\x01", "expected little-endian ELF64"
            assert struct.unpack_from("<H", payload, 18)[0] == 183, "not AArch64"
            signature.write_bytes(data[trailer_at - sig_len:trailer_at])
            content.write_bytes(payload)
            result = subprocess.run(command, capture_output=True)
            assert result.returncode == 0, str(module) + ": " + result.stderr.decode(errors="replace")
            if not negative_checked:
                damaged = bytearray(payload)
                damaged[len(damaged) // 2] ^= 1
                content.write_bytes(damaged)
                assert subprocess.run(command, capture_output=True).returncode != 0, "corruption was accepted"
                negative_checked = True
        print(f"PASS: {len(modules)} AArch64 module signatures verified against this Image's embedded key; corrupted payload rejected")


if __name__ == "__main__":
    main()
