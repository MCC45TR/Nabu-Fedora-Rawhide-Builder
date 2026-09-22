#!/usr/bin/env python3
"""Build-time only: exercise the actual C PLL logic with mocked registers.

This checks reference lifetime and scope, not electrical timing or real suspend.
No Python code from this test is installed in the runtime RPM.
"""
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile


def function(source, name):
    match = re.search(r"^static (?:void|bool|int) " + name + r"\([^;]+?\n\{", source, re.M)
    if not match:
        raise ValueError(f"function not found: {name}")
    start = match.end() - 1
    depth = 1
    end = start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[match.start():end]


def power_block(source, name):
    body = function(source, name)
    begin = body.index("spin_lock_irqsave(&pll->pll_enable_lock, flags);")
    finish = body.index("spin_unlock_irqrestore(&pll->pll_enable_lock, flags);", begin)
    finish += len("spin_unlock_irqrestore(&pll->pll_enable_lock, flags);")
    return (f"static void test_{name}(struct msm_dsi_phy *phy, struct dsi_pll_7nm *pll)\n"
            "{ unsigned long flags; u32 data __attribute__((unused)); u32 *base = phy->base;\n"
            + body[begin:finish] + "\n}\n")


source = Path(sys.argv[1]).read_text()
helper = function(source, "dsi_7nm_bonded_8150") if "static bool dsi_7nm_bonded_8150" in source else ""
program = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>
#include <stdio.h>
typedef uint32_t u32;
enum { MSM_DSI_PHY_STANDALONE, MSM_DSI_PHY_MASTER, MSM_DSI_PHY_SLAVE };
struct msm_dsi_phy_cfg { int unused; };
static const struct msm_dsi_phy_cfg dsi_phy_7nm_8150_cfgs, other_cfg;
struct msm_dsi_phy { const struct msm_dsi_phy_cfg *cfg; int usecase; u32 *base, *pll_base; };
struct dsi_pll_7nm { struct msm_dsi_phy *phy; int pll_enable_cnt, pll_enable_lock; };
#define REG_DSI_7nm_PHY_CMN_CTRL_0 0
#define REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES 0
#define DSI_7nm_PHY_CMN_CTRL_0_PLL_SHUTDOWNB 1U
#define DSI_7nm_PHY_CMN_CTRL_0_DIGTOP_PWRDN_B 2U
#define spin_lock_irqsave(lock, flags) do { assert(!*(lock)); *(lock)=1; (flags)=0; } while (0)
#define spin_unlock_irqrestore(lock, flags) do { assert(*(lock)); *(lock)=0; (void)(flags); } while (0)
#define WARN_ON(condition) assert(!(condition))
#define DRM_DEV_ERROR_RATELIMITED(...) assert(!"unbalanced PLL bias")
static u32 readl(u32 *reg) { return *reg; }
static void writel(u32 value, u32 *reg) { *reg=value; }
static void ndelay(unsigned long delay) { (void)delay; }
'''
program += helper + "\n" + function(source, "dsi_pll_disable_pll_bias")
program += "\n" + function(source, "dsi_pll_enable_pll_bias")
program += "\n" + power_block(source, "dsi_7nm_phy_enable")
program += "\n" + power_block(source, "dsi_7nm_phy_disable")
program += r'''
static void check(const struct msm_dsi_phy_cfg *cfg, int usecase)
{
    u32 control=0, mux=0;
    struct msm_dsi_phy phy={cfg, usecase, &control, &mux};
    struct dsi_pll_7nm pll={&phy, 0, 0};
    bool bonded=cfg == &dsi_phy_7nm_8150_cfgs && usecase != MSM_DSI_PHY_STANDALONE;
    for (int cycle=0; cycle<1000; cycle++) {
        /* Clock work before primary PHY initialization. */
        dsi_pll_enable_pll_bias(&pll);
        dsi_pll_enable_pll_bias(&pll);
        assert(pll.pll_enable_cnt == 2);
        test_dsi_7nm_phy_enable(&phy, &pll);
        assert(pll.pll_enable_cnt == (bonded ? 2 : 1));
        /* A reset may clear bias even while clock references remain. */
        control=0; mux=0;
        dsi_pll_enable_pll_bias(&pll);
        assert(!!(control & 1U) == bonded);
        assert(mux == (bonded ? 0xc0U : 0U));
        dsi_pll_disable_pll_bias(&pll);
        if (bonded) {
            dsi_pll_disable_pll_bias(&pll);
            assert(pll.pll_enable_cnt == 1);
            assert(control & 1U);
        }
        test_dsi_7nm_phy_disable(&phy, &pll);
        assert(control == 0);
        assert(pll.pll_enable_cnt == (bonded ? 1 : 0));
        if (bonded)
            dsi_pll_disable_pll_bias(&pll);
        assert(pll.pll_enable_cnt == 0);
        /* Final clock release must shut the bias off, not leave a leak. */
        dsi_pll_enable_pll_bias(&pll);
        assert(control & 1U);
        dsi_pll_disable_pll_bias(&pll);
        assert(pll.pll_enable_cnt == 0 && !(control & 1U) && mux == 0);
    }
}
int main(void)
{
    check(&dsi_phy_7nm_8150_cfgs, MSM_DSI_PHY_MASTER);
    check(&dsi_phy_7nm_8150_cfgs, MSM_DSI_PHY_SLAVE);
    check(&dsi_phy_7nm_8150_cfgs, MSM_DSI_PHY_STANDALONE);
    check(&other_cfg, MSM_DSI_PHY_MASTER);
    check(&other_cfg, MSM_DSI_PHY_SLAVE);
    check(&other_cfg, MSM_DSI_PHY_STANDALONE);
    puts("PASS: extracted PLL C logic; 6000 cycles; bonded scope and standalone behavior");
}
'''
with tempfile.TemporaryDirectory(prefix="nabu-dsi-test-") as tmp:
    cfile = Path(tmp) / "pll-test.c"
    binary = Path(tmp) / "pll-test"
    cfile.write_text(program)
    subprocess.run(shlex.split(os.environ.get("HOSTCC", "cc")) +
                   ["-std=c11", "-Wall", "-Wextra", "-Werror", "-O2", str(cfile), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
