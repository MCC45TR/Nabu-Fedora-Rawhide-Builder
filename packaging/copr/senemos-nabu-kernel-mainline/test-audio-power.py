#!/usr/bin/env python3
"""Host-only tests for the actual Nabu DAPM compatibility repair (no hardware)."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

tree = Path(sys.argv[1])
source = (tree / 'sound/soc/qcom/sm8150.c').read_text()
dts = (tree / 'arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu.dts').read_text()
dts = dts[dts.index('&sound {'):]
assert 'channels->min = channels->max = 4;' in source
assert 'SND_SOC_DAIFMT_DSP_A' in source
assert 'slot_mask = GENMASK(channels - 1, 0);' in source
slot_map = source.split('} cs35l41_tdm_channel_map[] = {', 1)[1].split('};', 1)[0]
rx_slots = [int(slot) for slot in re.findall(r'\.rx = \{(\d+)\}', slot_map)]
assert rx_slots == [3, 1, 2, 0], rx_slots
assert sorted(rx_slots) == list(range(4))
assert 'channels != ARRAY_SIZE(cs35l41_tdm_channel_map)' in source
assert re.search(r'for_each_rtd_codec_dais\(rtd, i, codec_dai\) \{\s*'
                 r'ret = snd_soc_dai_set_fmt\(codec_dai, codec_dai_fmt\);', source)
assert re.search(r'of_machine_is_compatible\("xiaomi,nabu"\) && link->dynamic\)\s*link->ignore_pmdown_time = 1;', source)
assert '"MultiMedia1 Playback", "BR SPK"' not in dts
for pos in ('BR', 'TR', 'BL', 'TL'):
    assert f'"Speaker", "{pos} Speaker"' in dts
    assert f'"{pos} Speaker", "{pos} SPK"' in dts
begin = source.index('static const struct snd_soc_dapm_widget nabu_speaker_widgets[]')
end = source.index('static int sm8150_platform_probe', begin)
code = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define BIT(n) (1u << (n))
#define GENMASK(h,l) (((1u << ((h)+1))-1) & ~((1u << (l))-1))
#define GFP_KERNEL 0
#define SND_SOC_DAPM_SPK(n,e) { n }
struct snd_soc_dapm_widget { const char *name; };
struct snd_soc_dapm_route { const char *sink, *control, *source; };
struct snd_soc_card {
    void *dev;
    const struct snd_soc_dapm_route *of_dapm_routes;
    int num_of_dapm_routes;
    const struct snd_soc_dapm_widget *dapm_widgets;
    int num_dapm_widgets;
};
static bool nabu = true, oom;
static bool of_machine_is_compatible(const char *s) {
    return nabu && !strcmp(s, "xiaomi,nabu");
}
static void *devm_kmemdup(void *dev, const void *p, size_t n, int flags) {
    (void)dev; (void)flags;
    void *out = oom ? NULL : malloc(n);
    if (out) memcpy(out, p, n);
    return out;
}
''' + source[begin:end] + r'''
int main(void) {
    const struct snd_soc_dapm_route old[] = {
        {"MultiMedia1 Playback", NULL, "BR SPK"},
        {"MultiMedia1 Playback", NULL, "TR SPK"},
        {"MultiMedia1 Playback", NULL, "BL SPK"},
        {"MultiMedia1 Playback", NULL, "TL SPK"},
        {"AMIC1", NULL, "MIC BIAS3"},
        {"MultiMedia1 Playback", "Do not alter", "BR SPK"},
    };
    struct snd_soc_card c = {.of_dapm_routes = old, .num_of_dapm_routes = 6};
    nabu = false;
    assert(!sm8150_fix_nabu_speaker_routes(&c));
    assert(c.of_dapm_routes == old && !c.dapm_widgets);
    nabu = true;
    c.num_of_dapm_routes = 3;
    assert(!sm8150_fix_nabu_speaker_routes(&c));
    assert(c.of_dapm_routes == old);
    c.num_of_dapm_routes = 6;
    oom = true;
    assert(sm8150_fix_nabu_speaker_routes(&c) == -ENOMEM);
    assert(c.of_dapm_routes == old && !c.dapm_widgets);
    oom = false;
    assert(!sm8150_fix_nabu_speaker_routes(&c));
    assert(c.of_dapm_routes != old && c.num_dapm_widgets == 4);
    for (int i = 0; i < 4; i++) {
        assert(!strcmp(c.of_dapm_routes[i].sink, nabu_speaker_widgets[i].name));
        assert(!strcmp(old[i].sink, "MultiMedia1 Playback"));
        assert(c.of_dapm_routes[i].source == old[i].source);
    }
    assert(c.of_dapm_routes[4].sink == old[4].sink);
    assert(c.of_dapm_routes[5].sink == old[5].sink);
    const struct snd_soc_dapm_route *fixed = c.of_dapm_routes;
    assert(!sm8150_fix_nabu_speaker_routes(&c));
    assert(c.of_dapm_routes == fixed); /* corrected DTs are not rewritten */
    free((void *)fixed);
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix='nabu-audio-test-') as tmp:
    src, exe = Path(tmp) / 'test.c', Path(tmp) / 'test'
    src.write_text(code)
    subprocess.run([os.environ.get('HOSTCC', 'cc'), '-std=c11', '-Wall', '-Wextra',
                    '-Werror', str(src), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
print('PASS: Nabu endpoint repair, OOM, idempotence, unrelated routes, four active TDM slots, DSP_A')
