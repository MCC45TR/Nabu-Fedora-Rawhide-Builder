#!/usr/bin/env python3
"""Host-only execution of the actual CS35L41 TDM/PCM setup functions."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

tree = Path(sys.argv[1])
codec = (tree / "sound/soc/codecs/cs35l41.c").read_text()
header = (tree / "include/sound/cs35l41.h").read_text()
machine = (tree / "sound/soc/qcom/sm8150.c").read_text()
dts = (tree / "arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts").read_text()
port = dts.split("reg = <QUATERNARY_TDM_RX_0>;", 1)[1].split("};", 1)[0]
# Arch's DT says invert/delay=1, but its driver ignores both properties and
# sends zeros. Match its effective AFE packet using our explicit properties.
for name, value in (("sync-mode", 1), ("sync-src", 1), ("invert-sync", 0),
                    ("data-delay", 0), ("data-align", 0)):
    assert f"qcom,tdm-{name} = <{value}>;" in port
assert "snd_soc_dai_set_tdm_slot(codec_dai, 0," not in machine
assert "snd_soc_dai_set_tdm_slot(cpu_dai, 0, slot_mask," in machine
assert "SND_SOC_DAIFMT_I2S" in machine
assert "slot_mask = BIT(2) | BIT(6);" in machine
assert ".set_tdm_slot = cs35l41_set_tdm_slot," in codec
assert "unsigned int tdm_width;" in (tree / "sound/soc/codecs/cs35l41.h").read_text()

macros = ("GLOBAL_CLK_CTRL", "GLOBAL_FS_MASK", "GLOBAL_FS_SHIFT", "SP_FORMAT",
          "ASP_WIDTH_RX_MASK", "ASP_WIDTH_RX_SHIFT", "ASP_WIDTH_TX_MASK",
          "ASP_WIDTH_TX_SHIFT", "SP_RX_WL", "ASP_RX_WL_MASK", "ASP_RX_WL_SHIFT",
          "SP_TX_WL", "ASP_TX_WL_MASK", "ASP_TX_WL_SHIFT")
defines = []
for name in macros:
    match = re.search(r"^#define CS35L41_" + name + r"\s+([^\n]+)$", header, re.M)
    assert match, name
    defines.append(f"#define CS35L41_{name} {match[1]}")

begin = codec.index("struct cs35l41_global_fs_config {")
end = codec.index("static int cs35l41_get_clk_config", begin)
code = r'''
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define GENMASK(h,l) ((~0UL << (l)) & (~0UL >> (sizeof(unsigned long)*8-1-(h))))
#define SNDRV_PCM_STREAM_PLAYBACK 0
#define dev_err(...) ((void)0)
struct regmap { unsigned int clk, fmt, rx, tx; int calls, fail; };
struct cs35l41_private { struct regmap *regmap; unsigned int tdm_width; void *dev; };
struct snd_soc_component { struct cs35l41_private *data; };
struct snd_soc_dai { struct snd_soc_component *component; };
struct snd_pcm_substream { int stream; };
struct snd_pcm_hw_params { unsigned int rate, width; };
#define snd_soc_component_get_drvdata(c) ((c)->data)
#define params_rate(p) ((p)->rate)
#define params_width(p) ((p)->width)
''' + "\n".join(defines) + r'''
static int regmap_update_bits(struct regmap *m, unsigned int reg,
                              unsigned int mask, unsigned int value) {
    if (++m->calls == m->fail) return -EIO;
    unsigned int *p = NULL;
    switch (reg) {
    case CS35L41_GLOBAL_CLK_CTRL: p = &m->clk; break;
    case CS35L41_SP_FORMAT: p = &m->fmt; break;
    case CS35L41_SP_RX_WL: p = &m->rx; break;
    case CS35L41_SP_TX_WL: p = &m->tx; break;
    default: assert(0);
    }
    *p = (*p & ~mask) | (value & mask);
    return 0;
}
''' + codec[begin:end] + r'''
int main(void) {
    struct regmap m = {0};
    struct cs35l41_private priv = {.regmap = &m};
    struct snd_soc_component component = {.data = &priv};
    struct snd_soc_dai dai = {.component = &component};
    struct snd_pcm_substream stream = {0};
    struct snd_pcm_hw_params params = {.rate = 48000, .width = 24};
    /* Legacy users keep their sample-width slots if no TDM override exists. */
    assert(!cs35l41_pcm_hw_params(&stream, &params, &dai));
    assert(((m.fmt & CS35L41_ASP_WIDTH_RX_MASK) >> CS35L41_ASP_WIDTH_RX_SHIFT) == 24);
    for (int i = 0; i < 4; ++i) {
        memset(&m, 0, sizeof(m));
        assert(!cs35l41_set_tdm_slot(&dai, 0, 1U << i, 8, 32));
        assert(!cs35l41_pcm_hw_params(&stream, &params, &dai));
        assert(((m.fmt & CS35L41_ASP_WIDTH_RX_MASK) >> CS35L41_ASP_WIDTH_RX_SHIFT) == 32);
        assert(((m.rx & CS35L41_ASP_RX_WL_MASK) >> CS35L41_ASP_RX_WL_SHIFT) == 24);
        assert(m.tx == 0);
    }
    /* Capture word and slot widths are independently represented too. */
    memset(&m, 0, sizeof(m));
    stream.stream = 1;
    assert(!cs35l41_pcm_hw_params(&stream, &params, &dai));
    assert(((m.fmt & CS35L41_ASP_WIDTH_TX_MASK) >> CS35L41_ASP_WIDTH_TX_SHIFT) == 32);
    assert(((m.tx & CS35L41_ASP_TX_WL_MASK) >> CS35L41_ASP_TX_WL_SHIFT) == 24);
    assert(m.rx == 0);
    /* Invalid input must leave the previous configuration intact. */
    assert(cs35l41_set_tdm_slot(&dai, 0, 256, 8, 32) == -EINVAL);
    assert(cs35l41_set_tdm_slot(&dai, 0, 1, 33, 32) == -EINVAL);
    assert(cs35l41_set_tdm_slot(&dai, 0, 1, -1, 32) == -EINVAL);
    assert(cs35l41_set_tdm_slot(&dai, 0, 1, 8, 8) == -EINVAL);
    assert(priv.tdm_width == 32);
    assert(!cs35l41_set_tdm_slot(&dai, 0, 0x80000000U, 32, 32));
    assert(!cs35l41_set_tdm_slot(&dai, 0, 1, 8, 16));
    memset(&m, 0, sizeof(m));
    assert(cs35l41_pcm_hw_params(&stream, &params, &dai) == -EINVAL);
    assert(m.calls == 0);
    assert(!cs35l41_set_tdm_slot(&dai, 0, 1, 8, 32));
    params.rate = 12345;
    assert(cs35l41_pcm_hw_params(&stream, &params, &dai) == -EINVAL);
    assert(m.calls == 0);
    params.rate = 48000;
    /* Each failed I2C update aborts setup; no subsequent write is attempted. */
    for (int direction = 0; direction < 2; ++direction) {
        stream.stream = direction;
        for (int fault = 1; fault <= 3; ++fault) {
            memset(&m, 0, sizeof(m)); m.fail = fault;
            assert(cs35l41_pcm_hw_params(&stream, &params, &dai) == -EIO);
            assert(m.calls == fault);
        }
    }
    assert(!cs35l41_set_tdm_slot(&dai, 0, 0, 0, 0));
    assert(priv.tdm_width == 0);
    puts("PASS: actual CS35L41 I2S sample width and optional 24-in-32 override, RX/TX, invalid inputs, I2C faults");
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix="nabu-framing-test-") as tmp:
    src, exe = Path(tmp) / "test.c", Path(tmp) / "test"
    src.write_text(code)
    subprocess.run([os.environ.get("HOSTCC", "cc"), "-std=c11", "-Wall", "-Wextra",
                    "-Werror", "-Wno-sign-compare", str(src), "-o", str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
