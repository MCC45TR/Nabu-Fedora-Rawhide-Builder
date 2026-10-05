#!/usr/bin/env python3
"""Build-host DTB test only: validate Nabu's EL2, display and audio topology.

This does not change DT, map physical memory or establish firmware EL2 access.
The small FDT reader uses the public flattened device tree v17 format, avoiding
an extra runtime agent or build-only libfdt Python dependency on the tablet.
"""
import copy
import pathlib
import struct
import sys


def cells(raw):
    assert len(raw) % 4 == 0, "unaligned FDT cells"
    return struct.unpack(">" + "I" * (len(raw) // 4), raw)


def strings(raw):
    assert raw.endswith(b"\0"), "unterminated FDT string list"
    return tuple(value.decode("ascii") for value in raw[:-1].split(b"\0"))


def read_dtb(data):
    assert len(data) >= 40, "short FDT header"
    magic, total, tree_at, strings_at, _, version, compatible, _, string_size, tree_size = struct.unpack_from(">10I", data)
    assert magic == 0xd00dfeed and total == len(data), "invalid FDT header"
    assert version == 17 and compatible <= 17, "unsupported FDT version"
    assert 40 <= tree_at <= total - tree_size and 40 <= strings_at <= total - string_size
    tree, strings = data[tree_at:tree_at + tree_size], data[strings_at:strings_at + string_size]
    nodes, stack, at = {}, [], 0
    while at + 4 <= len(tree):
        token = struct.unpack_from(">I", tree, at)[0]
        at += 4
        if token == 1:  # FDT_BEGIN_NODE
            end = tree.find(b"\0", at)
            assert end >= at, "unterminated FDT node"
            name = tree[at:end].decode("ascii")
            assert "/" not in name
            stack.append(name)
            path = "/".join(stack) or "/"
            assert path not in nodes, "duplicate FDT node"
            nodes[path] = {}
            at = (end + 4) & ~3
        elif token == 2:  # FDT_END_NODE
            assert stack, "unbalanced FDT node"
            stack.pop()
        elif token == 3:  # FDT_PROP
            assert stack and at + 8 <= len(tree)
            length, name_at = struct.unpack_from(">II", tree, at)
            at += 8
            assert at + length <= len(tree) and name_at < len(strings)
            end = strings.find(b"\0", name_at)
            assert end >= name_at
            name = strings[name_at:end].decode("ascii")
            props = nodes["/".join(stack) or "/"]
            assert name not in props, "duplicate FDT property"
            props[name] = tree[at:at + length]
            at = (at + length + 3) & ~3
        elif token == 4:  # FDT_NOP
            pass
        elif token == 9:  # FDT_END
            assert not stack and "/" in nodes, "incomplete FDT tree"
            return nodes
        else:
            raise AssertionError("invalid FDT token")
    raise AssertionError("no FDT_END")


def validate(nodes):
    assert b"xiaomi,nabu" in nodes["/"]["compatible"].split(b"\0"), "not Nabu"
    psci = nodes["/psci"]
    assert b"arm,psci-1.0" in psci["compatible"].split(b"\0")
    assert psci["method"] == b"smc\0", "PSCI must retain the trusted-firmware SMC conduit"
    cpus = [node for path, node in nodes.items() if path.startswith("/cpus/cpu@") and "/" not in path[6:]]
    assert len(cpus) == 8, "expected eight Nabu CPUs"
    assert {cells(cpu["reg"]) for cpu in cpus} == {(0, i * 0x100) for i in range(8)}
    for cpu in cpus:
        assert cpu["device_type"] == b"cpu\0" and cpu["enable-method"] == b"psci\0"
        assert cpu.get("status", b"okay\0") in (b"okay\0", b"ok\0"), "disabled CPU"
    gic_path = "/soc@0/interrupt-controller@17a00000"
    gic = nodes[gic_path]
    assert gic["compatible"] == b"arm,gic-v3\0"
    assert gic.get("status", b"okay\0") in (b"okay\0", b"ok\0")
    assert "interrupt-controller" in gic and cells(gic["#interrupt-cells"]) == (3,)
    assert cells(gic["reg"]) == (0, 0x17a00000, 0, 0x10000, 0, 0x17a60000, 0, 0x100000)
    assert cells(gic["interrupts"]) == (1, 9, 4), "missing GIC virtual maintenance PPI"
    timer = nodes["/timer"]
    assert timer["compatible"] == b"arm,armv8-timer\0"
    assert timer.get("status", b"okay\0") in (b"okay\0", b"ok\0")
    assert cells(timer["interrupts"]) == (1, 1, 8, 1, 2, 8, 1, 3, 8, 1, 0, 8), "timer PPI order/routing changed"
    assert timer.get("interrupt-parent", nodes["/"]["interrupt-parent"]) == gic["phandle"]
    # Nabu overrides the generic SM8150 TZ size. Match Xiaomi nabu-r-oss's
    # removed_regions and our board DTS, not the smaller generic SoC value.
    for address, size in ((0x85700000, 0x600000), (0x86200000, 0x5500000)):
        reserve = nodes[f"/reserved-memory/memory@{address:x}"]
        assert cells(reserve["reg"]) == (0, address, 0, size), "HYP/TZ reservation changed"
        assert "no-map" in reserve and "reusable" not in reserve, "HYP/TZ must stay reserved"
        assert reserve.get("status", b"okay\0") in (b"okay\0", b"ok\0")
    bootargs = nodes.get("/chosen", {}).get("bootargs", b"").decode("ascii")
    assert not any(flag in bootargs for flag in ("kvm-arm.mode=", "iommu.passthrough=1", "arm-smmu.disable_bypass=0")), "unvalidated hypervisor/SMMU override"

    # Check the serialized RPM DTB, not only the source DTS. Four codec
    # Stereo PCM still needs all four amplifier phandles and DAPM endpoints.
    sound = nodes["/sound"]
    assert sound["compatible"] == b"qcom,sm8150-sndcard\0"
    speakers = ("BR", "TR", "BL", "TL")
    assert strings(sound["widgets"]) == tuple(
        item for speaker in speakers for item in ("Speaker", f"{speaker} Speaker")
    ), "four physical speaker widgets changed"
    routes = strings(sound["audio-routing"])
    assert len(routes) % 2 == 0
    route_pairs = set(zip(routes[::2], routes[1::2]))
    assert all((f"{speaker} Speaker", f"{speaker} SPK") in route_pairs
               for speaker in speakers), "four speaker routes changed"
    assert not any(sink == "MultiMedia1 Playback" and source.endswith(" SPK")
                   for sink, source in route_pairs), "legacy feedback route returned"
    assert "playback-only" in nodes["/sound/mm1-dai-link"]
    amp_links = cells(nodes["/sound/speaker-dai-link/codec"]["sound-dai"])
    assert len(amp_links) == 8 and len(set(amp_links[::2])) == 4
    assert amp_links[1::2] == (0, 0, 0, 0), "four amplifier links changed"

    # Nabu uses two synchronous DSI links, with DSI0 as the sole master.
    display = "/soc@0/display-subsystem@ae00000"
    dsi0 = nodes[f"{display}/dsi@ae94000"]
    dsi1 = nodes[f"{display}/dsi@ae96000"]
    for dsi in (dsi0, dsi1):
        assert dsi.get("status", b"okay\0") in (b"okay\0", b"ok\0")
        assert "qcom,dual-dsi-mode" in dsi and "qcom,sync-dual-dsi" in dsi
    assert "qcom,master-dsi" in dsi0 and "qcom,master-dsi" not in dsi1
    panel = nodes[f"{display}/dsi@ae94000/panel@0"]
    assert "xiaomi,nabu-csot-nt36523" in strings(panel["compatible"])


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: test-el2-dtb.py COMPILED_NABU_DTB")
    data = pathlib.Path(sys.argv[1]).read_bytes()
    nodes = read_dtb(data)
    validate(nodes)
    # Exercise failure paths with in-memory copies, never write the real DTB.
    changes = [
        ("/psci", "method", b"hvc\0"),
        ("/cpus/cpu@0", "status", b"disabled\0"),
        ("/cpus/cpu@100", "reg", nodes["/cpus/cpu@0"]["reg"]),
        ("/soc@0/interrupt-controller@17a00000", "interrupts", bytes(12)),
        ("/soc@0/interrupt-controller@17a00000", "compatible", b"arm,gic-v2\0"),
        ("/timer", "interrupts", nodes["/timer"]["interrupts"][:-12]),
        ("/timer", "interrupt-parent", bytes(4)),
        ("/reserved-memory/memory@85700000", "no-map", None),
        ("/reserved-memory/memory@86200000", "reusable", b""),
        ("/reserved-memory/memory@86200000", "reg", bytes(16)),
        ("/chosen", "bootargs", b"kvm-arm.mode=protected\0"),
        ("/chosen", "bootargs", b"iommu.passthrough=1\0"),
        ("/sound", "widgets", b"Speaker\0BR Speaker\0"),
        ("/sound", "audio-routing", b"BR Speaker\0BR SPK\0"),
        ("/sound/speaker-dai-link/codec", "sound-dai", bytes(4)),
        ("/soc@0/display-subsystem@ae00000/dsi@ae96000", "status", b"disabled\0"),
        ("/soc@0/display-subsystem@ae00000/dsi@ae94000", "qcom,sync-dual-dsi", None),
        ("/soc@0/display-subsystem@ae00000/dsi@ae96000", "qcom,master-dsi", b""),
        ("/soc@0/display-subsystem@ae00000/dsi@ae94000/panel@0", "compatible", b"other,panel\0"),
    ]
    for path, prop, value in changes:
        modified = copy.deepcopy(nodes)
        if value is None:
            del modified[path][prop]
        else:
            modified.setdefault(path, {})[prop] = value
        try:
            validate(modified)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid DT accepted: {path} {prop}")
    for malformed in (b"", data[:39], b"BAD!" + data[4:], data[:-1]):
        try:
            read_dtb(malformed)
        except AssertionError:
            pass
        else:
            raise AssertionError("malformed FDT accepted")
    print("PASS: compiled Nabu DTB: EL2 prerequisites, 4 speakers, dual DSI; 23 negative cases")


if __name__ == "__main__":
    main()
